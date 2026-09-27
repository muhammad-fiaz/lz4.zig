//! lz4.zig: High-performance, memory-safe, native Zig implementation
//! of the LZ4 lossless compression algorithm and framing specification
//! (block format, frame format, streaming pipelines, and xxHash-32 checksums).
//!
//! Standard upstream reference commit: https://github.com/lz4/lz4/tree/48bfbfe351c5d6ea87d4af5557705e87755844e0
//! Minimum supported Zig version: 0.17.0.
//! License: MIT. Copyright (c) 2026 muhammad-fiaz.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

// Submodules

pub const version_mod = @import("version.zig");
pub const errors = @import("errors.zig");
pub const options = @import("options.zig");

pub const utils = struct {
    pub const bounds = @import("utils/bounds.zig");
    pub const endian = @import("utils/endian.zig");
    pub const bitstream = @import("utils/bitstream.zig");
    pub const checksum = @import("utils/checksum.zig");
    pub const memory = @import("utils/memory.zig");
};

pub const internal = struct {
    pub const constants = @import("internal/constants.zig");
    pub const tables = @import("internal/tables.zig");
    pub const validation = @import("internal/validation.zig");
};

pub const compress_mod = struct {
    pub const match_finder = @import("compress/match_finder.zig");
    pub const fast = @import("compress/fast.zig");
    pub const hc = @import("compress/hc.zig");
    pub const dictionary = @import("compress/dictionary.zig");
    pub const streaming = @import("compress/streaming.zig");
    pub const block = @import("compress/block.zig");
};

pub const decompress_mod = struct {
    pub const safe = @import("decompress/safe.zig");
    pub const partial = @import("decompress/partial.zig");
    pub const dictionary = @import("decompress/dictionary.zig");
    pub const streaming = @import("decompress/streaming.zig");
    pub const block = @import("decompress/block.zig");
};

pub const frame = struct {
    pub const header = @import("frame/header.zig");
    pub const descriptor = @import("frame/descriptor.zig");
    pub const block = @import("frame/block.zig");
    pub const reader = @import("frame/reader.zig");
    pub const writer = @import("frame/writer.zig");
    pub const streaming = @import("frame/streaming.zig");
    pub const skippable = @import("frame/skippable.zig");
};

pub const io = struct {
    pub const reader = @import("io/reader.zig");
    pub const writer = @import("io/writer.zig");
    pub const file = @import("io/file.zig");
};

// Public Types & Options

pub const Version = version_mod.Version;
pub const CompressionOptions = options.CompressionOptions;
pub const DecompressionOptions = options.DecompressionOptions;
pub const BlockMode = options.BlockMode;
pub const BlockMaxSize = options.BlockMaxSize;
pub const BlockCompressionOptions = options.BlockCompressionOptions;
pub const FrameOptions = options.FrameOptions;

pub const FrameDescriptor = frame.descriptor.FrameDescriptor;
pub const FrameHeader = frame.header.FrameHeader;
pub const BlockHeader = frame.block.BlockHeader;

pub const FastTable = internal.tables.FastTable;
pub const HcTable = internal.tables.HcTable;
pub const XxHash32 = utils.checksum.XxHash32;

pub const BlockCompressStream = compress_mod.streaming.BlockCompressStream;
pub const BlockDecompressStream = decompress_mod.streaming.BlockDecompressStream;
pub const FrameCompressStream = frame.streaming.FrameCompressStream;

// Public Errors

pub const CompressionError = errors.CompressionError;
pub const DecompressionError = errors.DecompressionError;
pub const FrameError = errors.FrameError;
pub const Error = errors.Error;

// Metadata & Constants

pub const version = version_mod.version;
pub const versionString = version_mod.versionString;
pub const versionNumber = version_mod.versionNumber;

pub const FRAME_MAGIC = internal.constants.FRAME_MAGIC;
pub const LEGACY_MAGIC = internal.constants.LEGACY_MAGIC;
pub const SKIPPABLE_MAGIC_MIN = internal.constants.SKIPPABLE_MAGIC_MIN;
pub const SKIPPABLE_MAGIC_MAX = internal.constants.SKIPPABLE_MAGIC_MAX;
pub const END_MARK = internal.constants.END_MARK;

