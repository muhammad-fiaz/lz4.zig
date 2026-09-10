//! Native Zig implementation of xxHash-32 algorithm reusing std.hash.XxHash32.
//!
//! xxHash-32 is the canonical checksum used for LZ4 frame headers,
//! block checksums, and content checksums.
//! Conforms to the official xxHash-32 specification.

const std = @import("std");

pub const PRIME32_1: u32 = 2654435761;
pub const PRIME32_2: u32 = 2246822519;
pub const PRIME32_3: u32 = 3266489917;
pub const PRIME32_4: u32 = 668265263;
pub const PRIME32_5: u32 = 374761393;

/// Compute xxHash-32 checksum in a single shot using std.hash.XxHash32.
pub inline fn hash(input: []const u8, seed: u32) u32 {
    return std.hash.XxHash32.hash(seed, input);
}

/// Stateful xxHash-32 accumulator for streaming checksums, wrapping std.hash.XxHash32.
pub const XxHash32 = struct {
    inner: std.hash.XxHash32,

    pub fn init(seed: u32) XxHash32 {
        return .{
            .inner = std.hash.XxHash32.init(seed),
        };
    }

    pub fn reset(self: *XxHash32, seed: u32) void {
        self.inner = std.hash.XxHash32.init(seed);
    }

    pub fn update(self: *XxHash32, data: []const u8) void {
        self.inner.update(data);
    }

    pub fn digest(self: *const XxHash32) u32 {
        var copy = self.inner;
        return copy.final();
    }
};

test "xxHash32 empty input" {
    // Official xxHash-32 sanity check for 0-length input
    const empty = "";
    try std.testing.expectEqual(@as(u32, 0x02CC5D05), hash(empty, 0));

    var s = XxHash32.init(0);
    s.update(empty);
    try std.testing.expectEqual(@as(u32, 0x02CC5D05), s.digest());
}

test "xxHash32 streaming matches one-shot across various lengths" {
    var prng = std.Random.DefaultPrng.init(0x12345678);
    const random = prng.random();

    var buffer: [256]u8 = undefined;
    random.bytes(&buffer);

    for (0..buffer.len) |len| {
        const slice = buffer[0..len];
        const seed = @as(u32, @truncate(len * 31));
        const one_shot = hash(slice, seed);

        var state = XxHash32.init(seed);
        // Chunked updates (1 byte, 3 bytes, remainder)
        if (slice.len > 5) {
            state.update(slice[0..2]);
            state.update(slice[2..5]);
            state.update(slice[5..]);
        } else {
            state.update(slice);
        }
        try std.testing.expectEqual(one_shot, state.digest());
    }
}
