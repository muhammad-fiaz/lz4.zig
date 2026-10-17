---
title: Streaming Compression Example
description: Explicit std.Io streaming, one-shot compression, and chunk-by-chunk push streaming using StreamingCompressor in lz4.zig.
keywords: streaming compression example, StreamingCompressor, push streaming zig, std.io.writer, compressStream
---

# Streaming Compression Example

When processing data in high-performance Zig applications, `lz4.zig` supports multiple compression workflows:
1. **One-Shot Compression**: Fast frame compression into allocated slices (`lz4.compress`) or caller-provided fixed buffers (`lz4.compressInto`).
2. **Incremental Push Streaming**: `StreamingCompressor` buffers continuous fragments into full blocks and emits frame-compliant bytes directly to any `std.Io.Writer`.
3. **Pipeline Stream Compression**: `lz4.compressStream` connects a `std.Io.Reader` directly to a `std.Io.Writer`.

## Overview

- **Struct**: [`lz4.StreamingCompressor`](/api/stream-compressor)
- **Functions**: [`lz4.compressStream`](/api/#streaming-io-functions), [`lz4.compress`](/api/#top-level-one-shot-functions), [`lz4.compressInto`](/api/#top-level-one-shot-functions)
- **Pattern**: Push-based streaming via `.write(chunk, writer)` and `.finish(writer)`
- **Buffering**: Emits complete LZ4 blocks whenever accumulated input reaches `blockMaxSize`

---

## Code

```zig
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
```

---

## Step-by-Step Breakdown

1. **One-Shot APIs**:
   - `lz4.compress(allocator, sample)` encodes the entire payload into a dynamically allocated LZ4 frame.
   - `lz4.compressInto(sample, &fixed_buf)` writes the frame directly into a caller-allocated slice with 0 allocations.
2. **`StreamingCompressor`**:
   - `StreamingCompressor.init`: Prepares block buffering state according to the requested `blockMaxSize`.
   - `sc.write(chunk, &writer)`: Emits frame header upon first write, buffers chunks, and writes filled blocks to `writer`.
   - `sc.finish(&writer)`: Flushes remaining buffered bytes, writes the `END_MARK`, appends checksum, and flushes `writer`.
3. **Pipeline Compression**:
   - `lz4.compressStream`: Streams data between any standard Zig 0.17 `std.Io.Reader` and `std.Io.Writer` with minimal memory usage.

---

## Running via Build System

```bash
zig build run-streaming_compression
```

### Expected Output

```console
One-shot allocated frame: 77 bytes
One-shot caller-buffer frame: 69 bytes
Streamed chunked frame produced: 83 bytes
Pipeline compressStream produced: 76 bytes
```

