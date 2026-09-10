//! Unified block decompression API for LZ4.

const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("../errors.zig");
const safe = @import("safe.zig");
const partial = @import("partial.zig");
const dictionary = @import("dictionary.zig");

/// Decompresses an LZ4 compressed block into caller-provided `dst`.
pub fn decompressBlock(src: []const u8, dst: []u8) errors.DecompressionError!usize {
    return safe.decompressSafe(src, dst);
}

/// Decompresses an LZ4 compressed block into newly allocated memory.
/// `max_uncompressed_size` specifies the maximum buffer to allocate.
pub fn decompressBlockAlloc(
    allocator: Allocator,
    src: []const u8,
    max_uncompressed_size: usize,
) (errors.DecompressionError || Allocator.Error)![]u8 {
    const buf = try allocator.alloc(u8, max_uncompressed_size);
    errdefer allocator.free(buf);

    const decomp_len = try decompressBlock(src, buf);
    return allocator.realloc(buf, decomp_len) catch buf[0..decomp_len];
}

/// Convenience one-shot default decompression into caller-provided buffer.
pub const decompress = decompressBlock;

/// Convenience one-shot default decompression returning newly allocated slice.
pub const decompressAlloc = decompressBlockAlloc;

/// Partially decompresses up to `target_size` bytes.
pub fn decompressBlockPartial(
    src: []const u8,
    dst: []u8,
    target_size: usize,
) errors.DecompressionError!usize {
    return partial.decompressPartial(src, dst, target_size);
}

/// Decompresses using a reference dictionary.
pub fn decompressBlockWithDict(
    src: []const u8,
    dst: []u8,
    dict: []const u8,
) errors.DecompressionError!usize {
    return dictionary.decompressUsingDict(src, dst, dict);
}

test "decompressBlock roundtrip" {
    const comp_mod = @import("../compress/block.zig");

    const message = "Sample text for block roundtrip testing in lz4.zig package.";
    var comp_buf: [256]u8 = undefined;
    const comp_len = try comp_mod.compress(message, &comp_buf);

    var decomp_buf: [256]u8 = undefined;
    const decomp_len = try decompress(comp_buf[0..comp_len], &decomp_buf);

    try std.testing.expectEqualStrings(message, decomp_buf[0..decomp_len]);

    const alloc_decomp = try decompressAlloc(std.testing.allocator, comp_buf[0..comp_len], 1024);
    defer std.testing.allocator.free(alloc_decomp);
    try std.testing.expectEqualStrings(message, alloc_decomp);
}
