//! LZ4 Frame Descriptor serialization, parsing, and validation.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const checksum = @import("../utils/checksum.zig");
const options_mod = @import("../options.zig");
const BlockMode = options_mod.BlockMode;
const BlockMaxSize = options_mod.BlockMaxSize;

/// Structure representing parsed or prepared LZ4 Frame Descriptor.
pub const FrameDescriptor = struct {
    version: u2 = constants.FRAME_VERSION,
    block_mode: BlockMode = .independent,
    block_checksum: bool = false,
    content_checksum: bool = true,
    content_size: ?u64 = null,
    dict_id: ?u32 = null,
    block_max_size: BlockMaxSize = .max64KB,

    /// Encodes this descriptor into `dst`, including Header Checksum (HC).
    /// Returns the number of descriptor bytes written (3..15 bytes).
    pub fn encode(self: FrameDescriptor, dst: []u8) errors.FrameError!usize {
        var needed: usize = 3; // FLG(1) + BD(1) + HC(1)
        if (self.content_size != null) needed += constants.CONTENT_SIZE_SIZE;
        if (self.dict_id != null) needed += constants.DICT_ID_SIZE;

        if (dst.len < needed) return errors.FrameError.DstCapacityTooSmall;

        const start_pos: usize = 0;
        var p: usize = 0;

        // FLG byte
        var flg: u8 = @as(u8, @intCast(self.version)) << 6;
        if (self.block_mode == .independent) flg |= (1 << 5);
        if (self.block_checksum) flg |= (1 << 4);
        if (self.content_size != null) flg |= (1 << 3);
        if (self.content_checksum) flg |= (1 << 2);
        if (self.dict_id != null) flg |= 1;
        dst[p] = flg;
        p += 1;

        // BD byte
        const bd: u8 = @as(u8, self.block_max_size.toId()) << 4;
        dst[p] = bd;
        p += 1;

        // Optional Content Size
        if (self.content_size) |cs| {
            endian.writeU64Le(dst[p..], cs);
            p += 8;
        }

        // Optional Dictionary ID
        if (self.dict_id) |did| {
            endian.writeU32Le(dst[p..], did);
            p += 4;
        }

        // Compute Header Checksum: (xxHash32(descriptor_fields, seed=0) >> 8) & 0xFF
        const desc_bytes = dst[start_pos..p];
        const h32 = checksum.hash(desc_bytes, 0);
        const hc = @as(u8, @truncate(h32 >> 8));
        dst[p] = hc;
        p += 1;

        return p;
    }

    /// Decodes and validates a Frame Descriptor from `src`.
    /// Returns the parsed descriptor and the total number of bytes consumed.
    pub fn decode(src: []const u8) errors.FrameError!struct { descriptor: FrameDescriptor, bytes_consumed: usize } {
        if (src.len < 3) return errors.FrameError.SrcBufferTooSmall;

        const flg = src[0];
        const bd = src[1];

        // 1. Validate Version: must be 01b (1)
        const ver = @as(u2, @truncate(flg >> 6));
        if (ver != constants.FRAME_VERSION) {
            return errors.FrameError.UnsupportedVersion;
        }

        // 2. Validate Reserved bits in FLG (bit 1 must be 0)
        if ((flg & 0x02) != 0) {
            return errors.FrameError.ReservedBitsNonZero;
        }

        // 3. Validate Reserved bits in BD (bit 7 and bits 0..3 must be 0)
        if ((bd & 0x8F) != 0) {
            return errors.FrameError.ReservedBitsNonZero;
        }

        // 4. Validate Block MaxSize ID (bits 4..6)
        const b_id = @as(u3, @truncate((bd >> 4) & 0x07));
        const max_size = BlockMaxSize.fromId(b_id) orelse {
            return errors.FrameError.InvalidBlockMaxSize;
        };

        const block_mode: BlockMode = if ((flg & (1 << 5)) != 0) .independent else .linked;
        const block_checksum = (flg & (1 << 4)) != 0;
        const has_content_size = (flg & (1 << 3)) != 0;
        const content_checksum = (flg & (1 << 2)) != 0;
        const has_dict_id = (flg & 1) != 0;

        var expected_len: usize = 3;
        if (has_content_size) expected_len += 8;
        if (has_dict_id) expected_len += 4;

        if (src.len < expected_len) {
            return errors.FrameError.SrcBufferTooSmall;
        }

        var p: usize = 2;
        var content_size: ?u64 = null;
        if (has_content_size) {
            content_size = endian.readU64Le(src[p..]);
            p += 8;
        }

        var dict_id: ?u32 = null;
        if (has_dict_id) {
            dict_id = endian.readU32Le(src[p..]);
            p += 4;
        }

        // Validate Header Checksum
        const desc_bytes = src[0..p];
        const h32 = checksum.hash(desc_bytes, 0);
        const expected_hc = @as(u8, @truncate(h32 >> 8));
        const actual_hc = src[p];
        p += 1;

        if (actual_hc != expected_hc) {
            return errors.FrameError.HeaderChecksumMismatch;
        }

        return .{
            .descriptor = .{
                .version = ver,
                .block_mode = block_mode,
                .block_checksum = block_checksum,
                .content_checksum = content_checksum,
                .content_size = content_size,
                .dict_id = dict_id,
                .block_max_size = max_size,
            },
            .bytes_consumed = p,
        };
    }
};

test "FrameDescriptor encode and decode roundtrip" {
    const desc = FrameDescriptor{
        .block_mode = .independent,
        .block_checksum = true,
        .content_checksum = true,
        .content_size = 12345678,
        .dict_id = 0xDEADBEEF,
        .block_max_size = .max256KB,
    };

    var buf: [32]u8 = undefined;
    const written = try desc.encode(&buf);

    const res = try FrameDescriptor.decode(buf[0..written]);
    try std.testing.expectEqual(written, res.bytes_consumed);
    try std.testing.expectEqual(desc.block_mode, res.descriptor.block_mode);
    try std.testing.expectEqual(desc.block_checksum, res.descriptor.block_checksum);
    try std.testing.expectEqual(desc.content_checksum, res.descriptor.content_checksum);
    try std.testing.expectEqual(desc.content_size, res.descriptor.content_size);
    try std.testing.expectEqual(desc.dict_id, res.descriptor.dict_id);
    try std.testing.expectEqual(desc.block_max_size, res.descriptor.block_max_size);
}

test "FrameDescriptor rejects invalid checksum" {
    const desc = FrameDescriptor{};
    var buf: [32]u8 = undefined;
    const written = try desc.encode(&buf);

    // Corrupt the header checksum byte (last byte)
    buf[written - 1] ^= 0xFF;

    try std.testing.expectError(errors.FrameError.HeaderChecksumMismatch, FrameDescriptor.decode(buf[0..written]));
}
