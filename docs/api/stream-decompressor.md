---
title: StreamingDecompressor
description: Chunked pull-based streaming decompressor for consuming incoming compressed fragments.
---

# `lz4.StreamingDecompressor`

`StreamingDecompressor` enables pull-based, chunk-by-chunk decompression. Compressed byte slices are fed as they arrive from a socket or file stream, and decompressed bytes are drained into caller-provided buffers.

```zig
pub const StreamingDecompressor = struct {
    allocator: std.mem.Allocator,
    options: DecompressionOptions,
    // ...
};
```

---

## Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, opts: DecompressionOptions) StreamingDecompressor
```

Initializes an incremental decompressor with the specified options.

---

### `deinit`

```zig
pub fn deinit(self: *StreamingDecompressor) void
```

Frees internal accumulation buffers.

---

### `reset`

```zig
pub fn reset(self: *StreamingDecompressor) void
```

Clears buffers and resets state for decoding a new stream while retaining allocated capacity.

---

### `feed`

```zig
pub fn feed(self: *StreamingDecompressor, chunk: []const u8) !void
```

Appends `chunk` of compressed data to the internal input buffer.

---

### `take`

```zig
pub fn take(self: *StreamingDecompressor, dst: []u8) !usize
```

Extracts available uncompressed bytes into `dst`. Returns the number of bytes written. If more decompressed data is available than can fit in `dst`, subsequent calls to `take` will continue draining the buffer until it returns `0`.

---

### `isFinished`

```zig
pub fn isFinished(self: *const StreamingDecompressor) bool
```

Returns `true` when all compressed frames have been completely decoded and all uncompressed data has been drained via `take`.

---

## Example Usage

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn processStream(allocator: std.mem.Allocator, socket: std.net.Stream) !void {
    var decompressor = lz4.StreamingDecompressor.init(allocator, .{});
    defer decompressor.deinit();

    var network_buf: [4096]u8 = undefined;
    var output_buf: [4096]u8 = undefined;

    while (true) {
        const bytes_read = try socket.read(&network_buf);
        if (bytes_read == 0) break;

        try decompressor.feed(network_buf[0..bytes_read]);

        while (true) {
            const count = try decompressor.take(&output_buf);
            if (count == 0) break;

            // Handle uncompressed bytes in output_buf[0..count]
        }
    }
}
```
