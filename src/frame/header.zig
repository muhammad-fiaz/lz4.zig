//! LZ4 Frame Header encoding and decoding.
//!
//! A Frame Header is the 4-byte Magic Number (0x184D2204) followed by
//! the Frame Descriptor (3 to 15 bytes). Total header length is 7 to 19 bytes.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const descriptor_mod = @import("descriptor.zig");
const options_mod = @import("../options.zig");
const BlockMaxSize = options_mod.BlockMaxSize;
const FrameDescriptor = descriptor_mod.FrameDescriptor;

pub const FrameHeader = struct {
    descriptor: FrameDescriptor,

    /// Encodes magic number (0x184D2204) + descriptor into `dst`.
    pub fn encode(self: FrameHeader, dst: []u8) errors.FrameError!usize {
        if (dst.len < constants.FRAME_HEADER_MIN_SIZE) {
            return errors.FrameError.DstCapacityTooSmall;
        }

        endian.writeU32Le(dst[0..4], constants.FRAME_MAGIC);
        const desc_len = try self.descriptor.encode(dst[4..]);
        return 4 + desc_len;
    }

    /// Decodes a Frame Header starting with magic number from `src`.
    pub fn decode(src: []const u8) errors.FrameError!struct { header: FrameHeader, bytes_consumed: usize } {
        if (src.len < 4) return errors.FrameError.SrcBufferTooSmall;

        const magic = endian.readU32Le(src[0..4]);
        if (magic != constants.FRAME_MAGIC) {
            return errors.FrameError.InvalidMagic;
        }

        const desc_res = try FrameDescriptor.decode(src[4..]);
        return .{
            .header = .{ .descriptor = desc_res.descriptor },
            .bytes_consumed = 4 + desc_res.bytes_consumed,
        };
    }
};

test "FrameHeader encode and decode" {
    const hdr = FrameHeader{
        .descriptor = .{
            .block_max_size = .max1MB,
            .content_checksum = true,
        },
    };

    var buf: [32]u8 = undefined;
    const written = try hdr.encode(&buf);

    const res = try FrameHeader.decode(buf[0..written]);
    try std.testing.expectEqual(written, res.bytes_consumed);
    try std.testing.expectEqual(BlockMaxSize.max1MB, res.header.descriptor.block_max_size);
}
