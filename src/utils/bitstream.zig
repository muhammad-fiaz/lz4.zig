//! Helpers for encoding and decoding LZ4 variable-length length extensions.

const std = @import("std");

/// Encodes an overflow length (value after subtracting token threshold)
/// into a series of 255 bytes terminated by the remainder byte.
/// Returns the number of bytes written to `dst`.
pub fn encodeVariableLength(dst: []u8, length: usize) usize {
    var rem = length;
    var written: usize = 0;
    while (rem >= 255) {
        dst[written] = 255;
        written += 1;
        rem -= 255;
    }
    dst[written] = @as(u8, @truncate(rem));
    written += 1;
    return written;
}

/// Decodes an LZ4 variable-length integer from `src`.
/// Returns the decoded additional length and the number of bytes consumed.
pub fn decodeVariableLength(
    src: []const u8,
    max_safe_value: usize,
) error{ TruncatedInput, IntegerOverflow }!struct { value: usize, bytes_consumed: usize } {
    var val: usize = 0;
    var idx: usize = 0;

    while (idx < src.len) {
        const b = src[idx];
        idx += 1;

        if (std.math.maxInt(usize) - val < b) {
            return error.IntegerOverflow;
        }
        val += b;

        if (val > max_safe_value) {
            return error.IntegerOverflow;
        }

        if (b < 255) {
            return .{
                .value = val,
                .bytes_consumed = idx,
            };
        }
    }

    return error.TruncatedInput;
}

test "variable length encode and decode roundtrip" {
    const test_values = [_]usize{ 0, 1, 10, 254, 255, 256, 510, 511, 1000, 65535, 100000 };
    var buf: [1024]u8 = undefined;

    for (test_values) |val| {
        const written = encodeVariableLength(&buf, val);
        const res = try decodeVariableLength(buf[0..written], std.math.maxInt(usize));
        try std.testing.expectEqual(val, res.value);
        try std.testing.expectEqual(written, res.bytes_consumed);
    }
}