pub const MINMATCH = internal.constants.MINMATCH;
pub const MAX_DISTANCE = internal.constants.MAX_DISTANCE;
pub const MAX_INPUT_SIZE = internal.constants.MAX_INPUT_SIZE;

// High-Level One-Shot Compression & Decompression

/// Upper bound calculation for worst-case compressed buffer capacity.
pub const compressBound = utils.bounds.compressBound;
pub const compressBlockBound = utils.bounds.compressBlockBound;
pub const compressFrameBound = utils.bounds.compressFrameBound;

/// Upper bound calculation alias.
pub fn maxCompressedSize(src_size: usize) usize {
    return utils.bounds.compressFrameBound(src_size, .{});
}

/// Flexible one-shot compression:
/// - If `arg1` is `Allocator`: allocates and returns `![]u8` containing a standard LZ4 frame.
/// - If `arg1` is `[]const u8` and `arg2` is `[]u8`: compresses into caller-allocated `arg2` and returns `!usize`.
pub fn compress(arg1: anytype, arg2: anytype) !if (@TypeOf(arg1) == Allocator) []u8 else usize {
    if (@TypeOf(arg1) == Allocator) {
        return compressWithOptions(arg1, arg2, .{});
    } else {
        return compress_mod.block.compress(arg1, arg2);
    }
}

/// One-shot compression with `CompressionOptions` returning a newly allocated slice.
pub fn compressWithOptions(allocator: Allocator, src: []const u8, opts: CompressionOptions) ![]u8 {
    const f_opts: FrameOptions = .{
        .blockMaxSize = opts.blockMaxSize,
        .blockMode = opts.blockMode,
        .contentChecksum = opts.contentChecksum,
        .blockChecksum = opts.blockChecksum,
        .contentSize = opts.contentSize orelse src.len,
        .dictId = opts.dictId,
        .compressionLevel = opts.level,
        .favorDecSpeed = opts.favorDecSpeed,
        .autoFlush = opts.autoFlush,
    };
    return frame.writer.compressFrameAlloc(allocator, src, f_opts);
}

/// Compresses `src` into caller-provided `dst` buffer (frame format).
pub fn compressInto(src: []const u8, dst: []u8) !usize {
    return frame.writer.compressFrame(src, dst, .{});
}

/// Flexible one-shot decompression:
/// - If `arg1` is `Allocator`: parses frame or raw block, allocates, and returns `![]u8`.
/// - If `arg1` is `[]const u8` and `arg2` is `[]u8`: decompresses into caller-allocated `arg2` and returns `!usize`.
pub fn decompress(arg1: anytype, arg2: anytype) !if (@TypeOf(arg1) == Allocator) []u8 else usize {
    if (@TypeOf(arg1) == Allocator) {
        return decompressWithOptions(arg1, arg2, .{});
    } else {
        return decompressInto(arg1, arg2);
    }
}

/// One-shot decompression with `DecompressionOptions` returning a newly allocated slice.
pub fn decompressWithOptions(allocator: Allocator, src: []const u8, opts: DecompressionOptions) ![]u8 {
    if (src.len >= 4 and std.mem.readInt(u32, src[0..4], .little) == FRAME_MAGIC) {
        return frame.reader.decompressFrameAlloc(allocator, src, opts.maxOutputSize);
    }
    return decompress_mod.block.decompressAlloc(allocator, src, opts.maxOutputSize);
}

/// Decompresses `src` into caller-provided `dst` buffer.
/// Automatically handles standard LZ4 frames or raw blocks.
pub fn decompressInto(src: []const u8, dst: []u8) !usize {
    if (src.len >= 4 and std.mem.readInt(u32, src[0..4], .little) == FRAME_MAGIC) {
        return frame.reader.decompressFrame(src, dst);
    }
    return decompress_mod.block.decompress(src, dst);
}

// Reusable Contexts

