//! Unified block compression API for LZ4.

const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("../errors.zig");
const bounds = @import("../utils/bounds.zig");
const options_mod = @import("../options.zig");
const BlockCompressionOptions = options_mod.BlockCompressionOptions;
const fast = @import("fast.zig");
const hc = @import("hc.zig");
const dictionary = @import("dictionary.zig");

pub const compressBound = bounds.compressBound;

/// Compresses `src` into caller-provided `dst` using the specified block options.
pub fn compressBlock(
    src: []const u8,
    dst: []u8,
    options: BlockCompressionOptions,
) errors.CompressionError!usize {
    if (options.dict) |d| {
        return dictionary.compressUsingDict(src, dst, d, options);
    }
    if (options.level >= 2) {
        return hc.compressHc(src, dst, options.level, null);
    }
    return fast.compressFast(src, dst, options.acceleration, null);
}

/// Compresses `src` into an allocated buffer sized with `compressBound(src.len)`.
/// The returned slice is resized to exact compressed bytes before returning.
pub fn compressBlockAlloc(
    allocator: Allocator,
    src: []const u8,
    options: BlockCompressionOptions,
) (errors.CompressionError || Allocator.Error)![]u8 {
    const max_dst = bounds.compressBound(src.len);
    if (max_dst == 0 and src.len > 0) return errors.CompressionError.InputTooLarge;

    const out_buf = try allocator.alloc(u8, max_dst);
    errdefer allocator.free(out_buf);

    const written = try compressBlock(src, out_buf, options);
    return allocator.realloc(out_buf, written) catch out_buf[0..written];
}

/// Convenience one-shot default fast compression into caller-provided buffer.
pub fn compress(src: []const u8, dst: []u8) errors.CompressionError!usize {
    return compressBlock(src, dst, .{});
}

/// Convenience one-shot default fast compression returning newly allocated slice.
pub fn compressAlloc(allocator: Allocator, src: []const u8) (errors.CompressionError || Allocator.Error)![]u8 {
    return compressBlockAlloc(allocator, src, .{});
}

test "compressBlock and compressBlockAlloc" {
    const text = "Repeating words Repeating words Repeating words Repeating words!";
    var buf: [256]u8 = undefined;
    const len = try compressBlock(text, &buf, .{});
    try std.testing.expect(len < text.len);

    const alloc_res = try compressBlockAlloc(std.testing.allocator, text, .{ .level = 9 });
    defer std.testing.allocator.free(alloc_res);
    try std.testing.expect(alloc_res.len < text.len);
}
