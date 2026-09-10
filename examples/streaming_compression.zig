//! Example: Chunked streaming compression using StreamingCompressor.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var sc = try lz4.StreamingCompressor.init(allocator, .{
        .blockMaxSize = .max64KB,
        .contentChecksum = true,
    });
    defer sc.deinit();

    var out_storage: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_storage);

    // Feed chunks incrementally
    try sc.write("Chunk 1: Streaming log message.\n", &writer);
    try sc.write("Chunk 2: Sensor reading at 21.5C.\n", &writer);
    try sc.finish(&writer);

    std.debug.print("Streamed frame produced: {d} bytes\n", .{writer.buffered().len});
}
