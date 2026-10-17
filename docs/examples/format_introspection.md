---
title: Format Introspection Example
description: Querying library version, format bounds, magic numbers, and specification constants.
keywords: format introspection example, getFrameInfo, FRAME_MAGIC, block bounds, introspection, specification constants
---

# Format Introspection Example

This example demonstrates how to introspect `lz4.zig` metadata, verify library version information, examine specification magic numbers, and calculate worst-case frame bounds.

## Overview

- **Constants**: [`lz4.FRAME_MAGIC`](/api/constants), `SKIPPABLE_MAGIC_MIN`, `SKIPPABLE_MAGIC_MAX`, `MINMATCH`, `MAX_DISTANCE`, `MAX_INPUT_SIZE`
- **Functions**: [`lz4.versionString`](/api/constants), [`lz4.versionNumber`](/api/constants), [`lz4.maxCompressedSize`](/api/#bounds-metadata-functions)

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    std.debug.print("lz4.zig Format Introspection:\n\n", .{});
    std.debug.print("Library Version:       {s} (integer: {d})\n", .{ lz4.versionString(), lz4.versionNumber() });
    std.debug.print("Frame Magic:           0x{X:0>8}\n", .{lz4.FRAME_MAGIC});
    std.debug.print("Skippable Magic Range: 0x{X:0>8} - 0x{X:0>8}\n", .{ lz4.SKIPPABLE_MAGIC_MIN, lz4.SKIPPABLE_MAGIC_MAX });
    std.debug.print("Minimum Match Length:  {d} bytes\n", .{lz4.MINMATCH});
    std.debug.print("Max Match Distance:    {d} bytes (64 KB)\n", .{lz4.MAX_DISTANCE});
    std.debug.print("Max Block Input Size:  {d} bytes (~2.11 GB)\n", .{lz4.MAX_INPUT_SIZE});

    // Test compressBound for sample size
    const sample_size: usize = 100_000;
    std.debug.print("\nWorst-case frame bound for {d} bytes: {d} bytes\n", .{
        sample_size,
        lz4.maxCompressedSize(sample_size),
    });
}
```

---

## Technical Details

- **`lz4.versionString()`**: Returns `"0.0.1"`.
- **`lz4.FRAME_MAGIC`**: `0x184D2204` represents the standard LZ4 frame specification revision v1.6.4.
- **`lz4.SKIPPABLE_MAGIC_MIN` & `MAX`**: `0x184D2A50` through `0x184D2A5F` designate user metadata frames that decoders can safely skip without decompressing.
- **`lz4.MINMATCH`**: Minimum match length of 4 bytes ensures that match encoding is always more compact than literal output.
- **`lz4.maxCompressedSize`**: Calculates the maximum output capacity required to store the compressed frame even in worst-case incompressible high-entropy payloads.

---

## Running via Build System

```bash
zig build run-format_introspection
```

### Expected Output

```console
lz4.zig Format Introspection:

Library Version:       0.0.1 (integer: 1)
Frame Magic:           0x184D2204
Skippable Magic Range: 0x184D2A50 - 0x184D2A5F
Minimum Match Length:  4 bytes
Max Match Distance:    65535 bytes (64 KB)
Max Block Input Size:  2113929216 bytes (~2.11 GB)

Worst-case frame bound for 100000 bytes: 131641 bytes
```
