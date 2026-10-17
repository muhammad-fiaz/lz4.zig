---
title: Caller Buffer Example
description: Zero-allocation frame and raw block compression and decompression using pre-allocated stack buffers.
keywords: caller buffer example, zero allocation compression zig, compressInto, decompressInto, stack buffers
---

# Caller Buffer Example

In latency-critical applications such as game loops, high-frequency network systems, or embedded microcontrollers, heap allocations are prohibited. `lz4.zig` provides `compressInto` and `decompressInto` (for standard frames) as well as `compress` and `decompress` (for raw blocks) to perform operations completely within caller-provided memory.

## Overview

- **Functions**: [`lz4.compressInto`](/api/#top-level-one-shot-functions), [`lz4.decompressInto`](/api/#top-level-one-shot-functions), [`lz4.compress`](/api/#top-level-one-shot-functions), [`lz4.decompress`](/api/#top-level-one-shot-functions)
- **Allocations**: Exactly **0** heap allocations
- **Error Behavior**: Returns `error.DstCapacityTooSmall` if caller buffer is insufficient

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const data = "Fixed stack memory buffers eliminate heap allocations entirely!";

    var frame_storage: [256]u8 = undefined;
    var block_storage: [256]u8 = undefined;
    var restored_storage: [256]u8 = undefined;

    // 1. Zero-allocation frame compression & decompression
    const frame_len = try lz4.compressInto(data, &frame_storage);
    const frame_restored_len = try lz4.decompressInto(frame_storage[0..frame_len], &restored_storage);

    std.debug.print("Zero-allocation frame roundtrip succeeded: '{s}' ({d} bytes)\n", .{
        restored_storage[0..frame_restored_len],
        frame_restored_len,
    });

    // 2. Zero-allocation raw block compression & decompression
    const block_len = try lz4.compress(data, &block_storage);
    const block_restored_len = try lz4.decompress(block_storage[0..block_len], &restored_storage);

    std.debug.print("Zero-allocation block roundtrip succeeded: '{s}' ({d} bytes)\n", .{
        restored_storage[0..block_restored_len],
        block_restored_len,
    });
}
```

---

## Step-by-Step Explanation

1. **Pre-allocated Memory**: Fixed byte arrays placed directly on the stack or static storage eliminate heap allocators.
2. **`lz4.compressInto(src, dst)`**: Compresses `src` into a standard, self-contained LZ4 frame directly into `dst`.
3. **`lz4.decompressInto(src, dst)`**: Decodes an LZ4 frame directly into `dst` without any dynamic allocation.
4. **`lz4.compress(src, dst)` & `lz4.decompress(src, dst)`**: Direct raw block operations for lightweight pipelines where frame headers are omitted.

---

## Running the Example

```bash
zig build run-caller_buffer
```

### Expected Output

```console
Zero-allocation frame roundtrip succeeded: 'Fixed stack memory buffers eliminate heap allocations entirely!' (63 bytes)
Zero-allocation block roundtrip succeeded: 'Fixed stack memory buffers eliminate heap allocations entirely!' (63 bytes)
```

