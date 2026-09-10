---
title: Constants
description: Magic numbers, format limits, and algorithmic constants defined in lz4.zig.
---

# Constants

The following constants are exposed by `lz4` for format introspection, buffer sizing, and protocol integration.

## Magic Numbers

| Constant | Value | Description |
| :--- | :--- | :--- |
| `lz4.FRAME_MAGIC` | `0x184D2204` | Standard LZ4 Frame Format magic identifier (Little Endian). |
| `lz4.LEGACY_MAGIC` | `0x184C2102` | Legacy LZ4 frame magic number from older tooling. |
| `lz4.SKIPPABLE_MAGIC_MIN` | `0x184D2A50` | Lower bound of the 16 skippable user frame magic numbers. |
| `lz4.SKIPPABLE_MAGIC_MAX` | `0x184D2A5F` | Upper bound of the 16 skippable user frame magic numbers. |
| `lz4.END_MARK` | `0x00000000` | 4-byte block size marker designating the end of blocks in a frame. |

---

## Algorithm & Size Limits

| Constant | Value | Description |
| :--- | :--- | :--- |
| `lz4.MINMATCH` | `4` | Minimum byte length for an LZ4 back-reference match sequence. |
| `lz4.MAX_DISTANCE` | `65535` | Maximum backwards offset distance (64 KiB - 1 byte). |
| `lz4.MAX_INPUT_SIZE` | `0x7E000000` | Maximum single-block uncompressed size (~2,113,929,216 bytes). |

---

## Block Capacity Limits

| Constant | Value | Description |
| :--- | :--- | :--- |
| `BLOCK_SIZE_64KB` | `65,536` bytes | 64 KiB uncompressed block buffer capacity. |
| `BLOCK_SIZE_256KB` | `262,144` bytes | 256 KiB uncompressed block buffer capacity. |
| `BLOCK_SIZE_1MB` | `1,048,576` bytes | 1 MiB uncompressed block buffer capacity. |
| `BLOCK_SIZE_4MB` | `4,194,304` bytes | 4 MiB uncompressed block buffer capacity. |
