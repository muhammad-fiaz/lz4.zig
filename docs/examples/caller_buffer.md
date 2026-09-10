---
title: Caller Buffer Example
description: Zero-allocation compression and decompression using pre-allocated stack or static buffers.
---

# Caller Buffer Example

In latency-critical applications such as game loops, high-frequency network systems, or embedded microcontrollers, heap allocations are prohibited. `lz4.zig` provides `compressInto` and `decompressInto` to perform operations completely within caller-provided memory.

## Overview

- **Functions**: [`lz4.compressInto`](/api/#top-level-one-shot-functions) & [`lz4.decompressInto`](/api/#top-level-one-shot-functions)
- **Allocations**: Exactly **0** heap allocations
- **Error Behavior**: Returns `error.DstCapacityTooSmall` if caller buffer is insufficient

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const raw_payload = "NetworkPacketHeader:Seq=1001;Flags=ACK;Data=PayloadSequenceData12345";

    // 1. Pre-allocate stack or statically sized buffers
    var comp_buffer: [256]u8 = undefined;
    var decomp_buffer: [256]u8 = undefined;

    // 2. Compress directly into destination slice
    const compressed_size = try lz4.compressInto(raw_payload, &comp_buffer);
    std.debug.print("Raw: {d} bytes -> Compressed into buffer: {d} bytes\n", .{
        raw_payload.len,
        compressed_size,
    });

    // 3. Decompress directly into output slice
    const decompressed_size = try lz4.decompressInto(comp_buffer[0..compressed_size], &decomp_buffer);

    std.debug.assert(std.mem.eql(u8, raw_payload, decomp_buffer[0..decompressed_size]));
    std.debug.print("Restored exact payload without heap allocations!\n", .{});
    std.debug.print("Restored payload: '{s}'\n", .{decomp_buffer[0..decompressed_size]});
}
```

---

## Step-by-Step Explanation

1. **`var comp_buffer: [256]u8 = undefined;`**: Memory is placed directly on the stack or in a pre-allocated ring buffer.
2. **`lz4.compressInto(src, dst)`**: Compresses `src` and formats it as an LZ4 frame directly into `dst`. It returns `usize` representing the exact number of bytes written.
3. **`lz4.decompressInto(src, dst)`**: Reads the frame header, parses each block, and writes directly into `dst`. Returns the uncompressed length without any dynamic allocations.

---

## Running the Example

```bash
zig run examples/caller_buffer.zig
```

### Expected Output

```console
Raw: 68 bytes -> Compressed into buffer: 79 bytes
Restored exact payload without heap allocations!
Restored payload: 'NetworkPacketHeader:Seq=1001;Flags=ACK;Data=PayloadSequenceData12345'
```
