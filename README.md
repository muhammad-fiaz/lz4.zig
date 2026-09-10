<div align="center">

# lz4.zig

<a href="https://muhammad-fiaz.github.io/lz4.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.17.0-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/lz4.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/lz4.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/lz4.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/lz4.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/lz4.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/lz4.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/lz4.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/lz4.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/lz4.zig/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/lz4.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/lz4.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-GitHub-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/muhammad-fiaz/lz4.zig/"><img src="https://hits.sh/muhammad-fiaz/lz4.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>Fast, native LZ4 compression for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/lz4.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/lz4.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/lz4.zig/guide/getting-started">Quick Start</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

`lz4.zig` is a complete, production-ready, native Zig implementation of the LZ4 compression ecosystem targeting **Zig 0.17.0**, built entirely from scratch in pure Zig. No C bindings, no `@cImport`, and no external runtime dependencies.

> [!TIP]
> If you build with lz4.zig, make sure to give it a star!

> [!NOTE]
> `lz4.zig` implements the LZ4 Block format (v1.5.1) and Frame format (v1.6.4). The standard upstream [LZ4 repository](https://github.com/lz4/lz4/tree/48bfbfe351c5d6ea87d4af5557705e87755844e0) (commit `48bfbfe351c5d6ea87d4af5557705e87755844e0`) is used as a reference standard for format behavior, compatibility requirements, and interoperability testing.
>
> - **Fast & High-Compression encoders**: Configurable acceleration levels (1..65535) and HC levels (2..12).
> - **LZ4 Frame streaming**: Magic numbers (`0x184D2204`), FLG/BD descriptors, block checksums, content checksums, and skippable frames (`0x184D2A50`..`0x184D2A5F`).
> - **Native xxHash-32**: Pure Zig implementation for block and content validation.
> - **Reusable contexts**: Initialize once, compress/decompress multiple streams via `reset()`, eliminating allocation churn.
> - **Chunked streaming**: Process arbitrarily split network streams without buffering the full input in memory.

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description |
|---|---|
| **One-shot Compression** | `lz4.compress(allocator, data)` for single-call standard frame compression |
| **One-shot Decompression** | `lz4.decompress(allocator, data)` for single-call frame or block decompression |
| **Caller-Buffer Operations** | `lz4.compressInto(src, dst)` and `lz4.decompressInto(src, dst)` for zero-allocation efficiency |
| **Compression Levels** | Level 1 (Fast) and Levels 2..12 (HC) via `lz4.compressWithOptions(allocator, data, .{ .level = ... })` |
| **Reusable Compressor** | `lz4.Compressor` (`init`, `compress`, `compressInto`, `reset`, `attachDictionary`, `deinit`) |
| **Reusable Decompressor** | `lz4.Decompressor` (`init`, `decompress`, `decompressInto`, `reset`, `attachDictionary`, `deinit`) |
| **I/O Streaming** | `compressStream` and `decompressStream` with Zig 0.17 `std.Io.Reader` & `std.Io.Writer` |
| **Streaming Compressor** | `StreamingCompressor` with `write(chunk, writer)` and `finish(writer)` |
| **Streaming Decompressor** | `StreamingDecompressor` with `feed(chunk)` and `take(out)` |
| **Dictionary Compression** | `attachDictionary()` on contexts or `compressUsingDict()` / `decompressBlockWithDict()` |
| **Partial Decompression** | Extract a prefix safely from a compressed block without decoding the full buffer |
| **Native xxHash-32** | Pure Zig checksum implementation with one-shot and streaming state |
| **Resource Limits** | `maxOutputSize` on `DecompressionOptions` to guard against decompression bombs |
| **Canonical Error Set** | Coherent `lz4.Error` error set mapped from internal codes |
| **Zero Dependencies** | Pure Zig implementation targeting Zig 0.17.0 |

</details>

---

<details>
<summary><strong>Prerequisites and Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| **Zig** | **0.17.0** (required) | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Cross-platform support |

---

## Supported Platforms

`lz4.zig` targets these architectures:

| Platform | x86_64 (64-bit) | aarch64 (ARM64) | x86 (32-bit) | arm (32-bit) | riscv64 |
|---|---|---|---|---|---|
| **Linux** | Yes | Yes | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes | - | - |
| **macOS** | Yes | Yes (Apple Silicon) | - | - | - |

### Cross-Compilation

Zig makes cross-compilation easy:

```bash
# Build for Linux ARM64
zig build -Dtarget=aarch64-linux

# Build for Windows x86_64
zig build -Dtarget=x86_64-windows

# Build for macOS Apple Silicon
zig build -Dtarget=aarch64-macos

# Build for 32-bit Windows
zig build -Dtarget=x86-windows

# Build for 32-bit ARM Linux
zig build -Dtarget=arm-linux-gnueabihf
```

</details>

---

## Installation

### Stable Release

```bash
zig fetch --save https://github.com/muhammad-fiaz/lz4.zig/archive/refs/tags/0.0.1.tar.gz
```

### Latest / Dev / Nightly

For development builds, nightly updates, or the latest unreleased changes:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/lz4.zig.git
```

### Wire into `build.zig`

```zig
const target = b.standardTargetOptions(.{});
const optimize = b.standardOptimizeOption(.{});

const lz4_dep = b.dependency("lz4", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("lz4", lz4_dep.module("lz4"));
```

---

## Quick Start

### One-Shot Compression & Decompression

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const data = "Native LZ4 compression in pure Zig 0.17.0!";

    // Compress (standard LZ4 frame)
    const compressed = try lz4.compress(allocator, data);
    defer allocator.free(compressed);

    // Decompress
    const decompressed = try lz4.decompress(allocator, compressed);
    defer allocator.free(decompressed);

    std.debug.print("Restored: {s}\n", .{decompressed});
}
```

### Zero-Allocation Caller Buffer

```zig
var out_buf: [256]u8 = undefined;
const comp_len = try lz4.compressInto(data, &out_buf);

var restored_buf: [256]u8 = undefined;
const decomp_len = try lz4.decompressInto(out_buf[0..comp_len], &restored_buf);
```

### Advanced Options (camelCase)

```zig
const compressed = try lz4.compressWithOptions(allocator, data, .{
    .level = 9,                   // 1 = fast, 2..12 = High Compression (HC)
    .blockMaxSize = .max256KB,    // .max64KB, .max256KB, .max1MB, .max4MB
    .contentChecksum = true,      // append xxHash-32 content checksum
    .blockChecksum = false,       // per-block xxHash-32 checksum
});
defer allocator.free(compressed);

const decompressed = try lz4.decompressWithOptions(allocator, compressed, .{
    .maxOutputSize = 10 * 1024 * 1024, // protect against decompression bombs
});
defer allocator.free(decompressed);
```

### Reusable Contexts (Zero Allocation Churn)

Initialize the context once with your allocator, reuse across multiple streams via `reset()`, and deinitialize when done:

```zig
var compressor = lz4.Compressor.init(allocator, .{ .level = 1 });
defer compressor.deinit();

var decompressor = lz4.Decompressor.init(allocator, .{});
defer decompressor.deinit();

// First stream
const comp1 = try compressor.compress(input1);
defer allocator.free(comp1);
const out1 = try decompressor.decompress(comp1);
defer allocator.free(out1);

// Reset state without reallocating buffers
compressor.reset(.{ .level = 9 });
decompressor.reset(.{});

// Second stream
const comp2 = try compressor.compress(input2);
defer allocator.free(comp2);
const out2 = try decompressor.decompress(comp2);
defer allocator.free(out2);
```

### Streaming I/O with `std.Io`

Stream directly between `std.Io.Reader` and `std.Io.Writer`:

```zig
// Stream compression
var reader = std.Io.Reader.fixed(input_bytes);
var writer = std.Io.Writer.fixed(&out_buffer);

try lz4.compressStream(allocator, &reader, &writer, .{ .contentChecksum = true });

// Stream decompression
var comp_reader = std.Io.Reader.fixed(writer.buffered());
var decomp_writer = std.Io.Writer.fixed(&decomp_buffer);

try lz4.decompressStream(allocator, &comp_reader, &decomp_writer, .{});
```

### Chunked Streaming Compressor & Decompressor

```zig
// Incremental compression
var sc = try lz4.StreamingCompressor.init(allocator, .{ .level = 1 });
defer sc.deinit();

try sc.write(chunk1, &writer);
try sc.write(chunk2, &writer);
try sc.finish(&writer);

// Incremental decompression
var sd = lz4.StreamingDecompressor.init(allocator, .{});
defer sd.deinit();

try sd.feed(chunk);
var out_buf: [4096]u8 = undefined;
while (!sd.isFinished()) {
    const n = try sd.take(&out_buf);
    if (n == 0) break;
    // process out_buf[0..n]
}
```

### Custom Dictionary Compression

```zig
const dict = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nServer: ZigLZ4\r\n";

var compressor = lz4.Compressor.init(allocator, .{ .level = 9 });
defer compressor.deinit();
compressor.attachDictionary(dict);

var decompressor = lz4.Decompressor.init(allocator, .{});
defer decompressor.deinit();
decompressor.attachDictionary(dict);

const compressed = try compressor.compress(payload);
defer allocator.free(compressed);

const original = try decompressor.decompress(compressed);
defer allocator.free(original);
```

---

## API Reference

### Top-Level Functions

| Function | Description |
|---|---|
| `lz4.compress(alloc, src)` | One-shot frame compression |
| `lz4.decompress(alloc, src)` | One-shot frame or block decompression |
| `lz4.compressWithOptions(alloc, src, opts)` | Compression with `CompressionOptions` |
| `lz4.decompressWithOptions(alloc, src, opts)` | Decompression with `DecompressionOptions` |
| `lz4.compressInto(src, dst)` | Compress into caller-allocated buffer |
| `lz4.decompressInto(src, dst)` | Decompress into caller-allocated buffer |
| `lz4.compressStream(alloc, reader, writer, opts)` | Stream compression via `std.Io` |
| `lz4.decompressStream(alloc, reader, writer, opts)` | Stream decompression via `std.Io` |
| `lz4.compressFile(io, src, dst, opts, alloc)` | Compress file on disk to LZ4 frame file |
| `lz4.decompressFile(io, src, dst, alloc)` | Decompress LZ4 file on disk |
| `lz4.compressBound(src_size)` / `maxCompressedSize(src_size)` | Calculate upper bound on compressed size |
| `lz4.versionString()` / `versionNumber()` | Library version (`0.0.1` / `1`) |

### Types

| Type | Description |
|---|---|
| `lz4.Compressor` | Reusable compressor: `init`, `compress`, `compressInto`, `reset`, `attachDictionary`, `deinit` |
| `lz4.Decompressor` | Reusable decompressor: `init`, `decompress`, `decompressInto`, `reset`, `attachDictionary`, `deinit` |
| `lz4.StreamingCompressor` | Streaming compressor: `write(chunk, writer)`, `finish(writer)`, `deinit()` |
| `lz4.StreamingDecompressor` | Streaming decompressor: `feed(chunk)`, `take(out)`, `read(reader, writer)`, `reset()`, `deinit()` |
| `lz4.CompressionOptions` | `level`, `acceleration`, `blockMaxSize`, `blockMode`, `contentChecksum`, `blockChecksum`, `contentSize`, `customDictionary` |
| `lz4.DecompressionOptions` | `maxOutputSize`, `customDictionary` |
| `lz4.BlockMaxSize` | `.max64KB`, `.max256KB`, `.max1MB`, `.max4MB` |
| `lz4.Error` | Canonical public error set: `CorruptStream`, `TruncatedInput`, `ResourceLimitExceeded`, etc. |

---

## Examples

The `examples/` directory contains complete, runnable examples:

| Example | File | Description |
|---|---|---|
| `compress_file` | `examples/compress_file.zig` | File compression on disk using `std.Io` |
| `decompress_file` | `examples/decompress_file.zig` | File decompression from disk using `std.Io` |
| `streaming_compression` | `examples/streaming_compression.zig` | Chunked streaming compression using `StreamingCompressor` |
| `streaming_decompression` | `examples/streaming_decompression.zig` | Chunked streaming decompression using `StreamingDecompressor` |
| `dictionary_compression` | `examples/dictionary_compression.zig` | Custom shared-dictionary compression |
| `reusable_context` | `examples/reusable_context.zig` | Context reuse via `reset()` without reallocating buffers |
| `error_handling` | `examples/error_handling.zig` | Corrupted bitstream detection and error diagnostics |
| `format_introspection` | `examples/format_introspection.zig` | Library version, standard commit metadata, and format limits |
| `bit_level` | `examples/bit_level.zig` | Variable-length integer encoding and token layout |
| `io_pipeline` | `examples/io_pipeline.zig` | In-memory, reader/writer, and chunked I/O shapes |

Run any example:

```bash
zig build run-compress_file
zig build run-streaming_compression
zig build run-reusable_context
zig build run-all-examples   # Run all 10 examples
```

---

## Building & Testing

```bash
zig build                    # Build native LZ4 library
zig build test               # Run all unit and integration tests
zig build test --summary all # Detailed test execution summary
zig build run-all-examples   # Run all 10 example executables
zig build fuzz               # Run decoder robustness fuzzer
zig build docs               # Generate documentation in zig-out/docs/
```

---

## Contributing

Contributions are welcome! Please ensure all tests pass:

```bash
zig fmt src examples build.zig build.zig.zon
zig build test --summary all
zig build run-all-examples
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Security

For vulnerability reporting and security guarantees, please see [SECURITY.md](SECURITY.md).

## Acknowledgements

`lz4.zig` is a native Zig implementation of the LZ4 format and codec, built entirely from scratch in Zig.

The [LZ4 project](https://github.com/lz4/lz4/tree/48bfbfe351c5d6ea87d4af5557705e87755844e0) (commit `48bfbfe351c5d6ea87d4af5557705e87755844e0`) is used as a reference standard for the LZ4 format, codec behavior, compatibility, and interoperability verification.

This project does not depend on the upstream implementation.

## License

MIT License - see [LICENSE](LICENSE) for details.
