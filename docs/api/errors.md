---
title: Error Taxonomy & Handling API
description: Comprehensive error set, error codes, and safe error-handling patterns in lz4.zig.
keywords: lz4 errors zig, CompressionError, DecompressionError, FrameError, error handling, robust zig
---

# Errors

`lz4.zig` returns typed, structured errors from the unified `lz4.Error` error set:

```zig
pub const Error = CompressionError || DecompressionError || FrameError;
```

---

## `lz4.CompressionError`

| Error | Description |
| :--- | :--- |
| `DstCapacityTooSmall` | Destination buffer is too small to receive compressed output. |
| `InputTooLarge` | Uncompressed input exceeds format limits (`2,113,929,216` bytes). |
| `CorruptInput` | Input contains invalid sequences for the selected compression mode. |
| `OutOfMemory` | System allocator failed to allocate internal context buffers. |

---

## `lz4.DecompressionError`

| Error | Description |
| :--- | :--- |
| `MalformedInput` | Input is corrupted, has illegal tokens, or violates LZ4 grammar. |
| `OffsetOutOfBounds` | Back-reference match offset is zero or points before the start of available history. |
| `CorruptLiteralLength` | Variable-length literal run was truncated or overflowed. |
| `CorruptMatchLength` | Variable-length match extension was truncated or overflowed. |
| `DstCapacityTooSmall` | Caller output buffer capacity exhausted before decompression completed. |
| `SourceBufferExhausted` | Compressed input ended abruptly in the middle of a sequence. |
| `UnexpectedEndOfStream` | Unexpected termination or missing required 5 trailing literal bytes. |
| `OutOfMemory` | System allocator failed during buffer growth. |

---

## `lz4.FrameError`

| Error | Description |
| :--- | :--- |
| `InvalidMagic` | First 4 bytes do not match `0x184D2204` or skippable frame magics. |
| `UnsupportedVersion` | Frame version field is not `01b`. |
| `ReservedBitsNonZero` | Reserved descriptor bits were non-zero. |
| `HeaderChecksumMismatch` | 1-byte descriptor checksum failed verification. |
| `BlockChecksumMismatch` | 4-byte block checksum failed verification. |
| `ContentChecksumMismatch`| 4-byte content xxHash-32 failed verification. |
| `InvalidBlockMaxSize` | Descriptor block max size is not in `4..7` (`64KB..4MB`). |
| `BlockSizeTooLarge` | Block size declared in frame exceeds descriptor limit. |
| `MissingEndMark` | Expected 4-byte `0x00000000` EndMark was not found. |
| `PrematureEndOfFrame` | Frame truncated before reading block, EndMark, or footer. |
| `DictionaryMismatch` | Frame requires a dictionary ID that does not match provided dictionary. |
| `CorruptFrame` | Corrupt block payload inside frame container. |

---

## Idiomatic Error Handling

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn processInput(allocator: std.mem.Allocator, data: []const u8) !void {
    const uncompressed = lz4.decompress(allocator, data) catch |err| switch (err) {
        error.InvalidMagic => {
            std.debug.print("Not an LZ4 file or unsupported header\n", .{});
            return;
        },
        error.ContentChecksumMismatch, error.BlockChecksumMismatch => {
            std.debug.print("Data integrity check failed: corrupt payload\n", .{});
            return;
        },
        error.MalformedInput, error.OffsetOutOfBounds => {
            std.debug.print("Malformed LZ4 block data\n", .{});
            return;
        },
        error.OutOfMemory => return err,
        else => {
            std.debug.print("Decompression error: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(uncompressed);
}
```
