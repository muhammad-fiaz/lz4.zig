//! Example: Using caller-provided stack buffers for allocation-free operation.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const data = "Fixed stack memory buffers eliminate heap allocations entirely!";

    var compressed_storage: [128]u8 = undefined;
    var restored_storage: [128]u8 = undefined;

    // Zero-allocation compression
    const comp_len = try lz4.compress(data, &compressed_storage);

    // Zero-allocation decompression
    const decomp_len = try lz4.decompress(compressed_storage[0..comp_len], &restored_storage);

    std.debug.print("Zero-allocation roundtrip succeeded: '{s}' ({d} bytes)\n", .{
        restored_storage[0..decomp_len],
        decomp_len,
    });
}
