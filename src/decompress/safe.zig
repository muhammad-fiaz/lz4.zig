//! Safe, fully bounds-checked native LZ4 block decompression.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bitstream = @import("../utils/bitstream.zig");
const memory = @import("../utils/memory.zig");
const validation = @import("../internal/validation.zig");

/// Decompresses an LZ4 compressed block from `src` into caller-provided `dst`.
/// Returns the number of uncompressed bytes produced.
pub fn decompressSafe(src: []const u8, dst: []u8) errors.DecompressionError!usize {
    return decompressSafeWithDict(src, dst, null);
}

/// Decompresses an LZ4 compressed block with an optional preceding dictionary.
pub fn decompressSafeWithDict(
    src: []const u8,
    dst: []u8,
    dict: ?[]const u8,
) errors.DecompressionError!usize {
    if (src.len == 0) {
        if (dst.len == 0) return 0;
        return errors.DecompressionError.MalformedInput;
    }

    // Special case for single-byte token representing empty block or small literals
    if (src.len == 1 and src[0] == 0) {
        return 0;
    }

    var ip: usize = 0;
    var op: usize = 0;
    const dict_bytes = dict orelse &[_]u8{};

    while (ip < src.len) {
        // Read token byte
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

        // Copy literals
        if (ip + lit_len > src.len) {
            return errors.DecompressionError.SourceBufferExhausted;
        }
        if (op + lit_len > dst.len) {
            return errors.DecompressionError.DstCapacityTooSmall;
        }

        if (lit_len > 0) {
            @memcpy(dst[op..][0..lit_len], src[ip..][0..lit_len]);
            op += lit_len;
            ip += lit_len;
        }

        // Check for end of block (last sequence only contains literals)
        if (ip == src.len) {
            return op;
        }

        // If not end of block, at least offset (2 bytes) must be present
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

        if (op + match_len > dst.len) {
            return errors.DecompressionError.DstCapacityTooSmall;
        }

        // Execute match copy
        if (offset <= op) {
            // Match is entirely within destination buffer history
            memory.copyMatch(dst, op, offset, match_len);
        } else {
            // Match begins in external dictionary
            const dict_offset = offset - op;
            memory.copyMatchFromDict(dst, op, dict_bytes, dict_offset, match_len);
        }
        op += match_len;
    }

    return op;
}

test "decompressSafe on fast compressed data" {
    const fast = @import("../compress/fast.zig");

    const original = "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.";
    var comp_buf: [256]u8 = undefined;
    const comp_len = try fast.compressFast(original, &comp_buf, 1, null);

    var decomp_buf: [256]u8 = undefined;
    const decomp_len = try decompressSafe(comp_buf[0..comp_len], &decomp_buf);

    try std.testing.expectEqual(original.len, decomp_len);
    try std.testing.expectEqualStrings(original, decomp_buf[0..decomp_len]);
}
