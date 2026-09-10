---
title: Frame Header & Format
description: LZ4 Frame Format v1.6.4, frame descriptors, block sequences, and format introspection in lz4.zig.
---

# Frame Header & Format

`lz4.zig` adheres to the official **LZ4 Frame Format Specification (v1.6.4)**.

An LZ4 frame consists of:
1. **Magic Number** (4 bytes): `0x184D2204` (Little Endian).
2. **Frame Descriptor** (3 to 15 bytes): Contains flags, block size identifier, optional content size, optional dictionary ID, and a 1-byte header checksum (HC).
3. **Data Blocks**: Zero or more blocks, each with a 4-byte size header, compressed or uncompressed payload, and optional 4-byte block checksum.
4. **EndMark** (4 bytes): `0x00000000`.
5. **Content Checksum** (optional, 4 bytes): xxHash-32 checksum of the decoded content.

---

## `lz4.FrameHeader`

Represents the decoded or prepared frame header:

```zig
pub const FrameHeader = struct {
    descriptor: FrameDescriptor,

    pub fn encode(self: FrameHeader, dst: []u8) errors.FrameError!usize;
    pub fn decode(src: []const u8) errors.FrameError!struct {
        header: FrameHeader,
        bytes_consumed: usize,
    };
};
```

---

## `lz4.FrameDescriptor`

```zig
pub const FrameDescriptor = struct {
    version: u2 = 1,
    block_mode: BlockMode = .independent,
    block_checksum: bool = false,
    content_checksum: bool = true,
    content_size: ?u64 = null,
    dict_id: ?u32 = null,
    block_max_size: BlockMaxSize = .max64KB,

    pub fn encode(self: FrameDescriptor, dst: []u8) errors.FrameError!usize;
    pub fn decode(src: []const u8) errors.FrameError!struct {
        descriptor: FrameDescriptor,
        bytes_consumed: usize,
    };
};
```

---

## Introspecting Frames with `getFrameInfo`

Inspect a frame without decoding its payload:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn inspect(frame_data: []const u8) !void {
    const info = try lz4.getFrameInfo(frame_data);

    std.debug.print("Block Max Size:    {}\n", .{info.descriptor.block_max_size});
    std.debug.print("Block Mode:        {}\n", .{info.descriptor.block_mode});
    std.debug.print("Content Checksum:  {}\n", .{info.descriptor.content_checksum});
    std.debug.print("Content Size:      {?d}\n", .{info.descriptor.content_size});
    std.debug.print("Dictionary ID:     {?x}\n", .{info.descriptor.dict_id});
}
```

---

## Skippable Frames

LZ4 defines skippable frames (`0x184D2A50` through `0x184D2A5F`) for embedding user metadata, timestamps, or application headers inside a compressed file without breaking decoders.

Each skippable frame has:
- 4 bytes: Magic Number (`0x184D2A5X`)
- 4 bytes: Frame Size ($N$ bytes)
- $N$ bytes: User data

`lz4.zig` automatically recognizes and skips over skippable frames when decompressing concatenated streams.
