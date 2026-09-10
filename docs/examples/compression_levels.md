---
title: Compression Levels Example
description: Comparing Fast acceleration levels against High-Compression (HC levels 2..12) in lz4.zig.
---

# Compression Levels Example

`lz4.zig` provides two distinct compression engines:
1. **Fast LZ4 (Level 1)**: Focuses on maximum compression throughput. The `acceleration` parameter skips table lookup probes to achieve multi-gigabyte-per-second speeds.
2. **High-Compression LZ4 (HC, Levels 2..12)**: Uses an optimal parsing algorithm to find longer matches across a deeper chain history, maximizing compression ratios while maintaining standard LZ4 decompression speeds.

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Repetitive text corpus
    const sample = "The quick brown fox jumps over the lazy dog. " ** 200;

    std.debug.print("Original uncompressed size: {d} bytes\n\n", .{sample.len});

    // 1. Fast Mode (Default Level 1, Acceleration = 1)
    const fast_frame = try lz4.compressWithOptions(allocator, sample, .{
        .level = 1,
        .acceleration = 1,
    });
    defer allocator.free(fast_frame);
    std.debug.print("Fast Mode (Accel 1):   {d} bytes\n", .{fast_frame.len});

    // 2. Fast Mode with higher acceleration (Accel = 4)
    const fast_accel_frame = try lz4.compressWithOptions(allocator, sample, .{
        .level = 1,
        .acceleration = 4,
    });
    defer allocator.free(fast_accel_frame);
    std.debug.print("Fast Mode (Accel 4):   {d} bytes\n", .{fast_accel_frame.len});

    // 3. High-Compression Mode (Level 4)
    const hc4_frame = try lz4.compressWithOptions(allocator, sample, .{
        .level = 4,
    });
    defer allocator.free(hc4_frame);
    std.debug.print("High Compression (L4): {d} bytes\n", .{hc4_frame.len});

    // 4. Maximum High-Compression Mode (Level 9)
    const hc9_frame = try lz4.compressWithOptions(allocator, sample, .{
        .level = 9,
    });
    defer allocator.free(hc9_frame);
    std.debug.print("High Compression (L9): {d} bytes\n", .{hc9_frame.len});
}
```

---

## Technical Explanation

- **Acceleration Parameter**:
  - `acceleration = 1` searches on every step when seeking candidates.
  - `acceleration = 4` increments step intervals faster when no matches are found, greatly speeding up compression on non-compressible or sparse data.
- **HC Levels (2..12)**:
  - Level 2-4: Light HC suitable for general archives where higher ratios are desired without heavy CPU costs.
  - Level 9: Standard HC default, providing the optimal ratio-to-time trade-off.
  - Level 12: Exhaustive search with full match chain exploration.

---

## Running the Example

```bash
zig run examples/compression_levels.zig
```

### Expected Output

```console
Original uncompressed size: 9000 bytes

Fast Mode (Accel 1):   104 bytes
Fast Mode (Accel 4):   104 bytes
High Compression (L4): 74 bytes
High Compression (L9): 74 bytes
```
