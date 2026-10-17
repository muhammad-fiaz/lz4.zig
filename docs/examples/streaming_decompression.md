---
title: Streaming Decompression Example
description: Explicit std.Io streaming, one-shot frame decompression, and chunked pull decompression in lz4.zig.
keywords: streaming decompression example, StreamingDecompressor, feed take, std.io.reader, decompressStream
---

# Streaming Decompression Example

When processing incoming data from streams, network sockets, or files, `lz4.zig` provides flexible decompression APIs:
1. **One-Shot Decompression**: Immediate decompression with dynamic allocation (`lz4.decompress`) or zero-allocation caller buffers (`lz4.decompressInto`).
2. **Explicit `std.Io` Streaming**: Seamless integration with Zig 0.17's standard `std.Io.Reader` and `std.Io.Writer` via `decompressor.read()` and `lz4.decompressStream()`.
3. **Chunked Push/Pull Streaming**: Flexible incremental feeding via `decompressor.feed()` and draining via `decompressor.take()`.

## Overview

- **Struct**: [`lz4.StreamingDecompressor`](/api/stream-decompressor)
- **Functions**: [`lz4.decompressStream`](/api/#streaming-io-functions), [`lz4.decompress`](/api/#top-level-one-shot-functions), [`lz4.decompressInto`](/api/#top-level-one-shot-functions)
- **Pattern**: Unified one-shot, standard `std.Io` stream processing, and chunked pull decompression
- **Buffer Safety**: Validates checksums, frame headers, and block sizes with bounds checking

---

## Code

```zig
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
```

---

## Step-by-Step Breakdown

1. **One-Shot APIs**:
   - `lz4.compress(allocator, src)` and `lz4.decompress(allocator, frame)` handle end-to-end framing and dynamic allocation.
   - `lz4.compressInto(src, dst)` and `lz4.decompressInto(frame, dst)` execute without allocating heap memory, ideal for fixed-buffer environments.
2. **Explicit `std.Io` Streaming**:
   - `StreamingDecompressor.read(&reader, &writer)` bridges an input reader directly to an output writer.
   - `lz4.decompressStream(allocator, &reader, &writer, opts)` provides a direct, low-overhead pipeline across standard I/O streams.
3. **Chunked Feed & Take**:
   - `decompressor.feed(chunk)` queues arriving packets.
   - `decompressor.take(&buf)` drains decoded bytes into caller slices.

---

## Running via Build System

```bash
zig build run-streaming_decompression
```

### Expected Output

```console
One-shot restored (98 bytes): 'Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!'
Caller-buffer one-shot restored (98 bytes): 'Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!'
Explicit std.Io stream restored (98 bytes): 'Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!'
Pipeline std.Io decompressStream (98 bytes): 'Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!'
Chunked pull restored (98 bytes): 'Decompressing data with native Zig 0.17.0 using both explicit std.Io streams and chunked decoders!'
```