/// Reusable compressor maintaining configuration and optional dictionary across operations.
pub const Compressor = struct {
    allocator: Allocator,
    options: CompressionOptions,
    dict: ?[]const u8 = null,

    pub fn init(allocator: Allocator, opts: CompressionOptions) Compressor {
        return .{
            .allocator = allocator,
            .options = opts,
            .dict = opts.customDictionary,
        };
    }

    pub fn deinit(self: *Compressor) void {
        _ = self;
    }

    pub fn reset(self: *Compressor, opts: CompressionOptions) void {
        self.options = opts;
        self.dict = opts.customDictionary;
    }

    pub fn attachDictionary(self: *Compressor, dict: []const u8) void {
        self.dict = dict;
    }

    pub fn compress(self: *Compressor, src: []const u8) ![]u8 {
        var opts = self.options;
        opts.customDictionary = self.dict;
        return compressWithOptions(self.allocator, src, opts);
    }

    pub fn compressInto(self: *Compressor, src: []const u8, dst: []u8) !usize {
        const f_opts: FrameOptions = .{
            .blockMaxSize = self.options.blockMaxSize,
            .blockMode = self.options.blockMode,
            .contentChecksum = self.options.contentChecksum,
            .blockChecksum = self.options.blockChecksum,
            .contentSize = src.len,
            .dictId = self.options.dictId,
            .compressionLevel = self.options.level,
            .favorDecSpeed = self.options.favorDecSpeed,
        };
        return frame.writer.compressFrame(src, dst, f_opts);
    }
};

/// Reusable decompressor maintaining configuration and optional dictionary across operations.
pub const Decompressor = struct {
    allocator: Allocator,
    options: DecompressionOptions,
    dict: ?[]const u8 = null,

    pub fn init(allocator: Allocator, opts: DecompressionOptions) Decompressor {
        return .{
            .allocator = allocator,
            .options = opts,
            .dict = opts.customDictionary,
        };
    }

    pub fn deinit(self: *Decompressor) void {
        _ = self;
    }

    pub fn reset(self: *Decompressor, opts: DecompressionOptions) void {
        self.options = opts;
        self.dict = opts.customDictionary;
    }

    pub fn attachDictionary(self: *Decompressor, dict: []const u8) void {
        self.dict = dict;
    }

    pub fn decompress(self: *Decompressor, src: []const u8) ![]u8 {
        var opts = self.options;
        opts.customDictionary = self.dict;
        return decompressWithOptions(self.allocator, src, opts);
    }

    pub fn decompressInto(self: *Decompressor, src: []const u8, dst: []u8) !usize {
        _ = self;
        if (src.len >= 4 and std.mem.readInt(u32, src[0..4], .little) == FRAME_MAGIC) {
            return frame.reader.decompressFrame(src, dst);
        }
        return decompress_mod.block.decompress(src, dst);
    }
};

/// Chunked streaming compressor emitting frame-compliant blocks.
pub const StreamingCompressor = struct {
    allocator: Allocator,
    stream: FrameCompressStream,
    header_written: bool = false,

    pub fn init(allocator: Allocator, opts: CompressionOptions) !StreamingCompressor {
        const f_opts: FrameOptions = .{
            .blockMaxSize = opts.blockMaxSize,
            .blockMode = opts.blockMode,
            .contentChecksum = opts.contentChecksum,
            .blockChecksum = opts.blockChecksum,
            .contentSize = opts.contentSize,
            .dictId = opts.dictId,
            .compressionLevel = opts.level,
            .favorDecSpeed = opts.favorDecSpeed,
        };
        return .{
            .allocator = allocator,
            .stream = try FrameCompressStream.init(allocator, f_opts),
            .header_written = false,
        };
    }

    pub fn deinit(self: *StreamingCompressor) void {
        self.stream.deinit();
    }

    pub fn write(self: *StreamingCompressor, chunk: []const u8, w: *Writer) !void {
        const worst_case = utils.bounds.compressFrameBound(chunk.len + 65536, .{});
        const out_buf = try self.allocator.alloc(u8, worst_case);
        defer self.allocator.free(out_buf);

        if (!self.header_written) {
            const h_len = try self.stream.writeHeader(out_buf);
            try w.writeAll(out_buf[0..h_len]);
            self.header_written = true;
        }

        const comp_len = try self.stream.update(chunk, out_buf);
        if (comp_len > 0) {
            try w.writeAll(out_buf[0..comp_len]);
        }
    }

    pub fn finish(self: *StreamingCompressor, w: *Writer) !void {
        const out_buf = try self.allocator.alloc(u8, 65536 + 1024);
        defer self.allocator.free(out_buf);

        if (!self.header_written) {
            const h_len = try self.stream.writeHeader(out_buf);
            try w.writeAll(out_buf[0..h_len]);
            self.header_written = true;
        }

        const fin_len = try self.stream.finish(out_buf);
        if (fin_len > 0) {
            try w.writeAll(out_buf[0..fin_len]);
        }
        try w.flush();
    }
};

