//! Example: Complete I/O streaming pipeline between std.Io.Reader and std.Io.Writer.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const payload = "Streaming through std.Io.Reader and std.Io.Writer in pure native Zig 0.17.0!";

    // 1. Pipeline compression
    var in_reader = std.Io.Reader.fixed(payload);
    var compressed_storage: [512]u8 = undefined;
    var comp_writer = std.Io.Writer.fixed(&compressed_storage);

    const comp_bytes = try lz4.compressStream(
        allocator,
        &in_reader,
        &comp_writer,
        .{ .contentChecksum = true },
    );
    std.debug.print("Pipeline compressed: {d} bytes (original: {d} bytes)\n", .{
        comp_bytes,
        payload.len,
    });

    // 2. Pipeline decompression
    var comp_reader = std.Io.Reader.fixed(compressed_storage[0..comp_bytes]);
    var restored_storage: [512]u8 = undefined;
    var decomp_writer = std.Io.Writer.fixed(&restored_storage);

    const decomp_bytes = try lz4.decompressStream(
        allocator,
        &comp_reader,
        &decomp_writer,
        .{},
    );

    std.debug.print("Pipeline restored ({d} bytes): '{s}'\n", .{
        decomp_bytes,
        restored_storage[0..decomp_bytes],
    });
}
