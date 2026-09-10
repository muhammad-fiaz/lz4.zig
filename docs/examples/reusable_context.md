---
title: Reusable Context Example
description: Reusing Compressor and Decompressor contexts across multiple streams to eliminate allocation overhead.
---

# Reusable Context Example

Repeatedly allocating and freeing compressor hash tables and internal stream buffers causes heap churn and GC-like latency spikes. In high-throughput systems, `lz4.Compressor` and `lz4.Decompressor` should be created once at startup and reused via `.reset()`.

## Overview

- **Structs**: [`lz4.Compressor`](/api/compressor) & [`lz4.Decompressor`](/api/decompressor)
- **Benefit**: Reuses internal memory buffers while allowing configuration changes (such as switching from Fast level 1 to HC level 9) between streams

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Initialize compressor and decompressor once
    var compressor = lz4.Compressor.init(allocator, .{ .level = 1 });
    defer compressor.deinit();

    var decompressor = lz4.Decompressor.init(allocator, .{});
    defer decompressor.deinit();

    // First round of data
    const input1 = "Stream 1: Telemetry packets flowing through reusable context.";
    const comp1 = try compressor.compress(input1);
    defer allocator.free(comp1);

    const out1 = try decompressor.decompress(comp1);
    defer allocator.free(out1);
    std.debug.print("Stream 1 restored ({d} bytes): '{s}'\n", .{ out1.len, out1 });

    // 2. Reset compressor state for High-Compression mode without reallocating
    compressor.reset(.{ .level = 9 });
    decompressor.reset(.{});

    // Second round of data
    const input2 = "Stream 2: High compression telemetry archive using reset state.";
    const comp2 = try compressor.compress(input2);
    defer allocator.free(comp2);

    const out2 = try decompressor.decompress(comp2);
    defer allocator.free(out2);
    std.debug.print("Stream 2 restored ({d} bytes): '{s}'\n", .{ out2.len, out2 });
}
```

---

## Step-by-Step Breakdown

1. **Initialization**: `Compressor.init` and `Decompressor.init` configure options and store references to the provided allocator.
2. **Stream 1**: First batch is processed with default Fast level 1.
3. **Resetting Context**: `compressor.reset(.{ .level = 9 })` dynamically adjusts the internal compression engine to High-Compression (HC Level 9) without allocating a new context.
4. **Stream 2**: Second batch is compressed with HC mode using the existing context.

---

## Running via Build System

```bash
zig build run-reusable_context
```

### Expected Output

```console
Stream 1 restored (61 bytes): 'Stream 1: Telemetry packets flowing through reusable context.'
Stream 2 restored (63 bytes): 'Stream 2: High compression telemetry archive using reset state.'
```
