---
title: Compressor API
description: Reusable compression context struct for maintaining state, options, and dictionaries across multiple operations.
keywords: lz4 Compressor, reusable context zig, reset compressor, attachDictionary, zero allocation loop
---

# `lz4.Compressor`

The `Compressor` struct maintains a persistent configuration, memory allocator, and optional dictionary. Reusing a `Compressor` instance avoids re-initializing configuration tables across multiple compression calls.

```zig
pub const Compressor = struct {
    allocator: std.mem.Allocator,
    options: CompressionOptions,
    dict: ?[]const u8 = null,
    // ...
};
```

---

## Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, opts: CompressionOptions) Compressor
```

Initializes a new `Compressor` instance with the specified allocator and compression options.

#### Parameters
- `allocator`: Memory allocator used for allocated compression outputs.
- `opts`: Configuration options controlling level, block max size, checksums, etc.

---

### `deinit`

```zig
pub fn deinit(self: *Compressor) void
```

Releases any internal resources owned by the compressor.

---

### `reset`

```zig
pub fn reset(self: *Compressor, opts: CompressionOptions) void
```

Resets the compressor options and dictionary without re-allocating the struct itself.

---

### `attachDictionary`

```zig
pub fn attachDictionary(self: *Compressor, dict: []const u8) void
```

Attaches an in-memory dictionary slice for subsequent compression operations.

---

### `compress`

```zig
pub fn compress(self: *Compressor, src: []const u8) ![]u8
```

Compresses `src` into a newly allocated slice containing a valid LZ4 Frame. The caller owns the returned slice and must free it using `self.allocator`.

#### Errors
- `error.OutOfMemory`: Failed to allocate output frame buffer.
- `error.InputTooLarge`: Input exceeds `MAX_INPUT_SIZE`.
- Other `CompressionError` codes.

---

### `compressInto`

```zig
pub fn compressInto(self: *Compressor, src: []const u8, dst: []u8) !usize
```

Compresses `src` directly into the caller-provided `dst` buffer (in LZ4 Frame format). Returns the number of compressed bytes written into `dst`.

#### Errors
- `error.DestinationBufferTooSmall`: `dst` buffer capacity is insufficient.
- `error.InputTooLarge`: `src` exceeds maximum format size.
- Other `CompressionError` codes.

---

## Example Usage

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compressor = lz4.Compressor.init(allocator, .{
        .level = 1,
        .contentChecksum = true,
    });
    defer compressor.deinit();

    const output1 = try compressor.compress("First payload data");
    defer allocator.free(output1);

    const output2 = try compressor.compress("Second payload data");
    defer allocator.free(output2);
}
```
