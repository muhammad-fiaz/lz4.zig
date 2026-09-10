---
title: Examples Overview
description: Gallery of runnable examples demonstrating the lz4.zig API in native Zig 0.17.0.
---

# Examples Overview

The `examples/` directory contains complete, standalone example programs demonstrating real-world patterns with `lz4.zig`.

Each example can be executed directly using the Zig build system:

```bash
# Run a specific example
zig build run-compress_file
zig build run-streaming_compression
zig build run-reusable_context
zig build run-dictionary_compression
zig build run-error_handling
zig build run-format_introspection
zig build run-bit_level
zig build run-io_pipeline

# Run all registered examples sequentially
zig build run-all-examples
```

---

## Example Directory

| Example | Command | Description |
| :--- | :--- | :--- |
| [Basic Compression](./basic_compression) | `zig build run-alloc_operations` | One-shot frame compression and decompression with allocator. |
| [Caller Buffers](./caller_buffer) | `zig build run-caller_buffer` | Zero-allocation compression & decompression into pre-allocated memory. |
| [Compression Levels](./compression_levels) | `zig build run-compression_levels` | Benchmarking Fast acceleration against High-Compression (HC levels 2..12). |
| [File Compression](./file_compression) | `zig build run-compress_file` | Compressing and decompressing disk files into `.lz4` format. |
| [Streaming Compression](./streaming_compression) | `zig build run-streaming_compression` | Stateful chunked compression with `StreamingCompressor`. |
| [Streaming Decompression](./streaming_decompression) | `zig build run-streaming_decompression` | Stateful chunked pull decompression with `StreamingDecompressor`. |
| [Reusable Context](./reusable_context) | `zig build run-reusable_context` | Amortizing allocation costs across thousands of operations with `reset()`. |
| [Dictionary Compression](./dictionary_compression) | `zig build run-dictionary_compression` | Compressing small, repetitive JSON and metrics payloads using pre-shared dictionaries. |
| [Error Handling](./error_handling) | `zig build run-error_handling` | Robust handling of corrupted frames, invalid tokens, and checksum errors. |
| [Format Introspection](./format_introspection) | `zig build run-format_introspection` | Inspecting frame headers, magic numbers, block size descriptors, and skippable frames. |
| [Bit-Level & Token Encoding](./bit_level) | `zig build run-bit_level` | Understanding LZ4 token structure, byte-level packing, and variable-length integer extensions. |
| [I/O Pipeline](./io_pipeline) | `zig build run-io_pipeline` | Integrating with Zig 0.17 `std.Io.Reader` and `std.Io.Writer`. |
