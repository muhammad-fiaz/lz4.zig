---
title: Streaming Decompression Example
description: Incremental pull-based decompression using StreamingDecompressor in lz4.zig.
---

# Streaming Decompression Example

When reading from asynchronous networks, TLS streams, or chunked HTTP connections, compressed bytes arrive in arbitrary packets. `StreamingDecompressor` allows applications to feed incoming fragments via `feed()` and drain uncompressed bytes via `take()`.

## Overview

- **Struct**: [`lz4.StreamingDecompressor`](/api/stream-decompressor)
- **Pattern**: Pull-based consumer via `.feed(chunk)` and `.take(out_buf)`
- **Buffer Safety**: Dynamically accumulates inputs without risking buffer overflow

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const original = "Chunked streaming decompression receiving slices over network or pipe.";
    const compressed = try lz4.compress(allocator, original);
    defer allocator.free(compressed);

    // 1. Initialize StreamingDecompressor
    var sd = lz4.StreamingDecompressor.init(allocator, .{});
    defer sd.deinit();

    // 2. Feed chunk into streaming decompressor
    try sd.feed(compressed);

    // 3. Extract decoded bytes into caller buffer
    var out_buf: [256]u8 = undefined;
    const n = try sd.take(&out_buf);

    std.debug.print("Stream restored ({d} bytes): '{s}'\n", .{ n, out_buf[0..n] });
}
```

---

## Step-by-Step Breakdown

1. **`StreamingDecompressor.init`**: Prepares internal input and output queues.
2. **`sd.feed(compressed)`**: Accepts any slice of incoming bytes (partial frame header, partial block, or multiple concatenated blocks).
3. **`sd.take(&out_buf)`**:
   - Parses completed blocks from the input queue.
   - Decompresses data directly into the caller's slice.
   - Returns the exact number of bytes transferred. If the caller buffer is full but more data remains, subsequent calls to `take()` continue transferring the remaining bytes until returning `0`.

---

## Running via Build System

```bash
zig build run-streaming_decompression
```

### Expected Output

```console
Stream restored (70 bytes): 'Chunked streaming decompression receiving slices over network or pipe.'
```
