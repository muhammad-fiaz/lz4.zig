//! LZ4 Frame encoder producing standard interoperable LZ4 frames.

const std = @import("std");
const Allocator = std.mem.Allocator;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bounds = @import("../utils/bounds.zig");
const checksum = @import("../utils/checksum.zig");
const options_mod = @import("../options.zig");
const FrameOptions = options_mod.FrameOptions;
const BlockCompressionOptions = options_mod.BlockCompressionOptions;
const descriptor_mod = @import("descriptor.zig");
const FrameDescriptor = descriptor_mod.FrameDescriptor;
const header_mod = @import("header.zig");
const FrameHeader = header_mod.FrameHeader;
const block_mod = @import("block.zig");
const BlockHeader = block_mod.BlockHeader;
const comp_block = @import("../compress/block.zig");

/// Compresses `src` into a complete, standard LZ4 frame written to `dst`.
pub fn compressFrame(
    src: []const u8,
    dst: []u8,
    options: FrameOptions,
) errors.FrameError!usize {
    const desc = FrameDescriptor{
        .block_mode = options.blockMode,
        .block_checksum = options.blockChecksum,
        .content_checksum = options.contentChecksum,
        .content_size = options.contentSize,
        .dict_id = options.dictId,
        .block_max_size = options.blockMaxSize,
    };

    const header = FrameHeader{ .descriptor = desc };
    var op: usize = try header.encode(dst);

    var content_hasher = if (options.contentChecksum)
        checksum.XxHash32.init(0)
    else
        undefined;

    if (options.contentChecksum) {
        content_hasher.update(src);
    }

    const block_max_size = options.blockMaxSize.toBytes();
    const block_comp_opts = BlockCompressionOptions{
        .level = options.compressionLevel,
        .favorDecSpeed = options.favorDecSpeed,
    };

    var src_offset: usize = 0;
    while (src_offset < src.len or (src.len == 0 and src_offset == 0)) {
        const chunk_len = @min(src.len - src_offset, block_max_size);
        const chunk = src[src_offset..][0..chunk_len];
        src_offset += chunk_len;

        // Reserve space for block header (4 bytes)
        if (op + 4 > dst.len) return errors.FrameError.DstCapacityTooSmall;
        const block_header_pos = op;
        op += 4;

        var compressed = false;
        var payload_len: usize = chunk.len;

        // Try compression if chunk is large enough to potentially compress
        if (chunk.len >= constants.MIN_LENGTH) {
            const worst_case = bounds.compressBound(chunk.len);
            const remaining_dst = if (dst.len > op) dst.len - op else 0;

            if (remaining_dst >= worst_case) {
                const comp_len = comp_block.compressBlock(chunk, dst[op..][0..worst_case], block_comp_opts) catch 0;
                if (comp_len > 0 and comp_len < chunk.len) {
                    compressed = true;
                    payload_len = comp_len;
                    op += comp_len;
                }
            }
        }

        if (!compressed) {
            // Write uncompressed data block
            if (op + chunk.len > dst.len) return errors.FrameError.DstCapacityTooSmall;
            @memcpy(dst[op..][0..chunk.len], chunk);
            op += chunk.len;
        }

        // Fill block header: 4-byte LE size with bit 31 set if uncompressed
        try BlockHeader.encode(dst[block_header_pos..][0..4], payload_len, !compressed);

        // Optional Block Checksum
        if (options.blockChecksum) {
            if (op + 4 > dst.len) return errors.FrameError.DstCapacityTooSmall;
            const b_check = block_mod.computeBlockChecksum(dst[block_header_pos + 4 .. op]);
            endian.writeU32Le(dst[op..], b_check);
            op += 4;
        }

        if (src.len == 0) break;
    }

    // Write EndMark (0x00000000)
    op += try block_mod.writeEndMark(dst[op..]);

    // Optional Content Checksum
    if (options.contentChecksum) {
        if (op + 4 > dst.len) return errors.FrameError.DstCapacityTooSmall;
        const final_digest = content_hasher.digest();
        endian.writeU32Le(dst[op..], final_digest);
        op += 4;
    }

    return op;
}

/// Compresses `src` into a newly allocated standard LZ4 frame slice.
pub fn compressFrameAlloc(
    allocator: Allocator,
    src: []const u8,
    options: FrameOptions,
) (errors.FrameError || Allocator.Error)![]u8 {
    const bound = bounds.compressFrameBound(src.len, options);
    const buf = try allocator.alloc(u8, bound);
    errdefer allocator.free(buf);

    const written = try compressFrame(src, buf, options);
    return allocator.realloc(buf, written) catch buf[0..written];
}

test "compressFrame basic test" {
    const text = "A frame containing repetitive text! A frame containing repetitive text!";
    var frame_buf: [256]u8 = undefined;

    const written = try compressFrame(text, &frame_buf, .{});
    try std.testing.expect(written > constants.FRAME_HEADER_MIN_SIZE);

    const alloc_frame = try compressFrameAlloc(std.testing.allocator, text, .{ .contentChecksum = true });
    defer std.testing.allocator.free(alloc_frame);
    try std.testing.expect(alloc_frame.len > 0);
}
