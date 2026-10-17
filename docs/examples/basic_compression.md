---
title: Basic Compression Example
description: Walkthrough of one-shot frame compression, raw block allocation, and decompression with dynamic memory allocation.
keywords: basic compression example, compressAlloc, decompressAlloc, one-shot frame zig, dynamic memory allocation
---

# Basic Compression Example

This example demonstrates the standard way to compress data into an LZ4 frame or raw block and decompress it back using an allocator.

## Overview

- **Functions**: [`lz4.compress`](/api/#top-level-one-shot-functions), [`lz4.decompress`](/api/#top-level-one-shot-functions), [`lz4.compressAlloc`](/api/#raw-block-apis), [`lz4.decompressAlloc`](/api/#raw-block-apis)
- **Format**: Standard LZ4 Frame Format (v1.6.4) and Raw LZ4 Block Format
- **Memory**: Dynamically allocated output slices owned by the caller

The one-shot frame API automatically calculates the worst-case compressed frame bound, encodes the frame magic number (`0x184D2204`), emits frame descriptors, compresses the data block, and calculates the xxHash-32 content checksum.

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const input = "Dynamically allocated slices returned directly from compress / decompress.";

    // 1. One-shot frame compression into allocated buffer
    const frame_slice = try lz4.compress(allocator, input);
    defer allocator.free(frame_slice);
    std.debug.print("Allocated compressed frame size: {d} bytes\n", .{frame_slice.len});

    // 2. One-shot frame decompression into allocated buffer
    const restored_frame = try lz4.decompress(allocator, frame_slice);
    defer allocator.free(restored_frame);
    std.debug.print("Allocated restored frame: '{s}'\n", .{restored_frame});

    // 3. Raw block allocation APIs
    const raw_block = try lz4.compressAlloc(allocator, input);
    defer allocator.free(raw_block);
    const restored_block = try lz4.decompressAlloc(allocator, raw_block, input.len + 16);
    defer allocator.free(restored_block);
    std.debug.print("Allocated raw block restored: '{s}'\n", .{restored_block});
}
```

---

## How It Works

1. **`lz4.compress(allocator, input)`**:
   - Computes the upper bound using `lz4.compressFrameBound`.
   - Allocates the destination frame buffer.
   - Writes the standard 4-byte frame magic `0x184D2204`.
   - Writes descriptor bytes, block data, and content checksum.
2. **`lz4.decompress(allocator, frame_slice)`**:
   - Validates frame header and checksums.
   - Allocates and returns the decompressed payload slice.
3. **`lz4.compressAlloc` / `lz4.decompressAlloc`**:
   - Low-level raw block APIs for applications managing custom framing.

---

## Running the Example

```bash
zig build run-alloc_operations
```

### Expected Output

```console
Allocated compressed frame size: 101 bytes
Allocated restored frame: 'Dynamically allocated slices returned directly from compress / decompress.'
Allocated raw block restored: 'Dynamically allocated slices returned directly from compress / decompress.'
```

