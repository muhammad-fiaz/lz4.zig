---
title: Dictionaries Guide
description: Using pre-shared and prefix dictionaries in lz4.zig to achieve high compression on small repetitive payloads.
---

# Dictionaries Guide

Standard compression algorithms often struggle on small payloads (e.g. JSON log records, HTTP headers, or network packets smaller than 1 KiB) because there is insufficient repetitive history within a single message to build LZ4 match offsets.

Pre-shared dictionaries solve this problem by priming the match history with domain-specific patterns known to both the sender and receiver.

---

## How LZ4 Dictionaries Work

In LZ4:
1. The dictionary data is loaded into memory as a reference window (up to 64 KiB is used as active history).
2. During compression, match searches can look backward into the dictionary slice.
3. During decompression, match offsets pointing into negative positions are resolved against the pre-shared dictionary buffer.

---

## Using Dictionaries with `Compressor` & `Decompressor`

The cleanest way to use dictionaries is through the reusable context structs:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Shared schema / training data
    const dict = "{\"timestamp\":0,\"user_id\":1000,\"event_type\":\"CLICK\",\"session_token\":\"AUTH_";

    // Setup Compressor with dictionary
    var compressor = lz4.Compressor.init(allocator, .{});
    defer compressor.deinit();
    compressor.attachDictionary(dict);

    // Setup Decompressor with dictionary
    var decompressor = lz4.Decompressor.init(allocator, .{});
    defer decompressor.deinit();
    decompressor.attachDictionary(dict);

    // Small repetitive payload
    const record = "{\"timestamp\":1712345,\"user_id\":1000,\"event_type\":\"CLICK\",\"session_token\":\"AUTH_98765\"}";

    // Compress using dictionary
    const compressed = try compressor.compress(record);
    defer allocator.free(compressed);

    // Decompress using dictionary
    const restored = try decompressor.decompress(compressed);
    defer allocator.free(restored);

    std.debug.assert(std.mem.eql(u8, record, restored));
}
```

---

## Low-Level Raw Block Dictionary APIs

For database engines or protocols that store raw blocks without frame headers:

```zig
const dict = "PRE-SHARED-DICTIONARY-TEMPLATE-FOR-METRICS";
const payload = "PRE-SHARED-DICTIONARY-TEMPLATE-FOR-METRICS:cpu=95.4,mem=42.1";

var comp_buf: [256]u8 = undefined;
var decomp_buf: [256]u8 = undefined;

// Compress block with reference dictionary
const comp_len = try lz4.compressUsingDict(payload, &comp_buf, dict);

// Decompress block with reference dictionary
const decomp_len = try lz4.decompressBlockWithDict(comp_buf[0..comp_len], &decomp_buf, dict);

std.debug.assert(std.mem.eql(u8, payload, decomp_buf[0..decomp_len]));
```

---

## Dictionary Identifier (`dictId`)

When using LZ4 Frames, the frame descriptor can optionally include a 4-byte `dictId`. This allows the receiver to verify that it holds the correct dictionary version before attempting decompression:

```zig
const opts: lz4.CompressionOptions = .{
    .dictId = 0xCAFEBABE,
    .customDictionary = dict,
};
```
