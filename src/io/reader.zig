//! Streaming frame decompression pipeline using standard library Reader and Writer interfaces.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const checksum = @import("../utils/checksum.zig");
const descriptor_mod = @import("../frame/descriptor.zig");
const FrameDescriptor = descriptor_mod.FrameDescriptor;
const block_mod = @import("../frame/block.zig");
const BlockHeader = block_mod.BlockHeader;
const skippable_mod = @import("../frame/skippable.zig");
const safe_decomp = @import("../decompress/safe.zig");

/// Decompresses an LZ4 frame stream incrementally from `r` and writes uncompressed
/// data to `w`.
/// Returns the total number of uncompressed bytes written to `w`.
pub fn decompressStream(
    r: *Reader,
    w: *Writer,
    allocator: Allocator,
) !usize {
    var total_uncompressed: usize = 0;

    // Allocate scratch buffers for reading blocks
    const max_block_size = constants.BLOCK_SIZE_4MB;
    const block_raw_buf = try allocator.alloc(u8, max_block_size + 16);
    defer allocator.free(block_raw_buf);

    const block_decomp_buf = try allocator.alloc(u8, max_block_size);
    defer allocator.free(block_decomp_buf);

    while (true) {
        // Read 4-byte Magic Number
        var magic_buf: [4]u8 = undefined;
        const n = try r.readSliceShort(&magic_buf);
        if (n == 0) return total_uncompressed;
        if (n < 4) {
            r.readSliceAll(magic_buf[n..4]) catch return errors.FrameError.PrematureEndOfFrame;
        }

        const magic = endian.readU32Le(&magic_buf);

        // Handle skippable frame
        if (skippable_mod.isSkippableMagic(magic)) {
            var size_buf: [4]u8 = undefined;
            try r.readSliceAll(&size_buf);
            const user_data_len = endian.readU32Le(&size_buf);
            try r.discardAll(user_data_len);
            continue;
        }

        if (magic != constants.FRAME_MAGIC) {
            return errors.FrameError.InvalidMagic;
        }

        // Read Descriptor FLG and BD bytes
        var desc_buf: [15]u8 = undefined;
        try r.readSliceAll(desc_buf[0..2]);

        const flg = desc_buf[0];
        const has_content_size = (flg & (1 << 3)) != 0;
        const has_dict_id = (flg & 1) != 0;

        var desc_len: usize = 2;
        if (has_content_size) desc_len += 8;
        if (has_dict_id) desc_len += 4;
        desc_len += 1; // HC byte

        try r.readSliceAll(desc_buf[2..desc_len]);

        const desc_res = try FrameDescriptor.decode(desc_buf[0..desc_len]);
        const desc = desc_res.descriptor;

        var content_hasher = if (desc.content_checksum)
            checksum.XxHash32.init(0)
        else
            undefined;

        // Block iteration loop
        var history_buf: [constants.BLOCK_SIZE_64KB]u8 = undefined;
        var history_len: usize = 0;

        while (true) {
            var b_header_buf: [4]u8 = undefined;
            try r.readSliceAll(&b_header_buf);

            const b_hdr = try BlockHeader.parse(&b_header_buf);
            if (b_hdr.is_end_mark) break;

            if (b_hdr.size > desc.block_max_size.toBytes()) {
                return errors.FrameError.BlockSizeTooLarge;
            }

            const raw_block = block_raw_buf[0..b_hdr.size];
            try r.readSliceAll(raw_block);

            if (desc.block_checksum) {
                var bc_buf: [4]u8 = undefined;
                try r.readSliceAll(&bc_buf);
                const expected_bc = endian.readU32Le(&bc_buf);
                if (!block_mod.verifyBlockChecksum(raw_block, expected_bc)) {
                    return errors.FrameError.BlockChecksumMismatch;
                }
            }

            if (b_hdr.is_uncompressed) {
                try w.writeAll(raw_block);
                if (desc.content_checksum) {
                    content_hasher.update(raw_block);
                }
                if (desc.block_mode == .linked) {
                    if (raw_block.len >= history_buf.len) {
                        @memcpy(&history_buf, raw_block[raw_block.len - history_buf.len ..]);
                        history_len = history_buf.len;
                    } else {
                        const keep = @min(history_len, history_buf.len - raw_block.len);
                        if (keep > 0) {
                            std.mem.copyForwards(u8, history_buf[0..keep], history_buf[history_len - keep .. history_len]);
                        }
                        @memcpy(history_buf[keep .. keep + raw_block.len], raw_block);
                        history_len = keep + raw_block.len;
                    }
                }
                total_uncompressed += raw_block.len;
            } else {
                const prev_dict: ?[]const u8 = if (desc.block_mode == .linked and history_len > 0)
                    history_buf[0..history_len]
                else
                    null;

                const decomp_len = safe_decomp.decompressSafeWithDict(raw_block, block_decomp_buf, prev_dict) catch {
                    return errors.FrameError.CorruptFrame;
                };
                const decomp_slice = block_decomp_buf[0..decomp_len];
                try w.writeAll(decomp_slice);
                if (desc.content_checksum) {
                    content_hasher.update(decomp_slice);
                }
                if (desc.block_mode == .linked) {
                    if (decomp_slice.len >= history_buf.len) {
                        @memcpy(&history_buf, decomp_slice[decomp_slice.len - history_buf.len ..]);
                        history_len = history_buf.len;
                    } else {
                        const keep = @min(history_len, history_buf.len - decomp_slice.len);
                        if (keep > 0) {
                            std.mem.copyForwards(u8, history_buf[0..keep], history_buf[history_len - keep .. history_len]);
                        }
                        @memcpy(history_buf[keep .. keep + decomp_slice.len], decomp_slice);
                        history_len = keep + decomp_slice.len;
                    }
                }
                total_uncompressed += decomp_len;
            }
        }

        // Validate content checksum
        if (desc.content_checksum) {
            var cc_buf: [4]u8 = undefined;
            try r.readSliceAll(&cc_buf);
            const expected_cc = endian.readU32Le(&cc_buf);
            if (content_hasher.digest() != expected_cc) {
                return errors.FrameError.ContentChecksumMismatch;
            }
        }
    }

    return total_uncompressed;
}

test "decompressStream with fixed reader and writer" {
    const writer_mod = @import("../frame/writer.zig");

    const message = "Streaming decompression with std.Io.Reader and Writer interfaces!";
    var frame_buf: [512]u8 = undefined;
    const frame_len = try writer_mod.compressFrame(message, &frame_buf, .{ .contentChecksum = true });

    var in_reader = Reader.fixed(frame_buf[0..frame_len]);

    var out_buf: [512]u8 = undefined;
    var out_writer = Writer.fixed(&out_buf);

    const decomp_len = try decompressStream(&in_reader, &out_writer, std.testing.allocator);
    try std.testing.expectEqualStrings(message, out_buf[0..decomp_len]);
}
