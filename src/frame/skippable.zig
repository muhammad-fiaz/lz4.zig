//! LZ4 Skippable Frame encoding and decoding.
//!
//! Skippable frames allow arbitrary user data to be embedded in an LZ4 stream.
//! Magic number: 0x184D2A50 .. 0x184D2A5F (4 bytes LE)
//! Frame Size: 4 bytes LE
//! User Data: Frame Size bytes.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");

/// Checks if a 32-bit magic number belongs to the skippable frame range (0x184D2A50 .. 0x184D2A5F).
pub inline fn isSkippableMagic(magic: u32) bool {
    return magic >= constants.SKIPPABLE_MAGIC_MIN and magic <= constants.SKIPPABLE_MAGIC_MAX;
}

/// Encodes a skippable frame containing `user_data` into `dst`.
pub fn encodeSkippableFrame(dst: []u8, magic_sub_id: u4, user_data: []const u8) errors.FrameError!usize {
    const total_len = 8 + user_data.len;
    if (dst.len < total_len) return errors.FrameError.DstCapacityTooSmall;

    const magic = constants.SKIPPABLE_MAGIC_MIN + @as(u32, magic_sub_id);
    endian.writeU32Le(dst[0..4], magic);
    endian.writeU32Le(dst[4..8], @as(u32, @truncate(user_data.len)));
    if (user_data.len > 0) {
        @memcpy(dst[8..total_len], user_data);
    }
    return total_len;
}

/// Parses a skippable frame header and returns the user data size and consumed header bytes.
pub fn parseSkippableHeader(src: []const u8) errors.FrameError!struct { user_data_size: usize, header_size: usize } {
    if (src.len < 8) return errors.FrameError.SrcBufferTooSmall;

    const magic = endian.readU32Le(src[0..4]);
    if (!isSkippableMagic(magic)) return errors.FrameError.InvalidMagic;

    const data_size = endian.readU32Le(src[4..8]);
    return .{
        .user_data_size = data_size,
        .header_size = 8,
    };
}

/// Skips an entire skippable frame, returning the total number of bytes skipped (8 + user_data_size).
pub fn skipFrame(src: []const u8) errors.FrameError!usize {
    const hdr = try parseSkippableHeader(src);
    const total = hdr.header_size + hdr.user_data_size;
    if (src.len < total) return errors.FrameError.PrematureEndOfFrame;
    return total;
}

test "skippable frame encode and skip" {
    const user_data = "Custom metadata payload 12345";
    var buf: [64]u8 = undefined;

    const written = try encodeSkippableFrame(&buf, 3, user_data);
    try std.testing.expectEqual(8 + user_data.len, written);

    const skipped = try skipFrame(buf[0..written]);
    try std.testing.expectEqual(written, skipped);
}
