//! Example: Reusable compressor and decompressor contexts eliminating allocation churn.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Initialize compressor and decompressor once
    var compressor = lz4.Compressor.init(allocator, .{ .level = 1 });
    defer compressor.deinit();

    var decompressor = lz4.Decompressor.init(allocator, .{});
    defer decompressor.deinit();

    // First round of data
    const input1 = "Stream 1: Telemetry packets flowing through reusable context.";
    const comp1 = try compressor.compress(input1);
    defer allocator.free(comp1);

    const out1 = try decompressor.decompress(comp1);
    defer allocator.free(out1);
    std.debug.print("Stream 1 restored ({d} bytes): '{s}'\n", .{ out1.len, out1 });

    // 2. Reset compressor state for High-Compression mode without reallocating
    compressor.reset(.{ .level = 9 });
    decompressor.reset(.{});

    // Second round of data
    const input2 = "Stream 2: High compression telemetry archive using reset state.";
    const comp2 = try compressor.compress(input2);
    defer allocator.free(comp2);

    const out2 = try decompressor.decompress(comp2);
    defer allocator.free(out2);
    std.debug.print("Stream 2 restored ({d} bytes): '{s}'\n", .{ out2.len, out2 });
}
