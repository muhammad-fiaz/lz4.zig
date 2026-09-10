//! Dictionary-based LZ4 block compression.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const bitstream = @import("../utils/bitstream.zig");
const match_finder = @import("match_finder.zig");
const tables = @import("../internal/tables.zig");
const options_mod = @import("../options.zig");
const BlockCompressionOptions = options_mod.BlockCompressionOptions;

/// Compresses `src` into `dst` using a dictionary for match references.
pub fn compressUsingDict(
    src: []const u8,
    dst: []u8,
    dict: []const u8,
    options: BlockCompressionOptions,
) errors.CompressionError!usize {
    _ = options;
    if (src.len > constants.MAX_INPUT_SIZE) {
        return errors.CompressionError.InputTooLarge;
    }

    // Usable dictionary is at most past 64 KB
    const dict_window = if (dict.len > constants.MAX_DISTANCE)
        dict[dict.len - constants.MAX_DISTANCE ..]
    else
        dict;

    if (dict_window.len == 0) {
        const fast = @import("fast.zig");
        return fast.compressFast(src, dst, 1, null);
    }

    // Build hash table pre-populated with dictionary entries
    var table = tables.FastTable.init();
    if (dict_window.len >= 4) {
        var d_idx: usize = 0;
        const d_limit = dict_window.len - 4;
        while (d_idx <= d_limit) : (d_idx += 1) {
            const seq = endian.readU32Le(dict_window[d_idx..]);
            const h = match_finder.hash4(seq, constants.HASH_LOG_DEFAULT);
            // We encode dictionary positions with high bit or negative offset
            // Storing 1-based index into dictionary: [1 .. dict_window.len]
            table.table[h] = @as(u32, @truncate(d_idx + 1));
        }
    }

    var op: usize = 0;
    var ip: usize = 0;
    var anchor: usize = 0;

    const mflimit = if (src.len >= constants.MFLIMIT) src.len - constants.MFLIMIT else 0;
    const matchlimit = if (src.len >= constants.LASTLITERALS) src.len - constants.LASTLITERALS else 0;

    if (mflimit == 0) {
        // Source too small to hold a match
        const required = 1 + (if (src.len >= 15) (src.len - 15) / 255 + 1 else 0) + src.len;
        if (dst.len < required) return errors.CompressionError.DstCapacityTooSmall;

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

    while (ip < mflimit) {
        const seq = endian.readU32Le(src[ip..]);
        const h = match_finder.hash4(seq, constants.HASH_LOG_DEFAULT);
        const candidate_raw = table.table[h];

        // Update table with current source position (offset by dict_window.len + 1)
        table.table[h] = @as(u32, @truncate(dict_window.len + 1 + ip));

        if (candidate_raw == 0) {
            ip += 1;
            continue;
        }

        var match_len: usize = 0;
        var offset: usize = 0;

        if (candidate_raw <= dict_window.len) {
            // Candidate is in dictionary
            const d_pos = candidate_raw - 1;
            offset = ip + (dict_window.len - d_pos);
            if (offset > constants.MAX_DISTANCE) {
                ip += 1;
                continue;
            }

            if (endian.readU32Le(dict_window[d_pos..]) != seq) {
                ip += 1;
                continue;
            }

            // Count matching bytes in dict
            const d_avail = dict_window.len - d_pos;
            const common_in_dict = match_finder.countCommonBytes(
                src[ip..],
                dict_window[d_pos..],
                @min(d_avail, matchlimit - ip),
            );

            if (common_in_dict == d_avail and ip + common_in_dict < matchlimit) {
                // Match crossed from dictionary into source buffer
                const more = match_finder.countCommonBytes(
                    src[ip + common_in_dict ..],
                    src[0..],
                    matchlimit - (ip + common_in_dict),
                );
                match_len = common_in_dict + more;
            } else {
                match_len = common_in_dict;
            }
        } else {
            // Candidate is in current source buffer
            const s_pos = (candidate_raw - dict_window.len) - 1;
            if (ip <= s_pos) {
                ip += 1;
                continue;
            }
            offset = ip - s_pos;
            if (offset > constants.MAX_DISTANCE) {
                ip += 1;
                continue;
            }
            if (endian.readU32Le(src[s_pos..]) != seq) {
                ip += 1;
                continue;
            }
            match_len = match_finder.countCommonBytes(
                src[ip..],
                src[s_pos..],
                matchlimit - ip,
            );
        }

        if (match_len < constants.MINMATCH) {
            ip += 1;
            continue;
        }

        // Backward extension
        while (ip > anchor and offset > 1) {
            const prev_src_byte = src[ip - 1];
            const prev_match_byte = if (offset <= ip)
                src[ip - offset]
            else
                dict_window[dict_window.len - (offset - ip)];

            if (prev_src_byte == prev_match_byte) {
                ip -= 1;
                match_len += 1;
            } else break;
        }

        // Encode literals
        const lit_len = ip - anchor;
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
        endian.writeU16Le(dst[op..], @as(u16, @truncate(offset)));
        op += 2;

        // Encode match length
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

        ip += match_len;
        anchor = ip;
    }

    // Last literals
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

test "compressUsingDict with known dictionary" {
    const safe = @import("../decompress/safe.zig");

    const dict = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nServer: ZigLZ4\r\n\r\n";
    const body = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nServer: ZigLZ4\r\n\r\n<html><body>Hello!</body></html>";

    var comp: [256]u8 = undefined;
    const comp_len = try compressUsingDict(body, &comp, dict, .{});

    var decomp: [256]u8 = undefined;
    const decomp_len = try safe.decompressSafeWithDict(comp[0..comp_len], &decomp, dict);

    try std.testing.expectEqualStrings(body, decomp[0..decomp_len]);
}
