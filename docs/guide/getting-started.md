---
title: Getting Started
description: Quick start guide to compressing and decompressing data with lz4.zig in native Zig 0.17.0.
---

# Getting Started

`lz4.zig` is a modern, pure Zig library for the LZ4 compression format. It provides high-performance compression and decompression without any C runtime bindings or external dependencies.

## Key Concepts

LZ4 operates on two standard formats:
1. **LZ4 Frames (`.lz4`)**: The standard container format containing a magic number (`0x184D2204`), descriptors, chunked blocks, and optional xxHash-32 checksums. This format is interoperable with the official `lz4` command-line utility.
2. **LZ4 Blocks**: Raw compressed streams consisting of token-based sequences of literals and match copies. Blocks are ideal for embedding directly in database engines, cache records, or custom network protocols.

`lz4.zig` handles both formats seamlessly.

---

## One-Shot Operations (With Allocator)

When dynamic memory is preferred, pass an `Allocator` as the first argument:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const payload = "Hello, high-speed LZ4 compression from native Zig!";

    // 1. Compress into an allocated LZ4 frame slice
    const compressed = try lz4.compress(allocator, payload);
    defer allocator.free(compressed);

    // 2. Decompress into an allocated slice
    const decompressed = try lz4.decompress(allocator, compressed);
    defer allocator.free(decompressed);

    std.debug.assert(std.mem.eql(u8, payload, decompressed));
}
```

---

## Zero-Allocation Caller Buffers

For hot paths, embedded environments, or kernel/game loops where heap allocation is undesirable, use caller-provided destination buffers:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const input = "Zero allocation compression is simple and safe in Zig.";

    // Calculate maximum compressed bounds or use fixed stack buffer
    var comp_buffer: [512]u8 = undefined;
    var decomp_buffer: [512]u8 = undefined;

    // Compress directly into buffer
    const comp_bytes = try lz4.compressInto(input, &comp_buffer);

    // Decompress directly from buffer
    const decomp_bytes = try lz4.decompressInto(comp_buffer[0..comp_bytes], &decomp_buffer);

    std.debug.assert(std.mem.eql(u8, input, decomp_buffer[0..decomp_bytes]));
}
```

---

## Reusable Contexts

If your application compresses or decompresses thousands of messages in a loop, avoid repeatedly allocating internal structures. Use `lz4.Compressor` and `lz4.Decompressor`:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn processBatches(allocator: std.mem.Allocator, messages: [][]const u8) !void {
    var compressor = lz4.Compressor.init(allocator, .{
        .level = 1,
        .contentChecksum = true,
    });
    defer compressor.deinit();

    for (messages) |msg| {
        const frame = try compressor.compress(msg);
        defer allocator.free(frame);

        // Process compressed frame...
    }
}
```

---

## Next Steps

- Check the [Installation Guide](./installation) for build system setup.
- Read [Compression](./compression) to learn about acceleration levels and High-Compression (HC).
- Explore [Streaming](./streaming) for large files and socket streams.
