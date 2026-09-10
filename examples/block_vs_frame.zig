//! Example: Understanding the difference between raw LZ4 blocks and LZ4 frames.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const data = "Raw blocks vs Self-contained Frames in LZ4 ecosystems.";

    // 1. Raw Block: no magic number, no header, no checksums.
    // Out-of-band metadata required to decode (uncompressed size must be known).
    var raw_block_buf: [128]u8 = undefined;
    const raw_len = try lz4.compress(data, &raw_block_buf);
    std.debug.print("Raw block bytes: {d} (no magic, no framing)\n", .{raw_len});

    // 2. LZ4 Frame: self-contained format with magic 0x184D2204, descriptor,
    // block headers, optional checksums, and EndMark. Interoperable with `lz4` CLI.
    var frame_buf: [256]u8 = undefined;
    const frame_len = try lz4.compressFrame(data, &frame_buf, .{
        .contentChecksum = true,
        .contentSize = data.len,
    });
    std.debug.print("LZ4 Frame bytes: {d} (starts with 0x{X:0>8})\n", .{
        frame_len,
        std.mem.readInt(u32, frame_buf[0..4], .little),
    });
}
