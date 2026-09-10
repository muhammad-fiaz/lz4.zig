//! Example: Stateful block streaming decompression for sequential chunks.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var c_stream = try lz4.BlockCompressStream.init(allocator, .{});
    defer c_stream.deinit();

    var d_stream = try lz4.BlockDecompressStream.init(allocator);
    defer d_stream.deinit();

    const chunk1 = "Segment 1: Logging sensor temperature at 24.5C. ";
    const chunk2 = "Segment 2: Logging sensor temperature at 25.1C. ";

    var c1: [128]u8 = undefined;
    var c2: [128]u8 = undefined;

    const len1 = try c_stream.compressContinue(chunk1, &c1);
    const len2 = try c_stream.compressContinue(chunk2, &c2);

    var d1: [128]u8 = undefined;
    var d2: [128]u8 = undefined;

    const dlen1 = try d_stream.decompressContinue(c1[0..len1], &d1);
    const dlen2 = try d_stream.decompressContinue(c2[0..len2], &d2);

    std.debug.print("Restored 1: '{s}'\n", .{d1[0..dlen1]});
    std.debug.print("Restored 2: '{s}'\n", .{d2[0..dlen2]});
}
