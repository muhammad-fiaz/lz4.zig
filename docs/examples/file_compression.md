---
title: File Compression Example
description: Compressing and decompressing disk files directly using lz4.zig and Zig 0.17 std.Io.
---

# File Compression Example

This example demonstrates how to compress an on-disk file into an official `.lz4` frame container and decompress it back using `lz4.compressFile` and `lz4.decompressFile`.

## Overview

- **Functions**: [`lz4.compressFile`](/api/#streaming-io-functions) & [`lz4.decompressFile`](/api/#streaming-io-functions)
- **Integration**: Leverages Zig 0.17's standard `std.Io` and `std.Io.Threaded`
- **Compatibility**: The generated files can be inspected and decompressed using the official upstream `lz4` CLI tool (`lz4 -d output.lz4`)

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");
const Io = std.Io;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = Io.Dir.cwd();
    const src_file = "example_input.txt";
    const dst_file = "example_output.lz4";
    const restored_file = "example_restored.txt";

    defer {
        cwd.deleteFile(io, src_file) catch {};
        cwd.deleteFile(io, dst_file) catch {};
        cwd.deleteFile(io, restored_file) catch {};
    }

    // 1. Create sample source file
    {
        const out = try cwd.createFile(io, src_file, .{});
        defer out.close(io);
        var buf: [256]u8 = undefined;
        var w = out.writer(io, &buf);
        try w.interface.writeAll("Native Zig LZ4 file compression using std.Io and LZ4 frame format!\n");
        try w.interface.flush();
    }

    // 2. Compress file to destination frame file
    try lz4.compressFile(io, src_file, dst_file, .{}, allocator);
    std.debug.print("Successfully compressed '{s}' to '{s}'\n", .{ src_file, dst_file });

    // 3. Decompress frame file back to restored file
    try lz4.decompressFile(io, dst_file, restored_file, allocator);
    std.debug.print("Successfully decompressed '{s}' to '{s}'\n", .{ dst_file, restored_file });
}
```

---

## Step-by-Step Explanation

1. **`std.Io.Threaded`**: Zig 0.17 introduces explicit asynchronous and threaded I/O interfaces via `std.Io`.
2. **`createFile` & `writer`**: Creates the sample input file with buffered writing.
3. **`lz4.compressFile`**: Streams the input file in 64 KiB blocks into the standard LZ4 frame format without buffering the whole file in RAM.
4. **`lz4.decompressFile`**: Streams the compressed LZ4 frame from disk and writes restored blocks directly to destination.
5. **Cleanup**: Deletes temporary files created during the demonstration.

---

## Running via Build System

```bash
# Run file compression demonstration
zig build run-compress_file

# Run file decompression demonstration
zig build run-decompress_file
```

### Expected Output

```console
Successfully compressed 'example_input.txt' to 'example_output.lz4'
Successfully decompressed 'example_archive.lz4' to 'example_restored.txt'
```