/// Chunked streaming decompressor consuming input chunks incrementally.
pub const StreamingDecompressor = struct {
    allocator: Allocator,
    options: DecompressionOptions,
    in_buf: std.ArrayList(u8),
    out_buf: std.ArrayList(u8),
    finished: bool = false,

    pub fn init(allocator: Allocator, opts: DecompressionOptions) StreamingDecompressor {
        return .{
            .allocator = allocator,
            .options = opts,
            .in_buf = std.ArrayList(u8).empty,
            .out_buf = std.ArrayList(u8).empty,
            .finished = false,
        };
    }

    pub fn deinit(self: *StreamingDecompressor) void {
        self.in_buf.deinit(self.allocator);
        self.out_buf.deinit(self.allocator);
    }

    pub fn reset(self: *StreamingDecompressor) void {
        self.in_buf.clearRetainingCapacity();
        self.out_buf.clearRetainingCapacity();
        self.finished = false;
    }

    pub fn feed(self: *StreamingDecompressor, chunk: []const u8) !void {
        try self.in_buf.appendSlice(self.allocator, chunk);
    }

    pub fn read(self: *StreamingDecompressor, r: *Reader, w: *Writer) !usize {
        return decompressStream(self.allocator, r, w, self.options);
    }

    pub fn take(self: *StreamingDecompressor, dst: []u8) !usize {
        if (self.out_buf.items.len > 0) {
            const n = @min(dst.len, self.out_buf.items.len);
            @memcpy(dst[0..n], self.out_buf.items[0..n]);
            const rem = self.out_buf.items.len - n;
            if (rem > 0) {
                std.mem.copyForwards(u8, self.out_buf.items[0..rem], self.out_buf.items[n..]);
            }
            self.out_buf.items.len = rem;
            return n;
        }

        if (self.finished or self.in_buf.items.len == 0) return 0;

        const decomp = decompress(self.allocator, self.in_buf.items) catch |err| {
            if (err == error.SourceBufferExhausted) return 0;
            return err;
        };
        defer self.allocator.free(decomp);

        self.finished = true;
        try self.out_buf.appendSlice(self.allocator, decomp);

        const n = @min(dst.len, self.out_buf.items.len);
        @memcpy(dst[0..n], self.out_buf.items[0..n]);
        const rem = self.out_buf.items.len - n;
        if (rem > 0) {
            std.mem.copyForwards(u8, self.out_buf.items[0..rem], self.out_buf.items[n..]);
        }
        self.out_buf.items.len = rem;
        return n;
    }

    pub fn isFinished(self: *const StreamingDecompressor) bool {
        return self.finished and self.out_buf.items.len == 0;
    }
};

// Raw Block APIs (Low-Level)

/// Fast block compression into caller-allocated `dst`.
pub const compressBlock = compress_mod.block.compressBlock;

/// Fast block compression returning newly allocated slice.
pub const compressBlockAlloc = compress_mod.block.compressBlockAlloc;

/// Explicit fast block compression with acceleration factor.
pub fn compressFast(src: []const u8, dst: []u8, acceleration: u32) CompressionError!usize {
    return compress_mod.fast.compressFast(src, dst, acceleration, null);
}

/// Explicit High-Compression (HC) block compression with level (2..12).
pub fn compressHC(src: []const u8, dst: []u8, level: i32) CompressionError!usize {
    return compress_mod.hc.compressHc(src, dst, level, null);
}

/// Block compression using an external or prefix reference dictionary.
pub const compressUsingDict = compress_mod.dictionary.compressUsingDict;

/// Block decompression into caller-allocated `dst`.
pub const decompressBlock = decompress_mod.block.decompressBlock;

