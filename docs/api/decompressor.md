---
title: Decompressor API
description: Reusable decompression context struct for maintaining state, options, and dictionaries across multiple operations.
keywords: lz4 Decompressor, reusable context zig, reset decompressor, stateful decompressor, attachDictionary
---

# `lz4.Decompressor`

The `Decompressor` struct maintains a persistent configuration, memory allocator, and optional dictionary. It automatically handles both LZ4 Frames and Raw Blocks.

```zig
pub const Decompressor = struct {
    allocator: std.mem.Allocator,
    options: DecompressionOptions,
    dict: ?[]const u8 = null,
    // ...
};
```

---

## Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, opts: DecompressionOptions) Decompressor
```

Initializes a new `Decompressor` instance with the specified allocator and decompression options.

#### Parameters
- `allocator`: Memory allocator used for allocated decompression outputs.
- `opts`: Configuration options controlling maximum uncompressed size, dictionary, etc.

---

### `deinit`

```zig
pub fn deinit(self: *Decompressor) void
```

Releases any internal resources owned by the decompressor.

---

### `reset`

```zig
pub fn reset(self: *Decompressor, opts: DecompressionOptions) void
```

Resets options and dictionary configuration without re-allocating the struct.

---

### `attachDictionary`

```zig
pub fn attachDictionary(self: *Decompressor, dict: []const u8) void
```

Attaches an in-memory dictionary slice for subsequent decompression operations.

---

### `decompress`

```zig
pub fn decompress(self: *Decompressor, src: []const u8) ![]u8
```

Decompresses `src` into a newly allocated slice. Automatically handles standard LZ4 frames or raw blocks. The caller owns the returned slice and must free it with `self.allocator`.

#### Errors
- `error.OutOfMemory`: Failed to allocate uncompressed output buffer.
- `error.MalformedInput`: Invalid LZ4 sequence or corrupted tokens.
- `error.BadChecksum`: Checksum verification mismatch.
- `error.OutputTooLarge`: Decompressed content exceeded `maxOutputSize`.

---

### `decompressInto`

```zig
pub fn decompressInto(self: *Decompressor, src: []const u8, dst: []u8) !usize
```

Decompresses `src` directly into the caller-provided `dst` buffer. Returns the exact number of decompressed bytes written.

#### Errors
- `error.DestinationBufferTooSmall`: Caller buffer is too small to contain the uncompressed data.
- `error.MalformedInput`: Corrupt byte stream.

---

## Example Usage

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var decompressor = lz4.Decompressor.init(allocator, .{
        .maxOutputSize = 50 * 1024 * 1024, // 50 MiB safety cap
    });
    defer decompressor.deinit();

    const restored = try decompressor.decompress(compressed_data);
    defer allocator.free(restored);

    std.debug.print("Restored {d} bytes\n", .{restored.len});
}
```
