---
title: DecompressionOptions
description: Configuration options for LZ4 decompression, resource constraints, and security limits.
---

# `lz4.DecompressionOptions`

`DecompressionOptions` configures bounds checking, dictionaries, and safety constraints for the decompression engine.

```zig
pub const DecompressionOptions = struct {
    maxOutputSize: usize = 128 * 1024 * 1024,
    customDictionary: ?[]const u8 = null,
};
```

---

## Fields

### `maxOutputSize`
- **Type**: `usize`
- **Default**: `128 * 1024 * 1024` (128 MiB)
- **Description**: Safety cap defining the maximum permitted buffer allocation for uncompressed output.
  - If a compressed stream attempts to decode more bytes than this limit (e.g. from a corrupted header or a malicious "zip bomb" style attack), decompression immediately aborts with `error.OutputTooLarge`.
  - Set this value according to your application's expected data sizes and memory budget.

### `customDictionary`
- **Type**: `?[]const u8`
- **Default**: `null`
- **Description**: In-memory dictionary slice for decoding payloads that were compressed with a reference dictionary.

---

## Example Usage

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn safeDecompress(allocator: std.mem.Allocator, untrusted_data: []const u8) ![]u8 {
    return lz4.decompressWithOptions(allocator, untrusted_data, .{
        .maxOutputSize = 16 * 1024 * 1024, // 16 MiB max
        .customDictionary = null,
    });
}
```
