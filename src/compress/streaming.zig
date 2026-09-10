//! Stateful block streaming compressor for continuous data chunks with shared history.

const std = @import("std");
const Allocator = std.mem.Allocator;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const dictionary = @import("dictionary.zig");
const options_mod = @import("../options.zig");
const BlockCompressionOptions = options_mod.BlockCompressionOptions;

/// Stateful block stream compressor maintaining up to 64 KB of sliding history.
pub const BlockCompressStream = struct {
    history_buf: []u8,
    history_len: usize,
    allocator: Allocator,
    options: BlockCompressionOptions,

    pub fn init(allocator: Allocator, options: BlockCompressionOptions) Allocator.Error!BlockCompressStream {
        const buf = try allocator.alloc(u8, constants.MAX_DISTANCE);
        return .{
            .history_buf = buf,
            .history_len = 0,
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *BlockCompressStream) void {
        self.allocator.free(self.history_buf);
    }

    pub fn reset(self: *BlockCompressStream) void {
        self.history_len = 0;
    }

    /// Compresses `src` chunk into `dst`, referencing preceding chunks in the stream.
    pub fn compressContinue(
        self: *BlockCompressStream,
        src: []const u8,
        dst: []u8,
    ) errors.CompressionError!usize {
        const dict = self.history_buf[0..self.history_len];
        const written = try dictionary.compressUsingDict(src, dst, dict, self.options);

        // Update sliding history with bytes from `src`
        if (src.len >= self.history_buf.len) {
            @memcpy(self.history_buf, src[src.len - self.history_buf.len ..]);
            self.history_len = self.history_buf.len;
        } else {
            const avail = self.history_buf.len - self.history_len;
            if (src.len <= avail) {
                @memcpy(self.history_buf[self.history_len..][0..src.len], src);
                self.history_len += src.len;
            } else {
                const shift = src.len - avail;
                std.mem.copyForwards(u8, self.history_buf[0 .. self.history_len - shift], self.history_buf[shift..self.history_len]);
                @memcpy(self.history_buf[self.history_len - shift ..][0..src.len], src);
                self.history_len = self.history_buf.len;
            }
        }

        return written;
    }
};

test "BlockCompressStream multi-chunk compression" {
    var stream = try BlockCompressStream.init(std.testing.allocator, .{});
    defer stream.deinit();

    const chunk1 = "Hello from the first chunk of streaming block data! ";
    const chunk2 = "Hello from the first chunk of streaming block data! Repeated pattern!";

    var out1: [128]u8 = undefined;
    var out2: [128]u8 = undefined;

    const len1 = try stream.compressContinue(chunk1, &out1);
    const len2 = try stream.compressContinue(chunk2, &out2);

    try std.testing.expect(len1 > 0);
    try std.testing.expect(len2 > 0);
}
