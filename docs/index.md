---
layout: home

hero:
  name: "lz4.zig"
  text: "Ultra-Fast Native LZ4 Compression for Zig"
  tagline: "Pure Zig implementation of the LZ4 ecosystem targeting Zig 0.17.0. Zero C dependencies, zero overhead, memory-safe."
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/
    - theme: alt
      text: Examples
      link: /examples/
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/lz4.zig

features:
  - icon: ⚡
    title: Pure Native Zig (0.17.0)
    details: Built entirely from scratch in native Zig without `@cImport`, C compiler requirements, or external runtime dependencies.
  - icon: 🚀
    title: Blazing Fast & High Compression
    details: Features both the standard Fast match-finder with configurable acceleration and the optimal High-Compression (HC) engine (levels 2..12).
  - icon: 📦
    title: Frame & Block Standard Formats
    details: Full interoperability with reference LZ4 tooling (v1.5.1 Block and v1.6.4 Frame specs), handling block headers, checksums, and skippable frames.
  - icon: 🛡️
    title: Memory-Safe & Bounded
    details: Robust error handling, protection against decompression bombs with `maxOutputSize`, and decoder robustness verified with continuous fuzzing.
  - icon: 🌊
    title: Streaming & I/O Pipelines
    details: First-class integration with Zig 0.17 `std.Io.Reader` and `std.Io.Writer` alongside push/pull stateful chunked streaming.
  - icon: 📚
    title: Dictionaries & Context Reuse
    details: Reusable `Compressor` and `Decompressor` instances eliminate allocation churn; attach pre-shared dictionaries for compressing small structured payloads.
---

## Quick Example

Compress and decompress data in just a few lines of idiomatic Zig:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const raw_data = "LZ4 is an extremely fast lossless compression algorithm!";

    // One-shot compression to a standard LZ4 frame
    const compressed = try lz4.compress(allocator, raw_data);
    defer allocator.free(compressed);

    // One-shot decompression (handles frames and blocks automatically)
    const restored = try lz4.decompress(allocator, compressed);
    defer allocator.free(restored);

    std.debug.print("Original size:   {d} bytes\n", .{raw_data.len});
    std.debug.print("Compressed size: {d} bytes\n", .{compressed.len});
    std.debug.print("Restored:        {s}\n", .{restored});
}
```

## Zero-Allocation Buffer Operations

For performance-critical code where allocations are prohibited, compress directly into pre-allocated memory:

```zig
var comp_buf: [1024]u8 = undefined;
var decomp_buf: [1024]u8 = undefined;

// Compress directly into caller buffer
const comp_size = try lz4.compressInto(raw_data, &comp_buf);

// Decompress directly from caller buffer
const decomp_size = try lz4.decompressInto(comp_buf[0..comp_size], &decomp_buf);
```

## Feature Matrix

| Feature | `lz4.zig` Support | Notes |
| :--- | :--- | :--- |
| **Language Target** | Zig 0.17.0 | Pure native Zig, no C toolchain required |
| **Block Format (v1.5.1)** | Full | Fast block encoder & safe bounded block decoder |
| **Frame Format (v1.6.4)** | Full | Magic `0x184D2204`, FLG, BD, block & content checksums |
| **High Compression (HC)** | Levels 2..12 | Optimal match parser for maximum compression ratio |
| **Fast Acceleration** | Levels 1..65535 | Step acceleration for real-time ingestion pipelines |
| **Streaming I/O** | `Reader` / `Writer` | Direct integration with standard Zig 0.17 I/O |
| **Chunked Streaming** | Push / Pull | `StreamingCompressor` and `StreamingDecompressor` |
| **Checksums** | xxHash-32 | Pure Zig xxHash-32 implementation included |
| **Dictionary Codec** | Supported | Prefix and external reference dictionaries |
| **Bomb Protection** | Supported | Explicit `maxOutputSize` bounds checking |

## Installation

Add `lz4.zig` to your `build.zig.zon`:

```bash
# Stable Release
zig fetch --save https://github.com/muhammad-fiaz/lz4.zig/archive/refs/tags/0.0.1.tar.gz

# Latest / Dev / Nightly
zig fetch --save git+https://github.com/muhammad-fiaz/lz4.zig.git
```

Then expose the module in your `build.zig`:

```zig
const lz4_dep = b.dependency("lz4", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("lz4", lz4_dep.module("lz4"));
```
