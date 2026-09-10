//! Example: Handling multiple concatenated frames and skippable metadata frames.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var multi_frame_stream: [1024]u8 = undefined;
    var p: usize = 0;

    // Frame 1
    const frame1_data = "First data stream segment. ";
    p += try lz4.compressFrame(frame1_data, multi_frame_stream[p..], .{ .contentChecksum = true });

    // Skippable User Metadata Frame
    const metadata = "User metadata: timestamp=2026-10-17 author=muhammad-fiaz";
    p += try lz4.frame.skippable.encodeSkippableFrame(multi_frame_stream[p..], 0, metadata);

    // Frame 2
    const frame2_data = "Second data stream segment.";
    p += try lz4.compressFrame(frame2_data, multi_frame_stream[p..], .{ .contentChecksum = true });

    std.debug.print("Created concatenated stream with 2 data frames and 1 skippable frame ({d} bytes)\n", .{p});

    // Decompress the whole combined stream: transparently decodes and skips user metadata
    var restored: [512]u8 = undefined;
    const restored_len = try lz4.decompressFrame(multi_frame_stream[0..p], &restored);

    std.debug.print("Combined restored content ({d} bytes):\n'{s}'\n", .{
        restored_len,
        restored[0..restored_len],
    });
}
