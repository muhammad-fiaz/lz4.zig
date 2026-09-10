//! Dictionary-based LZ4 block decompression.

const std = @import("std");
const errors = @import("../errors.zig");
const safe = @import("safe.zig");

/// Decompresses an LZ4 compressed block using a dictionary.
pub fn decompressUsingDict(
    src: []const u8,
    dst: []u8,
    dict: []const u8,
) errors.DecompressionError!usize {
    return safe.decompressSafeWithDict(src, dst, dict);
}

test "decompressUsingDict roundtrip" {
    const dict = "abcdefghijklmnopqrstuvwxyz";
    const data = "abcdefghijklmnopqrstuvwxyz1234567890";

    const comp_dict = @import("../compress/dictionary.zig");
    var comp: [128]u8 = undefined;
    const comp_len = try comp_dict.compressUsingDict(data, &comp, dict, .{});

    var decomp: [128]u8 = undefined;
    const decomp_len = try decompressUsingDict(comp[0..comp_len], &decomp, dict);
    try std.testing.expectEqualStrings(data, decomp[0..decomp_len]);
}
