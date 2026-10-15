//! Example: Streaming and one-shot decompression using explicit std.Io pipelines and chunked decoders.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const original = "Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!";

    // 1. One-Shot Compression & Decompression
    // -------------------------------------------------------------------------
    // One-shot allocating frame compression and decompression
    const one_shot_frame = try lz4.compress(allocator, original);
    defer allocator.free(one_shot_frame);

    const one_shot_restored = try lz4.decompress(allocator, one_shot_frame);
    defer allocator.free(one_shot_restored);

    std.debug.print("One-shot restored ({d} bytes): '{s}'\n", .{
        one_shot_restored.len,
        one_shot_restored,
    });

    // Zero-allocation caller-buffer one-shot compression and decompression
    var comp_buffer: [256]u8 = undefined;
    var decomp_buffer: [256]u8 = undefined;

    const frame_bytes = try lz4.compressInto(original, &comp_buffer);
    const restored_bytes = try lz4.decompressInto(comp_buffer[0..frame_bytes], &decomp_buffer);

    std.debug.print("Caller-buffer one-shot restored ({d} bytes): '{s}'\n", .{
        restored_bytes,
        decomp_buffer[0..restored_bytes],
    });

    // 2. Explicit std.Io Streaming Decompression
    // -------------------------------------------------------------------------
    // Streaming decompression using explicit std.Io.Reader and std.Io.Writer
    var in_reader = std.Io.Reader.fixed(one_shot_frame);
    var stream_storage: [256]u8 = undefined;
    var out_writer = std.Io.Writer.fixed(&stream_storage);

    var decompressor = lz4.StreamingDecompressor.init(allocator, .{});
    defer decompressor.deinit();

    const streamed_count = try decompressor.read(&in_reader, &out_writer);
    std.debug.print("Explicit std.Io stream restored ({d} bytes): '{s}'\n", .{
        streamed_count,
        stream_storage[0..streamed_count],
    });

    // Direct pipeline decompression via lz4.decompressStream
    var pipe_reader = std.Io.Reader.fixed(one_shot_frame);
    var pipe_storage: [256]u8 = undefined;
    var pipe_writer = std.Io.Writer.fixed(&pipe_storage);

    const pipe_count = try lz4.decompressStream(allocator, &pipe_reader, &pipe_writer, .{});
    std.debug.print("Pipeline std.Io decompressStream ({d} bytes): '{s}'\n", .{
        pipe_count,
        pipe_storage[0..pipe_count],
    });

    // 3. Incremental Chunked Push/Pull Decompression
    // -------------------------------------------------------------------------
    decompressor.reset();

    // Feed compressed frame in chunks (simulating packets over network or IPC)
    const mid = one_shot_frame.len / 2;
    try decompressor.feed(one_shot_frame[0..mid]);
    try decompressor.feed(one_shot_frame[mid..]);

    var chunk_buf: [256]u8 = undefined;
    const chunk_restored = try decompressor.take(&chunk_buf);

    std.debug.print("Chunked pull restored ({d} bytes): '{s}'\n", .{
        chunk_restored,
        chunk_buf[0..chunk_restored],
    });
}
