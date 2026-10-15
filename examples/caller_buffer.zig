//! Example: Using caller-provided stack buffers for zero-allocation operation.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const data = "Fixed stack memory buffers eliminate heap allocations entirely!";

    var frame_storage: [256]u8 = undefined;
    var block_storage: [256]u8 = undefined;
    var restored_storage: [256]u8 = undefined;

    // 1. Zero-allocation frame compression & decompression
    const frame_len = try lz4.compressInto(data, &frame_storage);
    const frame_restored_len = try lz4.decompressInto(frame_storage[0..frame_len], &restored_storage);

    std.debug.print("Zero-allocation frame roundtrip succeeded: '{s}' ({d} bytes)\n", .{
        restored_storage[0..frame_restored_len],
        frame_restored_len,
    });

    // 2. Zero-allocation raw block compression & decompression
    const block_len = try lz4.compress(data, &block_storage);
    const block_restored_len = try lz4.decompress(block_storage[0..block_len], &restored_storage);

    std.debug.print("Zero-allocation block roundtrip succeeded: '{s}' ({d} bytes)\n", .{
        restored_storage[0..block_restored_len],
        block_restored_len,
    });
}
