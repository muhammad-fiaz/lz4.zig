---
title: CompressionOptions
description: Complete specification of compression options, levels, block sizes, and frame descriptors in lz4.zig.
---

# `lz4.CompressionOptions`

`CompressionOptions` configures how data is compressed into LZ4 frames and blocks.

```zig
pub const CompressionOptions = struct {
    level: i32 = 1,
    acceleration: u32 = 1,
    blockMaxSize: BlockMaxSize = .max64KB,
    blockMode: BlockMode = .independent,
    contentChecksum: bool = true,
    blockChecksum: bool = false,
    contentSize: ?u64 = null,
    dictId: ?u32 = null,
    customDictionary: ?[]const u8 = null,
    favorDecSpeed: bool = false,
    autoFlush: bool = true,
};
```

---

## Fields

### `level`
- **Type**: `i32`
- **Default**: `1`
- **Description**: Compression mode selector:
  - `1`: Standard Fast LZ4 engine.
  - `2..12`: High-Compression (HC) engine with deeper match parsing. Level 9 is the standard HC recommended setting.

### `acceleration`
- **Type**: `u32`
- **Default**: `1`
- **Description**: Speed acceleration step for level 1. Values higher than `1` (e.g., `2`, `4`, `8`) skip search probes to increase encoding throughput at a modest cost in compression ratio.

### `blockMaxSize`
- **Type**: `BlockMaxSize`
- **Default**: `.max64KB`
- **Options**:
  - `.max64KB`: 64 KiB blocks (low memory overhead).
  - `.max256KB`: 256 KiB blocks.
  - `.max1MB`: 1 MiB blocks.
  - `.max4MB`: 4 MiB blocks (higher compression on large files).

### `blockMode`
- **Type**: `BlockMode`
- **Default**: `.independent`
- **Options**:
  - `.independent`: Each block can be parsed without state from previous blocks.
  - `.linked`: Blocks reference the sliding 64 KiB window of the preceding block.

### `contentChecksum`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Computes a 32-bit xxHash-32 checksum of the entire uncompressed stream and writes it immediately following the `END_MARK`.

### `blockChecksum`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Appends a 32-bit xxHash-32 checksum directly after each compressed block payload.

### `contentSize`
- **Type**: `?u64`
- **Default**: `null` (auto-populated with `src.len` in one-shot operations)
- **Description**: 8-byte original uncompressed size recorded in the frame header for verification and fast decoder pre-allocation.

### `dictId`
- **Type**: `?u32`
- **Default**: `null`
- **Description**: Optional 4-byte dictionary identifier stored in the frame descriptor.

### `customDictionary`
- **Type**: `?[]const u8`
- **Default**: `null`
- **Description**: In-memory dictionary buffer used to initialize match history.

### `favorDecSpeed`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Directs the HC parser to prefer match structures that maximize decompression throughput.

### `autoFlush`
- **Type**: `bool`
- **Default**: `true`
- **Description**: In streaming mode, flushes blocks immediately without waiting for a full `blockMaxSize` buffer.
