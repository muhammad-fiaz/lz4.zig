---
title: Streaming Guide
description: Streaming compression and decompression using Zig 0.17 std.Io readers/writers and chunked streaming processors.
---

# Streaming Guide

`lz4.zig` offers two streaming models:
1. **I/O Pipeline Streaming**: Direct streaming using Zig 0.17's standard `std.Io.Reader` and `std.Io.Writer`.
2. **Chunked Push/Pull Streaming**: Stateful `StreamingCompressor` and `StreamingDecompressor` for network sockets, event loops, and incremental chunk buffers.

---

## Standard I/O Pipelines (`compressStream` & `decompressStream`)

For files, pipes, sockets, and memory streams wrapped in `std.Io.Reader` and `std.Io.Writer`:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn compressFileToStream(
    allocator: std.mem.Allocator,
    input_file: std.fs.File,
    output_file: std.fs.File,
) !void {
    // 1. Create buffered reader and writer using Zig 0.17 std.Io
    var in_buf: [65536]u8 = undefined;
    var out_buf: [65536]u8 = undefined;

    var reader = input_file.reader(&in_buf);
    var writer = output_file.writer(&out_buf);

    // 2. Stream compression into LZ4 frame
    _ = try lz4.compressStream(allocator, &reader.interface, &writer.interface, .{
        .level = 1,
        .contentChecksum = true,
    });
    try writer.interface.flush();
}

pub fn decompressStreamToFile(
    allocator: std.mem.Allocator,
    compressed_file: std.fs.File,
    restored_file: std.fs.File,
) !void {
    var in_buf: [65536]u8 = undefined;
    var out_buf: [65536]u8 = undefined;

    var reader = compressed_file.reader(&in_buf);
    var writer = restored_file.writer(&out_buf);

    _ = try lz4.decompressStream(allocator, &reader.interface, &writer.interface, .{});
    try writer.interface.flush();
}
```

---

## File Compression Convenience Functions

For direct on-disk operations, `lz4.zig` provides ready-to-use file helpers leveraging Zig 0.17 `std.Io`:

```zig
var threaded: std.Io.Threaded = .init(allocator, .{});
defer threaded.deinit();
const io = threaded.io();

// Compress directly to an LZ4 file
try lz4.compressFile(io, "dataset.csv", "dataset.csv.lz4", .{
    .compressionLevel = 9,
    .contentChecksum = true,
}, allocator);

// Decompress an LZ4 file
try lz4.decompressFile(io, "dataset.csv.lz4", "dataset_restored.csv", allocator);
```

---

## Stateful Chunked Streaming

When dealing with asynchronous network sockets or chunked protocols, data arrives in arbitrary fragment sizes.

### Incremental Compression (`StreamingCompressor`)

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn streamChunks(allocator: std.mem.Allocator, chunks: [][]const u8, out_writer: *std.Io.Writer) !void {
    var compressor = try lz4.StreamingCompressor.init(allocator, .{
        .level = 1,
        .contentChecksum = true,
    });
    defer compressor.deinit();

    // Write chunks incrementally as they arrive
    for (chunks) |chunk| {
        try compressor.write(chunk, out_writer);
    }

    // Finish frame (emits EndMark and optional Content Checksum)
    try compressor.finish(out_writer);
}
```

### Incremental Decompression (`StreamingDecompressor`)

Feed compressed byte slices into the decompressor, and extract decompressed bytes into your output buffers:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn consumeStream(allocator: std.mem.Allocator, network_chunks: [][]const u8) !void {
    var decompressor = lz4.StreamingDecompressor.init(allocator, .{});
    defer decompressor.deinit();

    var temp_buf: [4096]u8 = undefined;

    for (network_chunks) |chunk| {
        // 1. Feed incoming chunk
        try decompressor.feed(chunk);

        // 2. Drain available uncompressed data
        while (true) {
            const count = try decompressor.take(&temp_buf);
            if (count == 0) break;

            // Process decompressed buffer fragment...
            std.debug.print("Extracted {d} decompressed bytes\n", .{count});
        }
    }
}
```
