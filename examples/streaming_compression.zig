//! Example: Streaming and one-shot compression using explicit std.Io writers and StreamingCompressor.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. One-Shot Compression (Allocating and Caller-Buffer)
    // -------------------------------------------------------------------------
    const sample = "High-performance compression in native Zig 0.17.0!";

    const allocated_frame = try lz4.compress(allocator, sample);
    defer allocator.free(allocated_frame);
    std.debug.print("One-shot allocated frame: {d} bytes\n", .{allocated_frame.len});

    var fixed_buf: [256]u8 = undefined;
    const caller_buf_len = try lz4.compressInto(sample, &fixed_buf);
    std.debug.print("One-shot caller-buffer frame: {d} bytes\n", .{caller_buf_len});

    // 2. Incremental Push Streaming with StreamingCompressor & std.Io.Writer
    // -------------------------------------------------------------------------
    var sc = try lz4.StreamingCompressor.init(allocator, .{
        .blockMaxSize = .max64KB,
        .contentChecksum = true,
    });
    defer sc.deinit();

    var out_storage: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_storage);

    // Feed chunks incrementally into the explicit writer
    try sc.write("Chunk 1: Streaming log message.\n", &writer);
    try sc.write("Chunk 2: Sensor reading at 21.5C.\n", &writer);
    try sc.finish(&writer);

    const chunked_bytes = writer.buffered().len;
    std.debug.print("Streamed chunked frame produced: {d} bytes\n", .{chunked_bytes});

    // 3. Direct Streaming Compression via std.Io.Reader and std.Io.Writer
    // -------------------------------------------------------------------------
    var in_reader = std.Io.Reader.fixed("Direct stream pipeline compression using lz4.compressStream.");
    var pipe_storage: [256]u8 = undefined;
    var pipe_writer = std.Io.Writer.fixed(&pipe_storage);

    const pipe_bytes = try lz4.compressStream(allocator, &in_reader, &pipe_writer, .{
        .contentChecksum = true,
    });
    std.debug.print("Pipeline compressStream produced: {d} bytes\n", .{pipe_bytes});
}
