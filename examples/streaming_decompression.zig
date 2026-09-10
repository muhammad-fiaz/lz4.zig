//! Example: Chunked streaming decompression using StreamingDecompressor.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const original = "Chunked streaming decompression receiving slices over network or pipe.";
    const compressed = try lz4.compress(allocator, original);
    defer allocator.free(compressed);

    var sd = lz4.StreamingDecompressor.init(allocator, .{});
    defer sd.deinit();

    // Feed chunk into streaming decompressor
    try sd.feed(compressed);

    var out_buf: [256]u8 = undefined;
    const n = try sd.take(&out_buf);

    std.debug.print("Stream restored ({d} bytes): '{s}'\n", .{ n, out_buf[0..n] });
}
