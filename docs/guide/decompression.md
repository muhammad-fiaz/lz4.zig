---
title: Decompression Guide
description: Decompressing frames, raw blocks, partial payloads, and enforcing security limits with lz4.zig.
---

# Decompression Guide

`lz4.zig` provides safe, high-speed decompression with automatic format detection, checksum validation, and protection against malicious inputs.

## Automatic Format Detection

The high-level `lz4.decompress` and `lz4.decompressWithOptions` functions automatically inspect the input header:
- If the first 4 bytes match `0x184D2204` (`FRAME_MAGIC`), the input is decoded as an **LZ4 Frame**.
- Otherwise, the input is decoded as a **Raw LZ4 Block**.

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Decompress any valid LZ4 data (frame or raw block)
    const decompressed = try lz4.decompress(allocator, compressed_data);
    defer allocator.free(decompressed);

    std.debug.print("Decompressed size: {d} bytes\n", .{decompressed.len});
}
```

---

## Decompression Security & Resource Limits

Untrusted data from the internet or unauthenticated users can present a "decompression bomb" attack (a tiny payload expanding into gigabytes of memory).

To guard against memory exhaustion, specify `maxOutputSize`:

```zig
const opts: lz4.DecompressionOptions = .{
    .maxOutputSize = 10 * 1024 * 1024, // Enforce a 10 MiB limit
    .verifyChecksums = true,
};

const safe_decompressed = try lz4.decompressWithOptions(allocator, untrusted_data, opts);
defer allocator.free(safe_decompressed);
```

If the uncompressed content exceeds `maxOutputSize`, decompression safely terminates with `error.OutputTooLarge` without overflowing memory.

---

## Zero-Allocation Caller Buffer

To decompress into a pre-allocated slice without any heap allocation:

```zig
var out_buf: [4096]u8 = undefined;

const decoded_len = try lz4.decompressInto(compressed_slice, &out_buf);
const result = out_buf[0..decoded_len];
```

---

## Partial Decompression

If you only need the first $N$ bytes of a compressed block (such as an index header or metadata record), use `decompressBlockPartial`:

```zig
var prefix_buf: [128]u8 = undefined;

// Decodes only up to prefix_buf.len bytes from the raw block
const bytes_read = try lz4.decompressBlockPartial(raw_block, &prefix_buf, prefix_buf.len);
const header = prefix_buf[0..bytes_read];
```

This avoids decompressing the remaining megabytes of the block, reducing latency and CPU usage.

---

## Error Handling

All decoders in `lz4.zig` strictly validate bounds and return structured errors from the canonical error set:

```zig
const data = lz4.decompress(allocator, untrusted_slice) catch |err| switch (err) {
    error.MalformedInput => {
        std.debug.print("Invalid or corrupt LZ4 sequence\n", .{});
        return;
    },
    error.BadChecksum => {
        std.debug.print("Data checksum mismatch detected!\n", .{});
        return;
    },
    error.OutputTooLarge => {
        std.debug.print("Decompressed size exceeded max safety limits\n", .{});
        return;
    },
    error.OutOfMemory => return err,
    else => return err,
};
defer allocator.free(data);
```