/// Block decompression returning newly allocated slice.
pub const decompressBlockAlloc = decompress_mod.block.decompressBlockAlloc;

/// Partial block decompression up to `target_size` bytes.
pub const decompressBlockPartial = decompress_mod.block.decompressBlockPartial;

/// Block decompression using a reference dictionary.
pub const decompressBlockWithDict = decompress_mod.block.decompressBlockWithDict;

/// One-shot block allocation aliases.
pub const compressAlloc = compress_mod.block.compressAlloc;
pub const decompressAlloc = decompress_mod.block.decompressAlloc;

// Frame APIs (Standard LZ4 Frame Format)

/// Compresses `src` into a standard LZ4 frame written to `dst`.
pub const compressFrame = frame.writer.compressFrame;

/// Compresses `src` into a standard LZ4 frame returning newly allocated slice.
pub const compressFrameAlloc = frame.writer.compressFrameAlloc;

/// Decompresses an LZ4 frame from `src` into caller-allocated `dst`.
pub const decompressFrame = frame.reader.decompressFrame;

/// Decompresses an LZ4 frame from `src` returning newly allocated slice.
pub const decompressFrameAlloc = frame.reader.decompressFrameAlloc;

/// Inspects and parses the Frame Descriptor from the beginning of `src`.
pub const getFrameInfo = frame.reader.getFrameInfo;

// Streaming & I/O Pipelines

/// Stream compression via `std.Io`.
pub fn compressStream(
    allocator: Allocator,
    reader: *Reader,
    writer: *Writer,
    opts: CompressionOptions,
) !usize {
    const frame_opts: FrameOptions = .{
        .blockMaxSize = opts.blockMaxSize,
        .blockMode = opts.blockMode,
        .contentChecksum = opts.contentChecksum,
        .blockChecksum = opts.blockChecksum,
        .contentSize = opts.contentSize,
        .dictId = opts.dictId,
        .compressionLevel = opts.level,
        .favorDecSpeed = opts.favorDecSpeed,
    };
    return io.writer.compressStream(reader, writer, frame_opts, allocator);
}

/// Stream decompression via `std.Io`.
pub fn decompressStream(
    allocator: Allocator,
    reader: *Reader,
    writer: *Writer,
    opts: DecompressionOptions,
) !usize {
    _ = opts;
    return io.reader.decompressStream(reader, writer, allocator);
}

/// Compresses a file on disk to a target compressed file.
pub const compressFile = io.file.compressFile;

/// Decompresses a compressed file on disk to a restored file.
pub const decompressFile = io.file.decompressFile;

// Checksum API

/// Computes an xxHash-32 checksum with seed.
pub const xxHash32 = utils.checksum.hash;

// Root Tests

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(version_mod);
    std.testing.refAllDecls(errors);
    std.testing.refAllDecls(options);
    std.testing.refAllDecls(utils.bounds);
    std.testing.refAllDecls(utils.endian);
    std.testing.refAllDecls(utils.bitstream);
    std.testing.refAllDecls(utils.checksum);
    std.testing.refAllDecls(utils.memory);
    std.testing.refAllDecls(internal.constants);
    std.testing.refAllDecls(internal.tables);
    std.testing.refAllDecls(internal.validation);
    std.testing.refAllDecls(compress_mod.match_finder);
    std.testing.refAllDecls(compress_mod.fast);
    std.testing.refAllDecls(compress_mod.hc);
    std.testing.refAllDecls(compress_mod.dictionary);
    std.testing.refAllDecls(compress_mod.streaming);
    std.testing.refAllDecls(compress_mod.block);
    std.testing.refAllDecls(decompress_mod.safe);
    std.testing.refAllDecls(decompress_mod.partial);
    std.testing.refAllDecls(decompress_mod.dictionary);
    std.testing.refAllDecls(decompress_mod.streaming);
    std.testing.refAllDecls(decompress_mod.block);
    std.testing.refAllDecls(frame.header);
    std.testing.refAllDecls(frame.descriptor);
    std.testing.refAllDecls(frame.block);
    std.testing.refAllDecls(frame.reader);
    std.testing.refAllDecls(frame.writer);
    std.testing.refAllDecls(frame.streaming);
    std.testing.refAllDecls(frame.skippable);
    std.testing.refAllDecls(io.reader);
    std.testing.refAllDecls(io.writer);
    std.testing.refAllDecls(io.file);
}

