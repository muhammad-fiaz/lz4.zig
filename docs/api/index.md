---
title: API Reference Overview
description: Overview of the public API symbols and functions exposed by lz4.zig.
---

# API Reference Overview

The `lz4.zig` public interface provides both top-level one-shot functions and specialized struct types for fine-grained control.

## Top-Level One-Shot Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `lz4.compress` | `(arg1, arg2) !Output` | Polymorphic one-shot compression: allocates `[]u8` if `arg1` is `Allocator`, or writes into caller slice `arg2`. |
| `lz4.compressWithOptions` | `(allocator, src, opts) ![]u8` | Compresses `src` with custom `CompressionOptions`, allocating a new slice for the frame. |
| `lz4.compressInto` | `(src, dst) !usize` | Compresses `src` into caller-allocated `dst` slice (standard frame format). |
| `lz4.decompress` | `(arg1, arg2) !Output` | Polymorphic one-shot decompression: auto-detects frame or block format. |
| `lz4.decompressWithOptions` | `(allocator, src, opts) ![]u8` | Decompresses `src` with custom `DecompressionOptions` (e.g. `maxOutputSize`). |
| `lz4.decompressInto` | `(src, dst) !usize` | Decompresses `src` directly into caller-allocated `dst` slice. |

---

## Streaming & I/O Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `lz4.compressStream` | `(allocator, reader, writer, opts) !usize` | Compresses stream from `std.Io.Reader` to `std.Io.Writer`. |
| `lz4.decompressStream` | `(allocator, reader, writer, opts) !usize` | Decompresses stream from `std.Io.Reader` to `std.Io.Writer`. |
| `lz4.compressFile` | `(allocator, in_path, out_path, opts) !void` | Compresses a file on disk into an LZ4 frame file. |
| `lz4.decompressFile` | `(allocator, in_path, out_path) !void` | Decompresses an on-disk LZ4 file back to its original format. |

---

## Raw Block Low-Level Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `lz4.compressBlock` | `(src, dst) !usize` | Compresses a raw block into `dst`. |
| `lz4.compressFast` | `(src, dst, acceleration) !usize` | Fast block compression with explicit acceleration factor. |
| `lz4.compressHC` | `(src, dst, level) !usize` | High-Compression block compression (level 2..12). |
| `lz4.compressUsingDict` | `(src, dst, dict) !usize` | Compresses a block using a prefix/external dictionary. |
| `lz4.decompressBlock` | `(src, dst) !usize` | Decompresses a raw LZ4 block into caller-allocated `dst`. |
| `lz4.decompressBlockPartial` | `(src, dst, target_size) !usize` | Decompresses up to `target_size` uncompressed bytes. |
| `lz4.decompressBlockWithDict`| `(src, dst, dict) !usize` | Decompresses a raw block using a reference dictionary. |

---

## Bounds & Metadata Functions

| Function | Description |
| :--- | :--- |
| `lz4.compressBound(size)` | Calculates worst-case compressed buffer capacity. |
| `lz4.compressFrameBound(size, opts)` | Calculates worst-case LZ4 frame size including headers and checksums. |
| `lz4.compressBlockBound(size)` | Calculates worst-case raw block size. |
| `lz4.getFrameInfo(src)` | Inspects and parses `FrameHeader` from a compressed slice. |
| `lz4.xxHash32(data, seed)` | Computes pure Zig xxHash-32 checksum with seed. |
| `lz4.versionString()` | Returns library version string (`0.0.1`). |
