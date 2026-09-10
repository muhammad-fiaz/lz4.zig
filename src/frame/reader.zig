//! LZ4 Frame decoder for decompressing standard and concatenated LZ4 frames.

const std = @import("std");
const Allocator = std.mem.Allocator;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const checksum = @import("../utils/checksum.zig");
const options_mod = @import("../options.zig");
const descriptor_mod = @import("descriptor.zig");
const FrameDescriptor = descriptor_mod.FrameDescriptor;
const header_mod = @import("header.zig");
const FrameHeader = header_mod.FrameHeader;
const block_mod = @import("block.zig");
const BlockHeader = block_mod.BlockHeader;
const skippable_mod = @import("skippable.zig");
const safe_decomp = @import("../decompress/safe.zig");

/// Parses the Frame Descriptor from the beginning of `src` without decompressing payload.
pub fn getFrameInfo(src: []const u8) errors.FrameError!FrameDescriptor {
    var p: usize = 0;
    while (p + 4 <= src.len) {
        const magic = endian.readU32Le(src[p..][0..4]);
        if (skippable_mod.isSkippableMagic(magic)) {
            const skipped = try skippable_mod.skipFrame(src[p..]);
            p += skipped;
            continue;
        }
        if (magic == constants.FRAME_MAGIC) {
            const res = try FrameHeader.decode(src[p..]);
            return res.header.descriptor;
        }
        return errors.FrameError.InvalidMagic;
    }
    return errors.FrameError.SrcBufferTooSmall;
}

/// Decompresses an LZ4 frame (including optional concatenated frames and skippable frames) into `dst`.
/// Returns total uncompressed bytes written to `dst`.
pub fn decompressFrame(src: []const u8, dst: []u8) errors.FrameError!usize {
    var ip: usize = 0;
    var op: usize = 0;

    while (ip < src.len) {
        // Check for skippable frames
        if (ip + 4 <= src.len) {
            const magic = endian.readU32Le(src[ip..][0..4]);
            if (skippable_mod.isSkippableMagic(magic)) {
                const skipped = try skippable_mod.skipFrame(src[ip..]);
                ip += skipped;
                continue;
            }
        }

        // Decode Frame Header
        const header_res = try FrameHeader.decode(src[ip..]);
        const desc = header_res.header.descriptor;
        ip += header_res.bytes_consumed;

        var content_hasher = if (desc.content_checksum)
            checksum.XxHash32.init(0)
        else
            undefined;

        const max_block_size = desc.block_max_size.toBytes();
        const frame_start_op = op;

        // Loop over data blocks until EndMark
        while (true) {
            if (ip + 4 > src.len) return errors.FrameError.PrematureEndOfFrame;

            const b_hdr = try BlockHeader.parse(src[ip..]);
            ip += 4;

            if (b_hdr.is_end_mark) {
                break;
            }

            if (b_hdr.size > max_block_size) {
                return errors.FrameError.BlockSizeTooLarge;
            }

            if (ip + b_hdr.size > src.len) {
                return errors.FrameError.PrematureEndOfFrame;
            }

            const raw_block = src[ip..][0..b_hdr.size];
            ip += b_hdr.size;

            // Block checksum verification
            if (desc.block_checksum) {
                if (ip + 4 > src.len) return errors.FrameError.PrematureEndOfFrame;
                const expected_bc = endian.readU32Le(src[ip..]);
                ip += 4;
                if (!block_mod.verifyBlockChecksum(raw_block, expected_bc)) {
                    return errors.FrameError.BlockChecksumMismatch;
                }
            }

            // Decompress or copy payload
            if (b_hdr.is_uncompressed) {
                if (op + raw_block.len > dst.len) return errors.FrameError.DstCapacityTooSmall;
                @memcpy(dst[op..][0..raw_block.len], raw_block);
                if (desc.content_checksum) {
                    content_hasher.update(raw_block);
                }
                op += raw_block.len;
            } else {
                const avail_dst = dst[op..];
                const prev_history: ?[]const u8 = if (desc.block_mode == .linked and op > frame_start_op) blk: {
                    const avail_hist = op - frame_start_op;
                    const hist_len = @min(avail_hist, constants.BLOCK_SIZE_64KB);
                    break :blk dst[op - hist_len .. op];
                } else null;

                const decomp_len = safe_decomp.decompressSafeWithDict(raw_block, avail_dst, prev_history) catch |err| switch (err) {
                    error.DstCapacityTooSmall => return errors.FrameError.DstCapacityTooSmall,
                    else => return errors.FrameError.CorruptFrame,
                };
                if (desc.content_checksum) {
                    content_hasher.update(dst[op..][0..decomp_len]);
                }
                op += decomp_len;
            }
        }

        // Content Checksum verification
        if (desc.content_checksum) {
            if (ip + 4 > src.len) return errors.FrameError.PrematureEndOfFrame;
            const expected_cc = endian.readU32Le(src[ip..]);
            ip += 4;
            if (content_hasher.digest() != expected_cc) {
                return errors.FrameError.ContentChecksumMismatch;
            }
        }

        // Validate content size if provided
        if (desc.content_size) |expected_size| {
            const frame_decoded_size: u64 = op - frame_start_op;
            if (expected_size != frame_decoded_size) {
                return errors.FrameError.CorruptFrame;
            }
        }
    }

    return op;
}

/// Decompresses an LZ4 frame into newly allocated memory.
pub fn decompressFrameAlloc(
    allocator: Allocator,
    src: []const u8,
    max_uncompressed_size: usize,
) (errors.FrameError || Allocator.Error)![]u8 {
    // If the frame header includes content_size, we can allocate exactly what's needed
    const exact_size: ?usize = if (getFrameInfo(src)) |desc| blk: {
        if (desc.content_size) |sz| {
            break :blk std.math.cast(usize, sz) orelse return errors.FrameError.DstCapacityTooSmall;
        }
        break :blk null;
    } else |_| null;
    const alloc_size = exact_size orelse max_uncompressed_size;

    const buf = try allocator.alloc(u8, alloc_size);
    errdefer allocator.free(buf);

    const decoded = try decompressFrame(src, buf);
    return allocator.realloc(buf, decoded) catch buf[0..decoded];
}

test "decompressFrame roundtrip with checksums and content size" {
    const writer = @import("writer.zig");

    const message = "The frame contains structured data with content checksum and block checksum!";
    var comp: [512]u8 = undefined;

    const comp_len = try writer.compressFrame(message, &comp, .{
        .contentChecksum = true,
        .blockChecksum = true,
        .contentSize = message.len,
    });

    var decomp: [512]u8 = undefined;
    const decomp_len = try decompressFrame(comp[0..comp_len], &decomp);

    try std.testing.expectEqualStrings(message, decomp[0..decomp_len]);

    const alloc_decomp = try decompressFrameAlloc(std.testing.allocator, comp[0..comp_len], 1024);
    defer std.testing.allocator.free(alloc_decomp);
    try std.testing.expectEqualStrings(message, alloc_decomp);
}
