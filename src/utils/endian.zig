//! Explicit Little-Endian encoding and decoding helpers for cross-platform portability.

const std = @import("std");

pub inline fn readU16Le(ptr: []const u8) u16 {
    return std.mem.readInt(u16, ptr[0..2], .little);
}

pub inline fn readU32Le(ptr: []const u8) u32 {
    return std.mem.readInt(u32, ptr[0..4], .little);
}

pub inline fn readU64Le(ptr: []const u8) u64 {
    return std.mem.readInt(u64, ptr[0..8], .little);
}

pub inline fn writeU16Le(dst: []u8, val: u16) void {
    std.mem.writeInt(u16, dst[0..2], val, .little);
}

pub inline fn writeU32Le(dst: []u8, val: u32) void {
    std.mem.writeInt(u32, dst[0..4], val, .little);
}

pub inline fn writeU64Le(dst: []u8, val: u64) void {
    std.mem.writeInt(u64, dst[0..8], val, .little);
}

test "endian read write symmetry" {
    var buf: [8]u8 = undefined;

    writeU16Le(buf[0..2], 0x1234);
    try std.testing.expectEqual(@as(u16, 0x1234), readU16Le(buf[0..2]));

    writeU32Le(buf[0..4], 0x184D2204);
    try std.testing.expectEqual(@as(u32, 0x184D2204), readU32Le(buf[0..4]));

    writeU64Le(buf[0..8], 0x0102030405060708);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), readU64Le(buf[0..8]));
}
