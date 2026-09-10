//! Partial LZ4 block decompression.
//!
//! Decompresses up to `target_output_size` bytes from an LZ4 block, stopping
//! cleanly as soon as the target amount of decompressed data is reached.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bitstream = @import("../utils/bitstream.zig");
const memory = @import("../utils/memory.zig");

/// Decompresses up to `target_output_size` bytes from `src` into `dst`.
/// Returns the actual number of uncompressed bytes produced (<= target_output_size).
pub fn decompressPartial(
    src: []const u8,
    dst: []u8,
    target_output_size: usize,
) errors.DecompressionError!usize {
    return decompressPartialWithDict(src, dst, target_output_size, null);
}

/// Decompresses up to `target_output_size` bytes from `src` into `dst` using a dictionary.
pub fn decompressPartialWithDict(
    src: []const u8,
    dst: []u8,
    target_output_size: usize,
    dict: ?[]const u8,
) errors.DecompressionError!usize {
    const target = @min(target_output_size, dst.len);
    if (target == 0) return 0;
    if (src.len == 0) return 0;
    if (src.len == 1 and src[0] == 0) return 0;

    var ip: usize = 0;
    var op: usize = 0;
    const dict_bytes = dict orelse &[_]u8{};

    while (ip < src.len and op < target) {
        const token = src[ip];
        ip += 1;

        // Decode literal length
        var lit_len: usize = token >> constants.ML_BITS;
        if (lit_len == 15) {
            const dec = bitstream.decodeVariableLength(
                src[ip..],
                constants.MAX_INPUT_SIZE,
            ) catch |err| switch (err) {
                error.TruncatedInput => return errors.DecompressionError.SourceBufferExhausted,
                error.IntegerOverflow => return errors.DecompressionError.CorruptLiteralLength,
            };
            lit_len += dec.value;
            ip += dec.bytes_consumed;
        }

        if (ip + lit_len > src.len) {
            return errors.DecompressionError.SourceBufferExhausted;
        }

        const lit_to_copy = @min(lit_len, target - op);
        if (lit_to_copy > 0) {
            @memcpy(dst[op..][0..lit_to_copy], src[ip..][0..lit_to_copy]);
            op += lit_to_copy;
        }
        ip += lit_len;

        if (op >= target or ip == src.len) {
            return op;
        }

        if (ip + 2 > src.len) {
            return errors.DecompressionError.SourceBufferExhausted;
        }

        const offset: usize = endian.readU16Le(src[ip..]);
        ip += 2;

        if (offset == 0) {
            return errors.DecompressionError.OffsetOutOfBounds;
        }

        const max_history = op + dict_bytes.len;
        if (offset > max_history or offset > constants.MAX_DISTANCE) {
            return errors.DecompressionError.OffsetOutOfBounds;
        }

        // Decode match length
        var match_len: usize = token & constants.ML_MASK;
        if (match_len == 15) {
            const dec = bitstream.decodeVariableLength(
                src[ip..],
                constants.MAX_INPUT_SIZE,
            ) catch |err| switch (err) {
                error.TruncatedInput => return errors.DecompressionError.SourceBufferExhausted,
                error.IntegerOverflow => return errors.DecompressionError.CorruptMatchLength,
            };
            match_len += dec.value;
            ip += dec.bytes_consumed;
        }
        match_len += constants.MINMATCH;

        const match_to_copy = @min(match_len, target - op);
        if (offset <= op) {
            memory.copyMatch(dst, op, offset, match_to_copy);
        } else {
            const dict_offset = offset - op;
            memory.copyMatchFromDict(dst, op, dict_bytes, dict_offset, match_to_copy);
        }
        op += match_to_copy;
    }

    return op;
}

test "decompressPartial extracts prefix" {
    const fast = @import("../compress/fast.zig");

    const message = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()";
    var comp: [128]u8 = undefined;
    const comp_len = try fast.compressFast(message, &comp, 1, null);

    var part: [10]u8 = undefined;
    const decomp_len = try decompressPartial(comp[0..comp_len], &part, 10);
    try std.testing.expectEqual(@as(usize, 10), decomp_len);
    try std.testing.expectEqualStrings("ABCDEFGHIJ", part[0..10]);
}
