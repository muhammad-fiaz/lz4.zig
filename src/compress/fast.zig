//! Native LZ4 fast block compression.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bitstream = @import("../utils/bitstream.zig");
const match_finder = @import("match_finder.zig");
const tables = @import("../internal/tables.zig");

/// Compresses `src` into `dst` using the fast LZ4 compression algorithm.
/// Returns the number of bytes written to `dst`.
pub fn compressFast(
    src: []const u8,
    dst: []u8,
    acceleration: u32,
    table: ?*tables.FastTable,
) errors.CompressionError!usize {
    if (src.len > constants.MAX_INPUT_SIZE) {
        return errors.CompressionError.InputTooLarge;
    }

    // Small or empty inputs cannot contain matches (MFLIMIT constraint)
    if (src.len < constants.MIN_LENGTH) {
        const required = 1 + (if (src.len >= 15) (src.len - 15) / 255 + 1 else 0) + src.len;
        if (dst.len < required) return errors.CompressionError.DstCapacityTooSmall;

        var op: usize = 0;
        if (src.len >= 15) {
            dst[op] = 15 << constants.ML_BITS;
            op += 1;
            op += bitstream.encodeVariableLength(dst[op..], src.len - 15);
        } else {
            dst[op] = @as(u8, @truncate(src.len)) << constants.ML_BITS;
            op += 1;
        }
        if (src.len > 0) {
            @memcpy(dst[op..][0..src.len], src);
            op += src.len;
        }
        return op;
    }

    var local_table: tables.FastTable = undefined;
    const hash_table = if (table) |t| t else blk: {
        local_table = tables.FastTable.init();
        break :blk &local_table;
    };
    hash_table.clear();

    var op: usize = 0;
    var ip: usize = 0;
    var anchor: usize = 0;

    const mflimit = src.len - constants.MFLIMIT;
    const matchlimit = src.len - constants.LASTLITERALS;

    const accel = @min(@max(acceleration, 1), constants.ACCELERATION_MAX);
    var search_match_nb: u32 = accel << 6;
    var forward_ip: usize = ip;
    var step: usize = 1;

    main_loop: while (true) {
        // Match finding loop
        var match_pos: usize = undefined;
        while (true) {
            ip = forward_ip;
            forward_ip += step;
            step = (search_match_nb >> 6);
            search_match_nb += 1;

            if (forward_ip > mflimit) break :main_loop;

            const seq = endian.readU32Le(src[ip..]);
            const h = match_finder.hash4(seq, constants.HASH_LOG_DEFAULT);
            const candidate = hash_table.table[h];
            hash_table.table[h] = @as(u32, @truncate(ip));

            if (candidate > 0 and (ip - candidate) <= constants.MAX_DISTANCE) {
                if (endian.readU32Le(src[candidate..]) == seq) {
                    match_pos = candidate;
                    break;
                }
            }
        }

        // Backward extension: catch up previous bytes if identical
        while (ip > anchor and match_pos > 0 and src[ip - 1] == src[match_pos - 1]) {
            ip -= 1;
            match_pos -= 1;
        }

        // Encode sequence literals
        const lit_len = ip - anchor;
        const token_pos = op;
        op += 1; // reserve byte for token

        // Check buffer capacity for literals
        const lit_overhead = if (lit_len >= 15) (lit_len - 15) / 255 + 1 else 0;
        if (op + lit_overhead + lit_len + 2 > dst.len) {
            return errors.CompressionError.DstCapacityTooSmall;
        }

        if (lit_len >= 15) {
            dst[token_pos] = 15 << constants.ML_BITS;
            op += bitstream.encodeVariableLength(dst[op..], lit_len - 15);
        } else {
            dst[token_pos] = @as(u8, @truncate(lit_len)) << constants.ML_BITS;
        }

        if (lit_len > 0) {
            @memcpy(dst[op..][0..lit_len], src[anchor..][0..lit_len]);
            op += lit_len;
        }

        // Encode offset (2 bytes little-endian)
        const offset = @as(u16, @truncate(ip - match_pos));
        std.debug.assert(offset > 0);
        endian.writeU16Le(dst[op..], offset);
        op += 2;

        // Encode match length
        const common = match_finder.countCommonBytes(
            src[ip + constants.MINMATCH ..],
            src[match_pos + constants.MINMATCH ..],
            matchlimit - (ip + constants.MINMATCH),
        );
        const match_len = constants.MINMATCH + common;
        ip += match_len;
        anchor = ip;

        const match_code = match_len - constants.MINMATCH;
        const match_overhead = if (match_code >= 15) (match_code - 15) / 255 + 1 else 0;
        if (op + match_overhead > dst.len) {
            return errors.CompressionError.DstCapacityTooSmall;
        }

        if (match_code >= 15) {
            dst[token_pos] |= 15;
            op += bitstream.encodeVariableLength(dst[op..], match_code - 15);
        } else {
            dst[token_pos] |= @as(u8, @truncate(match_code));
        }

        if (ip > mflimit) break :main_loop;

        // Populate table with position before ip
        const prev_seq = endian.readU32Le(src[ip - 2 ..]);
        const prev_h = match_finder.hash4(prev_seq, constants.HASH_LOG_DEFAULT);
        hash_table.table[prev_h] = @as(u32, @truncate(ip - 2));

        forward_ip = ip;
        step = 1;
        search_match_nb = accel << 6;
    }

    // Encode last literals
    const last_lit_len = src.len - anchor;
    const last_lit_overhead = if (last_lit_len >= 15) (last_lit_len - 15) / 255 + 1 else 0;
    if (op + 1 + last_lit_overhead + last_lit_len > dst.len) {
        return errors.CompressionError.DstCapacityTooSmall;
    }

    if (last_lit_len >= 15) {
        dst[op] = 15 << constants.ML_BITS;
        op += 1;
        op += bitstream.encodeVariableLength(dst[op..], last_lit_len - 15);
    } else {
        dst[op] = @as(u8, @truncate(last_lit_len)) << constants.ML_BITS;
        op += 1;
    }

    if (last_lit_len > 0) {
        @memcpy(dst[op..][0..last_lit_len], src[anchor..][0..last_lit_len]);
        op += last_lit_len;
    }

    return op;
}

test "compressFast on repetitive input" {
    const input = "Hello Hello Hello Hello Hello Hello Hello Hello!";
    var out: [128]u8 = undefined;
    const compressed_len = try compressFast(input, &out, 1, null);
    try std.testing.expect(compressed_len < input.len);
}
