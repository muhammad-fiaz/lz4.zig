---
title: Streaming Compression Example
description: Incremental chunk-by-chunk push streaming using StreamingCompressor in lz4.zig.
---

# Streaming Compression Example

When processing continuous data streams (such as live application logs, network sockets, or sensor streams), data arrives in incremental fragments over time. `StreamingCompressor` provides an incremental push interface that buffers input into full blocks and emits frame-compliant bytes directly to any `std.Io.Writer`.

## Overview

- **Struct**: [`lz4.StreamingCompressor`](/api/stream-compressor)
- **Pattern**: Push-based streaming via `.write(chunk, writer)` followed by `.finish(writer)`
- **Buffering**: Emits complete LZ4 blocks whenever accumulated input reaches `blockMaxSize`

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Initialize StreamingCompressor
    var sc = try lz4.StreamingCompressor.init(allocator, .{
        .blockMaxSize = .max64KB,
        .contentChecksum = true,
    });
    defer sc.deinit();

    // 2. Set up output buffer with std.Io.Writer.fixed
    var out_storage: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_storage);

    // 3. Feed chunks incrementally
    try sc.write("Chunk 1: Streaming log message.\n", &writer);
    try sc.write("Chunk 2: Sensor reading at 21.5C.\n", &writer);
    try sc.finish(&writer);

    std.debug.print("Streamed frame produced: {d} bytes\n", .{writer.buffered().len});
}
```

---

## Step-by-Step Breakdown

1. **`StreamingCompressor.init`**: Allocates the internal ring buffer for block buffering and prepares the frame header state.
2. **`sc.write(chunk, &writer)`**:
   - On the first call, it writes the standard LZ4 Frame Header to `writer`.
   - Accumulates input bytes into the internal block buffer.
   - If the accumulated bytes reach `blockMaxSize`, compresses the block and immediately writes it to `writer`.
3. **`sc.finish(&writer)`**:
   - Flushes any remaining bytes in the buffer as a final block.
   - Writes the 4-byte `END_MARK` (`0x00000000`).
   - Appends the 4-byte xxHash-32 content checksum (since `contentChecksum = true`).
   - Flushes the underlying writer.

---

## Running via Build System

```bash
zig build run-streaming_compression
```

### Expected Output

```console
Streamed frame produced: 83 bytes
```
