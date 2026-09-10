//! Example: Configuring compression levels and acceleration factors.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const text = "Exploring acceleration and compression levels in native Zig LZ4. Repeated phrases Repeated phrases!";

    var out_buf: [256]u8 = undefined;

    // 1. Fast default (acceleration = 1)
    const fast_len = try lz4.compressFast(text, &out_buf, 1);
    std.debug.print("Fast (accel=1): {d} bytes\n", .{fast_len});

    // 2. High acceleration (accel = 10, faster, slightly larger)
    const accel_len = try lz4.compressFast(text, &out_buf, 10);
    std.debug.print("Fast (accel=10): {d} bytes\n", .{accel_len});

    // 3. High Compression (level = 9, slower, tighter)
    const hc_len = try lz4.compressHC(text, &out_buf, 9);
    std.debug.print("HC (level=9): {d} bytes\n", .{hc_len});
}