test "Compressor and Decompressor reusable contexts" {
    const allocator = std.testing.allocator;

    var compressor = Compressor.init(allocator, .{ .level = 1 });
    defer compressor.deinit();

    var decompressor = Decompressor.init(allocator, .{});
    defer decompressor.deinit();

    const sample1 = "First round of reusable context test with lz4.zig!";
    const comp1 = try compressor.compress(sample1);
    defer allocator.free(comp1);

    const out1 = try decompressor.decompress(comp1);
    defer allocator.free(out1);
    try std.testing.expectEqualStrings(sample1, out1);

    // Reset with HC options
    compressor.reset(.{ .level = 9 });
    decompressor.reset(.{});

    const sample2 = "Second round of reusable context test with High Compression!";
    const comp2 = try compressor.compress(sample2);
    defer allocator.free(comp2);

    const out2 = try decompressor.decompress(comp2);
    defer allocator.free(out2);
    try std.testing.expectEqualStrings(sample2, out2);
}

test "StreamingCompressor and StreamingDecompressor" {
    const allocator = std.testing.allocator;

    var scomp = try StreamingCompressor.init(allocator, .{ .level = 1 });
    defer scomp.deinit();

    var out_storage: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_storage);

    try scomp.write("Part 1: streamed segment. ", &writer);
    try scomp.write("Part 2: streamed segment.", &writer);
    try scomp.finish(&writer);

    const frame_bytes = writer.buffered();

    var sdecomp = StreamingDecompressor.init(allocator, .{});
    defer sdecomp.deinit();

    try sdecomp.feed(frame_bytes);

    var decomp_buf: [128]u8 = undefined;
    const n = try sdecomp.take(&decomp_buf);
    try std.testing.expectEqualStrings("Part 1: streamed segment. Part 2: streamed segment.", decomp_buf[0..n]);
}

test "integration: empty and tiny inputs" {
    const inputs = [_][]const u8{
        "",
        "a",
        "ab",
        "abc",
        "abcd",
        "12345678",
        "123456789012",
        "1234567890123",
    };

    for (inputs) |input| {
        // Fast block
        var comp_buf: [128]u8 = undefined;
        const comp_len = try compress(input, &comp_buf);

        var decomp_buf: [128]u8 = undefined;
        const decomp_len = try decompressInto(comp_buf[0..comp_len], &decomp_buf);
        try std.testing.expectEqualStrings(input, decomp_buf[0..decomp_len]);

        // HC block
        for ([_]i32{ 2, 9 }) |level| {
            var hc_comp: [128]u8 = undefined;
            const hc_len = try compressHC(input, &hc_comp, level);
            var hc_decomp: [128]u8 = undefined;
            const hc_dlen = try decompressInto(hc_comp[0..hc_len], &hc_decomp);
            try std.testing.expectEqualStrings(input, hc_decomp[0..hc_dlen]);
        }

        // Standard Frame
        var frame_buf: [256]u8 = undefined;
        const frame_len = try compressFrame(input, &frame_buf, .{
            .contentChecksum = true,
            .blockChecksum = true,
            .contentSize = input.len,
        });

        var frame_decomp: [256]u8 = undefined;
        const frame_dlen = try decompressFrame(frame_buf[0..frame_len], &frame_decomp);
        try std.testing.expectEqualStrings(input, frame_decomp[0..frame_dlen]);
    }
}

test "integration: repetitive and highly compressible data" {
    const allocator = std.testing.allocator;

    const sizes = [_]usize{ 100, 1000, 10000, 65536 };
    for (sizes) |size| {
        const input = try allocator.alloc(u8, size);
        defer allocator.free(input);

        for (input, 0..) |*b, i| {
            b.* = @as(u8, @truncate(i % 17));
        }

        const comp = try compress(allocator, input);
        defer allocator.free(comp);

        try std.testing.expect(comp.len < input.len);

        const restored = try decompress(allocator, comp);
        defer allocator.free(restored);

        try std.testing.expectEqualSlices(u8, input, restored);
    }
}

