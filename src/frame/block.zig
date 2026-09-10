//! Frame data block and footer encoding, decoding, and checksum verification.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const checksum = @import("../utils/checksum.zig");

pub const BlockHeader = struct {
    is_end_mark: bool,
    is_uncompressed: bool,
    size: usize,

    /// Parse 4-byte block size field from `src`.
    pub fn parse(src: []const u8) errors.FrameError!BlockHeader {
        if (src.len < 4) return errors.FrameError.SrcBufferTooSmall;

        const val = endian.readU32Le(src[0..4]);
        if (val == constants.END_MARK) {
            return .{
                .is_end_mark = true,
                .is_uncompressed = false,
                .size = 0,
            };
        }

        const is_uncompressed = (val & constants.UNCOMPRESSED_FLAG) != 0;
        const size = @as(usize, val & ~constants.UNCOMPRESSED_FLAG);

        return .{
            .is_end_mark = false,
            .is_uncompressed = is_uncompressed,
            .size = size,
        };
    }

    /// Encode 4-byte block size field into `dst`.
    pub fn encode(dst: []u8, size: usize, is_uncompressed: bool) errors.FrameError!void {
        if (dst.len < 4) return errors.FrameError.DstCapacityTooSmall;

        var val = @as(u32, @truncate(size));
        if (is_uncompressed) {
            val |= constants.UNCOMPRESSED_FLAG;
        }
        endian.writeU32Le(dst[0..4], val);
    }
};

/// Writes the 4-byte 0x00000000 EndMark into `dst`.
pub fn writeEndMark(dst: []u8) errors.FrameError!usize {
    if (dst.len < 4) return errors.FrameError.DstCapacityTooSmall;
    endian.writeU32Le(dst[0..4], constants.END_MARK);
    return 4;
}

/// Computes the xxHash-32 block checksum for raw block data.
pub fn computeBlockChecksum(raw_block: []const u8) u32 {
    return checksum.hash(raw_block, 0);
}

/// Verifies whether `actual_checksum` matches the xxHash-32 of `raw_block`.
pub fn verifyBlockChecksum(raw_block: []const u8, expected_checksum: u32) bool {
    return computeBlockChecksum(raw_block) == expected_checksum;
}

test "BlockHeader parse and encode" {
    var buf: [4]u8 = undefined;

    try BlockHeader.encode(&buf, 1024, false);
    const h1 = try BlockHeader.parse(&buf);
    try std.testing.expect(!h1.is_end_mark);
    try std.testing.expect(!h1.is_uncompressed);
    try std.testing.expectEqual(@as(usize, 1024), h1.size);

    try BlockHeader.encode(&buf, 2048, true);
    const h2 = try BlockHeader.parse(&buf);
    try std.testing.expect(!h2.is_end_mark);
    try std.testing.expect(h2.is_uncompressed);
    try std.testing.expectEqual(@as(usize, 2048), h2.size);

    _ = try writeEndMark(&buf);
    const h3 = try BlockHeader.parse(&buf);
    try std.testing.expect(h3.is_end_mark);
}
