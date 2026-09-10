---
title: Dictionary Compression Example
description: Compressing and decompressing small structured records using pre-shared dictionaries in lz4.zig.
---

# Dictionary Compression Example

Small records (such as HTTP request/response headers, JSON logs, or time-series metrics) contain fewer than 500 bytes. Standard compression cannot achieve high ratios because recurring patterns cannot be referenced until they appear twice within the same record.

Pre-shared dictionaries solve this problem by providing common domain headers and structures beforehand.

## Overview

- **Functions**: [`lz4.compressUsingDict`](/api/#raw-block-low-level-functions) & [`lz4.decompressBlockWithDict`](/api/#raw-block-low-level-functions)
- **Ratio Gain**: Achieves **60-80% smaller** sizes on small payloads compared to non-dictionary compression
- **Context API**: Also supported via `compressor.attachDictionary(dict)` and `decompressor.attachDictionary(dict)`

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const dict =
        \\HTTP/1.1 200 OK
        \\Content-Type: application/json
        \\Server: ZigLZ4
    ;

    // Attach dictionary to reusable compressor and decompressor
    var compressor = lz4.Compressor.init(allocator, .{ .level = 9 });
    defer compressor.deinit();
    compressor.attachDictionary(dict);

    var decompressor = lz4.Decompressor.init(allocator, .{});
    defer decompressor.deinit();
    decompressor.attachDictionary(dict);

    const message =
        \\HTTP/1.1 200 OK
        \\Content-Type: application/json
        \\Server: ZigLZ4
        \\
        \\{"status":"ok","code":200}
    ;

    // 1. Compress with dictionary
    var comp_buf: [256]u8 = undefined;
    const comp_len = try lz4.compressUsingDict(message, &comp_buf, dict, .{ .level = 9 });
    std.debug.print("Original message: {d} bytes\n", .{message.len});
    std.debug.print("Dictionary compressed: {d} bytes\n", .{comp_len});

    // 2. Decompress with dictionary
    var restored: [256]u8 = undefined;
    const decomp_len = try lz4.decompressBlockWithDict(comp_buf[0..comp_len], &restored, dict);

    std.debug.print("Restored message: '{s}' ({d} bytes)\n", .{
        restored[0..decomp_len],
        decomp_len,
    });
}
```

---

## Step-by-Step Breakdown

1. **Pre-Shared Dictionary**: The dictionary string contains standard HTTP 200 headers commonly present across responses.
2. **`lz4.compressUsingDict`**: The encoder matches the entire first 3 lines of the message against the dictionary, replacing them with a single small token and offset reference. The output shrinks from 89 bytes down to just 34 bytes (a 62% reduction!).
3. **`lz4.decompressBlockWithDict`**: Resolves negative match offsets against the provided dictionary slice, reconstructing the original message byte-for-byte.

---

## Running via Build System

```bash
zig build run-dictionary_compression
```

### Expected Output

```console
Original message: 89 bytes
Dictionary compressed: 34 bytes
Restored message: 'HTTP/1.1 200 OK
Content-Type: application/json
Server: ZigLZ4

{"status":"ok","code":200}' (89 bytes)
```
