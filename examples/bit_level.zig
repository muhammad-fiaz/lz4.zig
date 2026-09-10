//! Example: Bit-level and variable-length integer encoding and decoding.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    std.debug.print("Bit-level and Variable-length Encoding:\n\n", .{});

    // 1. Variable-length integer encoding (LZ4 length extension encoding: 0xFF bytes)
    var buffer: [512]u8 = undefined;
    const test_lengths = [_]usize{ 0, 14, 15, 255, 510, 1000, 65535 };

    for (test_lengths) |len| {
        const encoded_len = lz4.utils.bitstream.encodeVariableLength(&buffer, len);
        const decoded = try lz4.utils.bitstream.decodeVariableLength(buffer[0..encoded_len], lz4.MAX_INPUT_SIZE);

        std.debug.print("Length {d:5} -> Encoded into {d} bytes: {x} (Decoded: {d})\n", .{
            len,
            encoded_len,
            buffer[0..encoded_len],
            decoded.value,
        });
    }

    // 2. Token layout: high 4 bits = literal length, low 4 bits = match length (-4)
    const token: u8 = (15 << 4) | 12; // 15+ literal length, 12+4=16 match length
    const lit_len_token: usize = token >> 4;
    const match_len_token: usize = (token & 0x0F) + lz4.MINMATCH;
    std.debug.print("\nToken 0x{X:0>2}: literal prefix {d}, match base length {d}\n", .{
        token,
        lit_len_token,
        match_len_token,
    });
}
