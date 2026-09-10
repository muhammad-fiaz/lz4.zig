//! High-performance memory copying and match reproduction utilities.

const std = @import("std");

/// Copies non-overlapping or distinct-region memory using 8-byte steps where possible.
pub inline fn wildCopy8(dst: []u8, src: []const u8, len: usize) void {
    std.debug.assert(dst.len >= len);
    std.debug.assert(src.len >= len);

    var i: usize = 0;
    while (i + 8 <= len) : (i += 8) {
        @memcpy(dst[i..][0..8], src[i..][0..8]);
    }
    while (i < len) : (i += 1) {
        dst[i] = src[i];
    }
}

/// Copies match bytes from earlier in the buffer (`dst_index - offset`) into `dst[dst_index..]`.
/// Correctly handles the LZ4 overlap case where `match_len > offset` (e.g. repeated bytes).
pub inline fn copyMatch(
    buffer: []u8,
    dst_start: usize,
    offset: usize,
    match_len: usize,
) void {
    std.debug.assert(offset > 0);
    std.debug.assert(dst_start >= offset);
    std.debug.assert(dst_start + match_len <= buffer.len);

    const match_start = dst_start - offset;

    // Fast path: if offset is 1, it's run-length byte repetition.
    if (offset == 1) {
        const byte = buffer[match_start];
        @memset(buffer[dst_start..][0..match_len], byte);
        return;
    }

    // Non-overlapping fast path: match is completely before destination.
    if (offset >= match_len) {
        @memcpy(buffer[dst_start..][0..match_len], buffer[match_start..][0..match_len]);
        return;
    }

    // Overlapping match: copy byte-by-byte so previously copied bytes can be read again.
    var i: usize = 0;
    while (i < match_len) : (i += 1) {
        buffer[dst_start + i] = buffer[match_start + i];
    }
}

/// Copies match bytes when the match starts within an external dictionary.
pub fn copyMatchFromDict(
    buffer: []u8,
    dst_start: usize,
    dict: []const u8,
    dict_offset: usize,
    match_len: usize,
) void {
    std.debug.assert(dst_start + match_len <= buffer.len);
    std.debug.assert(dict_offset <= dict.len);

    const dict_match_start = dict.len - dict_offset;
    const available_in_dict = dict.len - dict_match_start;

    if (match_len <= available_in_dict) {
        @memcpy(buffer[dst_start..][0..match_len], dict[dict_match_start..][0..match_len]);
    } else {
        // Match crosses from external dictionary into destination buffer prefix
        @memcpy(buffer[dst_start..][0..available_in_dict], dict[dict_match_start..][0..available_in_dict]);
        const rem = match_len - available_in_dict;
        // The remaining bytes come from the start of the current destination buffer
        var i: usize = 0;
        while (i < rem) : (i += 1) {
            buffer[dst_start + available_in_dict + i] = buffer[i];
        }
    }
}

test "copyMatch non-overlapping and overlapping" {
    var buf: [32]u8 = undefined;
    @memset(&buf, 0);

    // Write initial literals: "ABCD"
    @memcpy(buf[0..4], "ABCD");

    // Copy non-overlapping: offset=4, len=4 -> "ABCD"
    copyMatch(&buf, 4, 4, 4);
    try std.testing.expectEqualStrings("ABCDABCD", buf[0..8]);

    // Copy offset=1, len=4 -> "DDDD"
    copyMatch(&buf, 8, 1, 4);
    try std.testing.expectEqualStrings("ABCDABCDDDDD", buf[0..12]);

    // Copy overlapping: offset=2, len=6 at index 12 -> copies "DDDDDD"
    copyMatch(&buf, 12, 2, 6);
    try std.testing.expectEqualStrings("ABCDABCDDDDDDDDDDD", buf[0..18]);
}
