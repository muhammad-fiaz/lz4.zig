//! Example: Library version, format introspection, and specification limits.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    std.debug.print("lz4.zig Format Introspection:\n\n", .{});
    std.debug.print("Library Version:       {s} (integer: {d})\n", .{ lz4.versionString(), lz4.versionNumber() });
    std.debug.print("Frame Magic:           0x{X:0>8}\n", .{lz4.FRAME_MAGIC});
    std.debug.print("Skippable Magic Range: 0x{X:0>8} - 0x{X:0>8}\n", .{ lz4.SKIPPABLE_MAGIC_MIN, lz4.SKIPPABLE_MAGIC_MAX });
    std.debug.print("Minimum Match Length:  {d} bytes\n", .{lz4.MINMATCH});
    std.debug.print("Max Match Distance:    {d} bytes (64 KB)\n", .{lz4.MAX_DISTANCE});
    std.debug.print("Max Block Input Size:  {d} bytes (~2.11 GB)\n", .{lz4.MAX_INPUT_SIZE});

    // Test compressBound for sample size
    const sample_size: usize = 100_000;
    std.debug.print("\nWorst-case frame bound for {d} bytes: {d} bytes\n", .{
        sample_size,
        lz4.maxCompressedSize(sample_size),
    });
}
