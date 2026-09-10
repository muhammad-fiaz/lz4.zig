//! Stateful block streaming decompressor for continuous chunks with shared history.

const std = @import("std");
const Allocator = std.mem.Allocator;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const safe = @import("safe.zig");

/// Stateful block stream decompressor maintaining up to 64 KB of sliding history.
pub const BlockDecompressStream = struct {
    history_buf: []u8,
    history_len: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Allocator.Error!BlockDecompressStream {
        const buf = try allocator.alloc(u8, constants.MAX_DISTANCE);
        return .{
            .history_buf = buf,
            .history_len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BlockDecompressStream) void {
        self.allocator.free(self.history_buf);
    }

    pub fn reset(self: *BlockDecompressStream) void {
        self.history_len = 0;
    }

    /// Decompresses consecutive compressed chunk `src` into `dst` referencing previous stream history.
    pub fn decompressContinue(
        self: *BlockDecompressStream,
        src: []const u8,
        dst: []u8,
    ) errors.DecompressionError!usize {
        const dict = self.history_buf[0..self.history_len];
        const decomp_len = try safe.decompressSafeWithDict(src, dst, dict);
        const produced = dst[0..decomp_len];

        // Update sliding history with newly decompressed bytes
        if (produced.len >= self.history_buf.len) {
            @memcpy(self.history_buf, produced[produced.len - self.history_buf.len ..]);
            self.history_len = self.history_buf.len;
        } else {
            const avail = self.history_buf.len - self.history_len;
            if (produced.len <= avail) {
                @memcpy(self.history_buf[self.history_len..][0..produced.len], produced);
                self.history_len += produced.len;
            } else {
                const shift = produced.len - avail;
                std.mem.copyForwards(u8, self.history_buf[0 .. self.history_len - shift], self.history_buf[shift..self.history_len]);
                @memcpy(self.history_buf[self.history_len - shift ..][0..produced.len], produced);
                self.history_len = self.history_buf.len;
            }
        }

        return decomp_len;
    }
};

test "BlockCompressStream and BlockDecompressStream roundtrip" {
    const comp_stream_mod = @import("../compress/streaming.zig");

    var c_stream = try comp_stream_mod.BlockCompressStream.init(std.testing.allocator, .{});
    defer c_stream.deinit();

    var d_stream = try BlockDecompressStream.init(std.testing.allocator);
    defer d_stream.deinit();

    const chunk1 = "Chunk 1: The quick brown fox jumps over the lazy dog. ";
    const chunk2 = "Chunk 2: The quick brown fox jumps over the lazy dog again!";

    var c1: [128]u8 = undefined;
    var c2: [128]u8 = undefined;

    const len1 = try c_stream.compressContinue(chunk1, &c1);
    const len2 = try c_stream.compressContinue(chunk2, &c2);

    var d1: [128]u8 = undefined;
    var d2: [128]u8 = undefined;

    const dlen1 = try d_stream.decompressContinue(c1[0..len1], &d1);
    const dlen2 = try d_stream.decompressContinue(c2[0..len2], &d2);

    try std.testing.expectEqualStrings(chunk1, d1[0..dlen1]);
    try std.testing.expectEqualStrings(chunk2, d2[0..dlen2]);
}
