---
title: I/O Pipeline Example
description: Pipelining compression and decompression directly between std.Io.Reader and std.Io.Writer in Zig 0.17.0.
keywords: io pipeline example, compressStream, decompressStream, std.io.reader, std.io.writer, streaming pipeline
---

# I/O Pipeline Example

`lz4.zig` features first-class support for the Zig 0.17 standard `std.Io.Reader` and `std.Io.Writer` interfaces, enabling zero-copy pipelines between file descriptors, network sockets, ring buffers, and memory streams.

## Overview

- **Functions**: [`lz4.compressStream`](/api/#streaming-io-functions) & [`lz4.decompressStream`](/api/#streaming-io-functions)
- **Memory Efficiency**: Streams in 64 KiB block increments, keeping peak RAM consumption constant regardless of stream length

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const payload = "Streaming through std.Io.Reader and std.Io.Writer in pure native Zig 0.17.0!";

    // 1. Pipeline compression using std.Io
    var in_reader = std.Io.Reader.fixed(payload);
    var compressed_storage: [512]u8 = undefined;
    var comp_writer = std.Io.Writer.fixed(&compressed_storage);

    const comp_bytes = try lz4.compressStream(
        allocator,
        &in_reader,
        &comp_writer,
        .{ .contentChecksum = true },
    );
    std.debug.print("Pipeline compressed: {d} bytes (original: {d} bytes)\n", .{
        comp_bytes,
        payload.len,
    });

    // 2. Pipeline decompression using std.Io
    var comp_reader = std.Io.Reader.fixed(compressed_storage[0..comp_bytes]);
    var restored_storage: [512]u8 = undefined;
    var decomp_writer = std.Io.Writer.fixed(&restored_storage);

    const decomp_bytes = try lz4.decompressStream(
        allocator,
        &comp_reader,
        &decomp_writer,
        .{},
    );

    std.debug.print("Pipeline restored ({d} bytes): '{s}'\n", .{
        decomp_bytes,
        restored_storage[0..decomp_bytes],
    });
}
```

---

## Step-by-Step Breakdown

1. **`std.Io.Reader.fixed(payload)`**: Wraps a static byte slice into a standard reader interface without any heap allocation.
2. **`std.Io.Writer.fixed(&compressed_storage)`**: Wraps a destination buffer into a standard writer interface.
3. **`lz4.compressStream`**: Reads blocks incrementally from `in_reader`, compresses them, and writes frame-formatted blocks directly into `comp_writer`.
4. **`lz4.decompressStream`**: Reads blocks from `comp_reader`, decompresses each block, verifies checksums, and emits uncompressed data to `decomp_writer`.

---

## Running via Build System

```bash
zig build run-io_pipeline
```

### Expected Output

```console
Pipeline compressed: 93 bytes (original: 76 bytes)
Pipeline restored (76 bytes): 'Streaming through std.Io.Reader and std.Io.Writer in pure native Zig 0.17.0!'
```
