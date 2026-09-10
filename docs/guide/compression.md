---
title: Compression Guide
description: In-depth guide to compression modes, levels, options, and buffer strategies in lz4.zig.
---

# Compression Guide

`lz4.zig` provides flexible compression mechanisms tailored for both maximum throughput and high compression ratios.

## Compression Strategies & Levels

LZ4 supports two primary compression engines:

1. **Fast LZ4 (Default)**:
   - Uses an accelerated hash table (`FastTable`) to detect repetitive sequences at byte-level speed.
   - Controlled via the `acceleration` parameter (default `1`). Higher acceleration values (e.g., `2`, `4`, `8`) skip search steps to achieve throughput of multiple gigabytes per second on modern CPUs.
2. **High-Compression LZ4 (HC)**:
   - Uses optimal parsing and chain-based match finding (`HcTable`).
   - Enabled by setting `.level = 2` through `12` (default HC is `9`).
   - Produces significantly smaller compressed sizes while preserving standard LZ4 decompression speeds.

### Configuring Levels and Options

Use `lz4.compressWithOptions` to pass custom `CompressionOptions`:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const input = "Repeat pattern: abcdefghijklmnopqrstuvwxyz0123456789 -- " ** 100;

    // Fast mode with acceleration
    const fast_opts: lz4.CompressionOptions = .{
        .acceleration = 2,
        .contentChecksum = true,
    };
    const fast_frame = try lz4.compressWithOptions(allocator, input, fast_opts);
    defer allocator.free(fast_frame);

    // High-Compression (HC) mode
    const hc_opts: lz4.CompressionOptions = .{
        .level = 9, // Level 9 is standard HC
        .blockMaxSize = .max_64kb,
        .contentChecksum = true,
    };
    const hc_frame = try lz4.compressWithOptions(allocator, input, hc_opts);
    defer allocator.free(hc_frame);

    std.debug.print("Input: {d} bytes | Fast: {d} bytes | HC: {d} bytes\n", .{
        input.len,
        fast_frame.len,
        hc_frame.len,
    });
}
```

---

## Block Max Size & Memory Trade-offs

The LZ4 frame descriptor defines the maximum uncompressed size of each data block inside the frame:

| `BlockMaxSize` | Max Block Uncompressed Size | Typical Use Case |
| :--- | :--- | :--- |
| `.max_64kb` | 64 KiB | Small memory footprint, network packets |
| `.max_256kb` | 256 KiB | Balanced latency and ratio |
| `.max_1mb` | 1 MiB | Default standard for files and streams |
| `.max_4mb` | 4 MiB | Maximum compression ratio for large payloads |

```zig
const opts: lz4.CompressionOptions = .{
    .blockMaxSize = .max_4mb,
};
```

---

## Block Independence Mode

LZ4 frames support two block modes:
- **`BlockMode.independent` (Default)**: Each block can be decompressed independently without reference to previous blocks. Essential for parallel decompression and streaming recovery.
- **`BlockMode.linked`**: Blocks reference the sliding 64 KiB window of the preceding block, improving compression ratios for repetitive structured streams.

```zig
const opts: lz4.CompressionOptions = .{
    .blockMode = .linked,
};
```

---

## Raw Block Compression

When framing overhead is unwanted (e.g. key-value storage engines like RocksDB or Redis), compress raw blocks:

```zig
var dst_buf: [1024]u8 = undefined;

// Raw block compression
const block_size = try lz4.compressBlock(input_data, &dst_buf);

// Or with explicit acceleration
const fast_size = try lz4.compressFast(input_data, &dst_buf, 2);

// Or with High-Compression
const hc_size = try lz4.compressHC(input_data, &dst_buf, 9);
```

---

## Calculating Upper Bounds

Before allocating memory for compressed data, compute the guaranteed worst-case output capacity:

```zig
const max_frame_size = lz4.compressFrameBound(input.len, .{});
const max_block_size = lz4.compressBlockBound(input.len);
```
