//! Fast match finder routines and common byte counting.

const std = @import("std");
const constants = @import("../internal/constants.zig");

/// Multiplicative hash for 4-byte sequence.
pub inline fn hash4(sequence: u32, hash_log: u5) u32 {
    const shift: u5 = @truncate(32 - @as(u6, hash_log));
    return (sequence *% 2654435761) >> shift;
}

/// Computes the number of identical prefix bytes between `p1` and `p2`, up to `max_len`.
pub inline fn countCommonBytes(p1: []const u8, p2: []const u8, max_len: usize) usize {
    const limit = @min(@min(p1.len, p2.len), max_len);
    var idx: usize = 0;

    // 8-byte word comparison
    while (idx + 8 <= limit) : (idx += 8) {
        const v1 = std.mem.readInt(u64, p1[idx..][0..8], .little);
        const v2 = std.mem.readInt(u64, p2[idx..][0..8], .little);
        const diff = v1 ^ v2;
        if (diff != 0) {
            const common = @ctz(diff) / 8;
            return idx + common;
        }
    }

    // 4-byte comparison if >= 4 bytes left
    if (idx + 4 <= limit) {
        const v1 = std.mem.readInt(u32, p1[idx..][0..4], .little);
        const v2 = std.mem.readInt(u32, p2[idx..][0..4], .little);
        const diff = v1 ^ v2;
        if (diff != 0) {
            const common = @ctz(diff) / 8;
            return idx + common;
        }
        idx += 4;
    }

    // Tail byte-by-byte comparison
    while (idx < limit and p1[idx] == p2[idx]) : (idx += 1) {}

    return idx;
}

test "countCommonBytes correctness" {
    const a = "Hello, World! ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const b = "Hello, World! 1234567890";
    try std.testing.expectEqual(14, countCommonBytes(a, b, 100));
    try std.testing.expectEqual(10, countCommonBytes(a, b, 10));

    const c = "AAAAAAAA";
    const d = "AAAAAAAA";
    try std.testing.expectEqual(8, countCommonBytes(c, d, 8));
}