test "integration: random incompressible data" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xCAFEBABE);
    const random = prng.random();

    const input = try allocator.alloc(u8, 8192);
    defer allocator.free(input);
    random.bytes(input);

    const f = try compressFrameAlloc(allocator, input, .{
        .contentChecksum = true,
        .blockChecksum = true,
    });
    defer allocator.free(f);

    const restored = try decompressFrameAlloc(allocator, f, input.len);
    defer allocator.free(restored);

    try std.testing.expectEqualSlices(u8, input, restored);
}

test "integration: block corruption and bounds safety" {
    const corrupt_offset_zero = [_]u8{
        0x00,
        0x00,
        0x00,
    };
    var dst: [64]u8 = undefined;
    try std.testing.expectError(
        DecompressionError.OffsetOutOfBounds,
        decompressBlock(&corrupt_offset_zero, &dst),
    );

    const corrupt_offset_beyond = [_]u8{
        0x10,
        'A',
        0x05,
        0x00,
    };
    try std.testing.expectError(
        DecompressionError.OffsetOutOfBounds,
        decompressBlock(&corrupt_offset_beyond, &dst),
    );

    const truncated_literals = [_]u8{
        0x50,
        'A',
        'B',
    };
    try std.testing.expectError(
        DecompressionError.SourceBufferExhausted,
        decompressBlock(&truncated_literals, &dst),
    );

    const valid_block = [_]u8{
        0x40,
        'A',
        'B',
        'C',
        'D',
    };
    var tiny_dst: [2]u8 = undefined;
    try std.testing.expectError(
        DecompressionError.DstCapacityTooSmall,
        decompressBlock(&valid_block, &tiny_dst),
    );
}

test "integration: frame corruption and validation" {
    const valid_input = "Testing frame corruptions";
    var frame_buf: [256]u8 = undefined;
    const frame_len = try compressFrame(valid_input, &frame_buf, .{
        .contentChecksum = true,
        .blockChecksum = true,
    });
    const valid_frame = frame_buf[0..frame_len];

    var corrupt_buf: [256]u8 = undefined;

    @memcpy(corrupt_buf[0..frame_len], valid_frame);
    corrupt_buf[0] = 0xFF;
    var out: [256]u8 = undefined;
    try std.testing.expectError(FrameError.InvalidMagic, decompressFrame(corrupt_buf[0..frame_len], &out));

    @memcpy(corrupt_buf[0..frame_len], valid_frame);
    corrupt_buf[4] ^= 0xC0;
    try std.testing.expectError(FrameError.UnsupportedVersion, decompressFrame(corrupt_buf[0..frame_len], &out));

    @memcpy(corrupt_buf[0..frame_len], valid_frame);
    corrupt_buf[6] ^= 0xFF;
    try std.testing.expectError(FrameError.HeaderChecksumMismatch, decompressFrame(corrupt_buf[0..frame_len], &out));

    @memcpy(corrupt_buf[0..frame_len], valid_frame);
    corrupt_buf[frame_len - 1] ^= 0x55;
    try std.testing.expectError(FrameError.ContentChecksumMismatch, decompressFrame(corrupt_buf[0..frame_len], &out));

    try std.testing.expectError(FrameError.PrematureEndOfFrame, decompressFrame(valid_frame[0 .. frame_len - 5], &out));
}

test "integration: concatenated and skippable frames" {
    const part1 = "First frame payload. ";
    const part2 = "Second frame payload. ";
    const user_data = "Custom metadata tag: 007";

    var stream_buf: [1024]u8 = undefined;
    var p: usize = 0;

    p += try compressFrame(part1, stream_buf[p..], .{ .contentChecksum = true });
    p += try frame.skippable.encodeSkippableFrame(stream_buf[p..], 0, user_data);
    p += try compressFrame(part2, stream_buf[p..], .{ .contentChecksum = true });

    var out: [512]u8 = undefined;
    const decomp_len = try decompressFrame(stream_buf[0..p], &out);

    try std.testing.expectEqualStrings("First frame payload. Second frame payload. ", out[0..decomp_len]);
}
