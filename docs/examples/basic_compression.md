---
title: Basic Compression Example
description: Complete walkthrough of one-shot frame compression and decompression with dynamic memory allocation.
---

# Basic Compression Example

This example demonstrates the simplest and most common way to compress data into a standard LZ4 frame and decompress it back using an allocator.

## Overview

- **Function**: [`lz4.compress`](/api/#top-level-one-shot-functions) & [`lz4.decompress`](/api/#top-level-one-shot-functions)
- **Format**: Standard LZ4 Frame Format (v1.6.4)
- **Memory**: Dynamically allocated output slices owned by the caller

The one-shot API automatically calculates the worst-case compressed frame bound, encodes the frame magic number (`0x184D2204`), emits frame descriptors, compresses the data block, and calculates the xxHash-32 content checksum.

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const original_text =
        "LZ4 is a lossless compression algorithm, providing compression speed > 500 MB/s per core, " ++
        "scalable with multi-cores CPU. It features an extremely fast decoder, with speed in multiple " ++
        "GB/s per core, typically reaching RAM speed limits on multi-core systems.";

    std.debug.print("Original size:   {d} bytes\n", .{original_text.len});

    // 1. Compress into an allocated LZ4 Frame
    const compressed = try lz4.compress(allocator, original_text);
    defer allocator.free(compressed);

    std.debug.print("Compressed size: {d} bytes\n", .{compressed.len});
    const ratio = @as(f64, @floatFromInt(original_text.len)) / @as(f64, @floatFromInt(compressed.len));
    std.debug.print("Ratio:           {d:.2}x\n", .{ratio});

    // 2. Decompress back into an allocated slice
    const decompressed = try lz4.decompress(allocator, compressed);
    defer allocator.free(decompressed);

    std.debug.assert(std.mem.eql(u8, original_text, decompressed));
    std.debug.print("Decompression succeeded and verified!\n", .{});
}
```

---

## How It Works

1. **Allocator Setup**: A standard `GeneralPurposeAllocator` is initialized to manage heap allocations safely with leak detection.
2. **`lz4.compress(allocator, original_text)`**:
   - Computes the upper bound using `lz4.compressFrameBound`.
   - Allocates the destination frame buffer.
   - Writes the standard 4-byte frame magic `0x184D2204`.
   - Writes the FLG and BD descriptor bytes, enabling content checksum.
   - Encodes data blocks and appends the 4-byte `END_MARK` (`0x00000000`).
   - Appends the 4-byte xxHash-32 content checksum.
3. **`lz4.decompress(allocator, compressed)`**:
   - Inspects the first 4 bytes to detect the frame magic.
   - Verifies the frame descriptor checksum.
   - Decodes each data block.
   - Validates the xxHash-32 content checksum against the decoded data.
   - Returns the exact uncompressed byte slice.

---

## Running the Example

```bash
zig run src/main.zig
```

### Expected Output

```console
Original size:   251 bytes
Compressed size: 211 bytes
Ratio:           1.19x
Decompression succeeded and verified!
```
