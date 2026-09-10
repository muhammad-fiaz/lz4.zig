//! Streaming frame encoder and decoder for incremental processing.

const std = @import("std");
const Allocator = std.mem.Allocator;
const constants = @import("../internal/constants.zig");
const errors = @import("../errors.zig");
const endian = @import("../utils/endian.zig");
const checksum = @import("../utils/checksum.zig");
const options_mod = @import("../options.zig");
const FrameOptions = options_mod.FrameOptions;
const BlockCompressionOptions = options_mod.BlockCompressionOptions;
const descriptor_mod = @import("descriptor.zig");
const FrameDescriptor = descriptor_mod.FrameDescriptor;
const header_mod = @import("header.zig");
const FrameHeader = header_mod.FrameHeader;
const block_mod = @import("block.zig");
const BlockHeader = block_mod.BlockHeader;
const comp_block = @import("../compress/block.zig");
const safe_decomp = @import("../decompress/safe.zig");

/// Incremental streaming frame encoder.
pub const FrameCompressStream = struct {
    allocator: Allocator,
    options: FrameOptions,
    descriptor: FrameDescriptor,
    content_hasher: checksum.XxHash32,
    block_buffer: []u8,
    block_buffered: usize,
    header_written: bool,
    finished: bool,

    pub fn init(allocator: Allocator, options: FrameOptions) Allocator.Error!FrameCompressStream {
        const block_size = options.blockMaxSize.toBytes();
        const buf = try allocator.alloc(u8, block_size);
        errdefer allocator.free(buf);

        return .{
            .allocator = allocator,
            .options = options,
            .descriptor = .{
                .block_mode = options.blockMode,
                .block_checksum = options.blockChecksum,
                .content_checksum = options.contentChecksum,
                .content_size = options.contentSize,
                .dict_id = options.dictId,
                .block_max_size = options.blockMaxSize,
            },
            .content_hasher = checksum.XxHash32.init(0),
            .block_buffer = buf,
            .block_buffered = 0,
            .header_written = false,
            .finished = false,
        };
    }

    pub fn deinit(self: *FrameCompressStream) void {
        self.allocator.free(self.block_buffer);
    }

    /// Writes the frame header into `dst`. Must be called once before data is compressed.
    pub fn writeHeader(self: *FrameCompressStream, dst: []u8) errors.FrameError!usize {
        if (self.header_written) return 0;
        const header = FrameHeader{ .descriptor = self.descriptor };
        const written = try header.encode(dst);
        self.header_written = true;
        return written;
    }

    /// Incrementally updates the frame with incoming `src` bytes, emitting full compressed
    /// blocks into `dst` as they fill `blockMaxSize`.
    pub fn update(
        self: *FrameCompressStream,
        src: []const u8,
        dst: []u8,
    ) errors.FrameError!usize {
        std.debug.assert(self.header_written);
        if (self.finished) return 0;

        if (self.options.contentChecksum) {
            self.content_hasher.update(src);
        }

        var op: usize = 0;
        var ip: usize = 0;
        const block_max = self.block_buffer.len;

        while (ip < src.len) {
            const avail_in_block = block_max - self.block_buffered;
            const to_copy = @min(src.len - ip, avail_in_block);

            @memcpy(self.block_buffer[self.block_buffered..][0..to_copy], src[ip..][0..to_copy]);
            self.block_buffered += to_copy;
            ip += to_copy;

            if (self.block_buffered == block_max) {
                const written = try self.flushBlock(dst[op..]);
                op += written;
            }
        }

        return op;
    }

    fn flushBlock(self: *FrameCompressStream, dst: []u8) errors.FrameError!usize {
        if (self.block_buffered == 0) return 0;

        const chunk = self.block_buffer[0..self.block_buffered];
        self.block_buffered = 0;

        if (dst.len < 4) return errors.FrameError.DstCapacityTooSmall;
        var op: usize = 4; // reserve for block header

        const block_comp_opts = BlockCompressionOptions{
            .level = self.options.compressionLevel,
            .favorDecSpeed = self.options.favorDecSpeed,
        };

        var compressed = false;
        var payload_len: usize = chunk.len;

        if (chunk.len >= constants.MIN_LENGTH) {
            const worst_case = comp_block.compressBound(chunk.len);
            if (dst.len >= 4 + worst_case) {
                const comp_len = comp_block.compressBlock(chunk, dst[4..][0..worst_case], block_comp_opts) catch 0;
                if (comp_len > 0 and comp_len < chunk.len) {
                    compressed = true;
                    payload_len = comp_len;
                    op += comp_len;
                }
            }
        }

        if (!compressed) {
            if (dst.len < 4 + chunk.len) return errors.FrameError.DstCapacityTooSmall;
            @memcpy(dst[4..][0..chunk.len], chunk);
            op += chunk.len;
        }

        try BlockHeader.encode(dst[0..4], payload_len, !compressed);

        if (self.options.blockChecksum) {
            if (op + 4 > dst.len) return errors.FrameError.DstCapacityTooSmall;
            const b_check = block_mod.computeBlockChecksum(dst[4..op]);
            endian.writeU32Le(dst[op..], b_check);
            op += 4;
        }

        return op;
    }

    /// Flushes any pending buffered data, writes EndMark and optional Content Checksum.
    pub fn finish(self: *FrameCompressStream, dst: []u8) errors.FrameError!usize {
        std.debug.assert(self.header_written);
        if (self.finished) return 0;

        var op: usize = 0;
        if (self.block_buffered > 0) {
            const flushed = try self.flushBlock(dst[op..]);
            op += flushed;
        }

        // Write EndMark
        const end_mark_len = try block_mod.writeEndMark(dst[op..]);
        op += end_mark_len;

        // Optional Content Checksum
        if (self.options.contentChecksum) {
            if (op + 4 > dst.len) return errors.FrameError.DstCapacityTooSmall;
            const final_digest = self.content_hasher.digest();
            endian.writeU32Le(dst[op..], final_digest);
            op += 4;
        }

        self.finished = true;
        return op;
    }
};

test "FrameCompressStream streaming workflow" {
    const reader_mod = @import("reader.zig");

    var stream = try FrameCompressStream.init(std.testing.allocator, .{
        .blockMaxSize = .max64KB,
        .contentChecksum = true,
    });
    defer stream.deinit();

    var comp_buffer: [1024]u8 = undefined;
    var written: usize = 0;

    written += try stream.writeHeader(comp_buffer[written..]);
    written += try stream.update("Hello, ", comp_buffer[written..]);
    written += try stream.update("Streaming ", comp_buffer[written..]);
    written += try stream.update("LZ4 Frame!", comp_buffer[written..]);
    written += try stream.finish(comp_buffer[written..]);

    var decomp_buffer: [256]u8 = undefined;
    const decomp_len = try reader_mod.decompressFrame(comp_buffer[0..written], &decomp_buffer);

    try std.testing.expectEqualStrings("Hello, Streaming LZ4 Frame!", decomp_buffer[0..decomp_len]);
}
