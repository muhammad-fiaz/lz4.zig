---
title: Error Handling Example
description: Safe, robust error handling on corrupted, truncated, and invalid LZ4 inputs.
keywords: error handling example, SourceBufferExhausted, InvalidMagic, DstCapacityTooSmall, corrupt frame, robust zig
---

# Error Handling Example

LZ4 decoders frequently parse untrusted input from network sockets, public endpoints, and untrusted files. `lz4.zig` ensures complete memory safety: no panics, no unhandled buffer overflows, and coherent typed error returns.

## Overview

- **Error Set**: [`lz4.Error`](/api/errors) (`CompressionError || DecompressionError || FrameError`)
- **Safety Guarantees**: Bounds-checked loops, zero unhandled undefined behavior, verified with continuous fuzzing

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var out_buf: [256]u8 = undefined;

    // 1. Handling truncated block input
    const truncated_block = [_]u8{ 0x30, 'X' }; // claims 3 literals, only 1 provided
    if (lz4.decompress(&truncated_block, &out_buf)) |_| {
        std.debug.print("Unexpected success on truncated input!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on truncated block: {s}\n", .{@errorName(err)});
    }

    // 2. Handling invalid magic number on frame decompression
    const bad_magic_frame = [_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66 };
    if (lz4.decompressFrame(&bad_magic_frame, &out_buf)) |_| {
        std.debug.print("Unexpected success on bad magic!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on invalid frame magic: {s}\n", .{@errorName(err)});
    }

    // 3. Handling destination buffer exhaustion
    var tiny_buf: [4]u8 = undefined;
    const large_text = "This uncompressed text exceeds 4 bytes capacity!";
    var valid_comp: [128]u8 = undefined;
    const comp_len = try lz4.compress(large_text, &valid_comp);

    if (lz4.decompress(valid_comp[0..comp_len], &tiny_buf)) |_| {
        std.debug.print("Unexpected success on small buffer!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on small buffer: {s}\n", .{@errorName(err)});
    }
}
```

---

## Step-by-Step Breakdown

1. **Truncated Block (`error.SourceBufferExhausted`)**:
   - The token byte `0x30` indicates a literal length of 3 bytes.
   - However, the slice only provides 1 byte (`'X'`).
   - The safe decoder identifies that `ip + lit_len > src.len` and safely exits with `SourceBufferExhausted` rather than reading past the slice boundary.
2. **Invalid Magic (`error.InvalidMagic`)**:
   - `decompressFrame` verifies the first 4 bytes against `0x184D2204`.
   - The provided slice contains `0x00 0x11 0x22 0x33`, immediately failing validation.
3. **Buffer Exhaustion (`error.DstCapacityTooSmall`)**:
   - The uncompressed payload exceeds the 4-byte destination capacity.
   - Rather than overflowing caller memory, the decoder checks bounds and aborts with `DstCapacityTooSmall`.

---

## Running via Build System

```bash
zig build run-error_handling
```

### Expected Output

```console
Expected error caught on truncated block: SourceBufferExhausted
Expected error caught on invalid frame magic: InvalidMagic
Expected error caught on small buffer: DstCapacityTooSmall
```
