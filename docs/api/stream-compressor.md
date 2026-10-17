---
title: StreamingCompressor API
description: Chunked push-based streaming compressor for incrementally building standard LZ4 frames.
keywords: StreamingCompressor, push streaming zig, std.io.writer compression, chunked lz4, streaming compression
---

# `lz4.StreamingCompressor`

`StreamingCompressor` enables push-based, chunk-by-chunk compression where data arrives in arbitrary increments and is emitted directly into a `std.Io.Writer`.

```zig
pub const StreamingCompressor = struct {
    allocator: std.mem.Allocator,
    stream: FrameCompressStream,
    header_written: bool = false,
    // ...
};
```

---

## Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, opts: CompressionOptions) !StreamingCompressor
```

Initializes the streaming compressor, allocating necessary block buffers and state based on `CompressionOptions`.

---

### `deinit`

```zig
pub fn deinit(self: *StreamingCompressor) void
```

Releases all internal streaming buffers.

---

### `write`

```zig
pub fn write(self: *StreamingCompressor, chunk: []const u8, w: *std.Io.Writer) !void
```

Appends `chunk` to the compressor. If the accumulated input fills a complete block (as configured by `blockMaxSize`), the block is compressed and written immediately to `w`.

On the first call to `write`, the standard LZ4 Frame Header is automatically written to `w`.

---

### `finish`

```zig
pub fn finish(self: *StreamingCompressor, w: *std.Io.Writer) !void
```

Flushes any remaining buffered input as the final block, emits the standard 4-byte `END_MARK` (`0x00000000`), appends the 4-byte content checksum if enabled, and flushes `w`.

---

## Example Usage

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn streamData(allocator: std.mem.Allocator, chunks: [][]const u8, file: std.fs.File) !void {
    var out_buffer: [65536]u8 = undefined;
    var writer = file.writer(&out_buffer);

    var compressor = try lz4.StreamingCompressor.init(allocator, .{
        .level = 1,
        .contentChecksum = true,
        .blockMaxSize = .max_64kb,
    });
    defer compressor.deinit();

    for (chunks) |chunk| {
        try compressor.write(chunk, &writer.interface);
    }

    try compressor.finish(&writer.interface);
}
```
