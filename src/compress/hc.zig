//! Native LZ4 High Compression (HC) block compressor.
//!
//! Uses hash chains and configurable search depth (levels 2..12) with
//! lazy match evaluation to achieve significantly higher compression ratios.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bitstream = @import("../utils/bitstream.zig");
const match_finder = @import("match_finder.zig");
const tables = @import("../internal/tables.zig");

pub const HcParams = struct {
    max_nb_searches: usize,
    target_length: usize,
};

pub fn getHcParams(level: i32) HcParams {
    const cl = @min(@max(level, constants.HC_CLEVEL_MIN), constants.HC_CLEVEL_MAX);
    return switch (cl) {
        2 => .{ .max_nb_searches = 2, .target_length = 16 },
        3 => .{ .max_nb_searches = 4, .target_length = 16 },
        4 => .{ .max_nb_searches = 8, .target_length = 16 },
        5 => .{ .max_nb_searches = 16, .target_length = 16 },
        6 => .{ .max_nb_searches = 32, .target_length = 16 },
        7 => .{ .max_nb_searches = 64, .target_length = 16 },
        8 => .{ .max_nb_searches = 128, .target_length = 16 },
        9 => .{ .max_nb_searches = 256, .target_length = 16 },
        10 => .{ .max_nb_searches = 512, .target_length = 64 },
        11 => .{ .max_nb_searches = 1024, .target_length = 128 },
        12 => .{ .max_nb_searches = 4096, .target_length = 256 },
        else => .{ .max_nb_searches = 256, .target_length = 16 },
    };
}

const Match = struct {
    pos: usize,
    len: usize,
};

fn findLongestMatch(
    src: []const u8,
    ip: usize,
    matchlimit: usize,
    table: *tables.HcTable,
    params: HcParams,
) ?Match {
    const seq = endian.readU32Le(src[ip..]);
    const h = match_finder.hash4(seq, constants.HASH_LOG_HC);

    var candidate = table.hash_table[h];
    // Insert current position into chain
    table.chain_table[ip & 0xFFFF] = @as(u16, @truncate(candidate));
    table.hash_table[h] = @as(u32, @truncate(ip));

    var best_pos: usize = 0;
    var best_len: usize = 0;
    var nb_searches: usize = 0;

    while (candidate > 0 and nb_searches < params.max_nb_searches) : (nb_searches += 1) {
        if (ip <= candidate or (ip - candidate) > constants.MAX_DISTANCE) break;

        if (endian.readU32Le(src[candidate..]) == seq) {
            const common = match_finder.countCommonBytes(
                src[ip + constants.MINMATCH ..],
                src[candidate + constants.MINMATCH ..],
                matchlimit - (ip + constants.MINMATCH),
            );
            const m_len = constants.MINMATCH + common;
            if (m_len > best_len) {
                best_len = m_len;
                best_pos = candidate;
                if (m_len >= params.target_length) break;
            }
        }

        const next_candidate = table.chain_table[candidate & 0xFFFF];
        if (next_candidate >= candidate) break;
        candidate = next_candidate;
    }

    if (best_len >= constants.MINMATCH) {
        return Match{ .pos = best_pos, .len = best_len };
    }
    return null;
}

/// Compress `src` into `dst` using high-compression (HC) mode.
pub fn compressHc(
    src: []const u8,
    dst: []u8,
    level: i32,
    table: ?*tables.HcTable,
) errors.CompressionError!usize {
    if (src.len > constants.MAX_INPUT_SIZE) {
        return errors.CompressionError.InputTooLarge;
    }

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

    var local_table: tables.HcTable = undefined;
    const hc_table = if (table) |t| t else blk: {
        local_table = tables.HcTable.init();
        break :blk &local_table;
    };
    hc_table.clear();

    const params = getHcParams(level);

    var op: usize = 0;
    var ip: usize = 0;
    var anchor: usize = 0;

    const mflimit = src.len - constants.MFLIMIT;
    const matchlimit = src.len - constants.LASTLITERALS;

    while (ip < mflimit) {
        const match0 = findLongestMatch(src, ip, matchlimit, hc_table, params);
        if (match0 == null) {
            ip += 1;
            continue;
        }

        var selected_match = match0.?;
        var selected_ip = ip;

        // Lazy match evaluation: check ip + 1
        if (ip + 1 < mflimit) {
            const match1 = findLongestMatch(src, ip + 1, matchlimit, hc_table, params);
            if (match1) |m1| {
                if (m1.len > selected_match.len + 1) {
                    selected_match = m1;
                    selected_ip = ip + 1;
                    ip = selected_ip;
                }
            }
        }

        // Backward extension
        var m_pos = selected_match.pos;
        while (selected_ip > anchor and m_pos > 0 and src[selected_ip - 1] == src[m_pos - 1]) {
            selected_ip -= 1;
            m_pos -= 1;
        }

        // Encode literals
        const lit_len = selected_ip - anchor;
        const token_pos = op;
        op += 1;

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

        // Encode offset
        const offset = @as(u16, @truncate(selected_ip - m_pos));
        std.debug.assert(offset > 0);
        endian.writeU16Le(dst[op..], offset);
        op += 2;

        // Encode match length
        const match_len = selected_match.len;
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

        ip = selected_ip + match_len;
        anchor = ip;
    }

    // Encode remaining literals
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

test "compressHc and roundtrip" {
    const safe = @import("../decompress/safe.zig");

    const text = "To be, or not to be, that is the question: Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune, or to take arms against a sea of troubles and by opposing end them.";
    var comp: [512]u8 = undefined;
    const comp_len = try compressHc(text, &comp, 9, null);

    var decomp: [512]u8 = undefined;
    const decomp_len = try safe.decompressSafe(comp[0..comp_len], &decomp);

    try std.testing.expectEqualStrings(text, decomp[0..decomp_len]);
}
