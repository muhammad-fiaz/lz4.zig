//! Example: Inspecting and parsing LZ4 Frame metadata before decompressing.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const original = "Sample payload for inspection of frame metadata headers.";

    var frame_buf: [512]u8 = undefined;
    const frame_len = try lz4.compressFrame(original, &frame_buf, .{
        .blockMaxSize = .max256KB,
        .blockMode = .independent,
        .contentChecksum = true,
        .contentSize = original.len,
    });

    // Inspect frame metadata
    const info = try lz4.getFrameInfo(frame_buf[0..frame_len]);

    std.debug.print("Frame Descriptor Information:\n", .{});
    std.debug.print("  Format Version:   {d}\n", .{info.version});
    std.debug.print("  Block Max Size:   {d} bytes\n", .{info.block_max_size.toBytes()});
    std.debug.print("  Block Mode:       {s}\n", .{@tagName(info.block_mode)});
    std.debug.print("  Content Checksum: {}\n", .{info.content_checksum});
    std.debug.print("  Declared Size:    {?d} bytes\n", .{info.content_size});
}
