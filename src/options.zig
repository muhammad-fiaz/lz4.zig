//! Configuration options for LZ4 block and frame encoding/decoding.

const std = @import("std");
const constants = @import("internal/constants.zig");

/// Block dependency mode in LZ4 frame format.
pub const BlockMode = enum(u1) {
    linked = 0,
    independent = 1,
};

/// Block maximum uncompressed size permitted in an LZ4 frame.
pub const BlockMaxSize = enum(u3) {
    max64KB = 4,
    max256KB = 5,
    max1MB = 6,
    max4MB = 7,

    /// Convert the block size identifier to its byte capacity.
    pub fn toBytes(self: BlockMaxSize) usize {
        return switch (self) {
            .max64KB => constants.BLOCK_SIZE_64KB,
            .max256KB => constants.BLOCK_SIZE_256KB,
            .max1MB => constants.BLOCK_SIZE_1MB,
            .max4MB => constants.BLOCK_SIZE_4MB,
        };
    }

    /// Parse a 3-bit field from BD descriptor into a valid BlockMaxSize.
    pub fn fromId(id: u3) ?BlockMaxSize {
        return switch (id) {
            4 => .max64KB,
            5 => .max256KB,
            6 => .max1MB,
            7 => .max4MB,
            else => null,
        };
    }

    /// Return the 3-bit descriptor ID.
    pub fn toId(self: BlockMaxSize) u3 {
        return @backingInt(self);
    }
};

/// Configuration options for general LZ4 compression.
pub const CompressionOptions = struct {
    /// Compression level: 1 = fast, 2..12 = High Compression (HC).
    level: i32 = constants.CLEVEL_DEFAULT,
    /// Acceleration factor for fast mode (level 1). Values > 1 increase speed at small cost to ratio.
    acceleration: u32 = constants.ACCELERATION_DEFAULT,
    /// Maximum size of data blocks within an LZ4 frame (64KB, 256KB, 1MB, 4MB). Default is 64 KB.
    blockMaxSize: BlockMaxSize = .max64KB,
    /// Whether blocks are independent (default) or linked.
    blockMode: BlockMode = .independent,
    /// Whether to calculate and append an xxHash-32 content checksum. Default is true.
    contentChecksum: bool = true,
    /// Whether to append a 32-bit xxHash-32 checksum after each block. Default is false.
    blockChecksum: bool = false,
    /// Optional uncompressed content size to store in the frame header.
    contentSize: ?u64 = null,
    /// Optional dictionary identifier to store in the frame header.
    dictId: ?u32 = null,
    /// Optional custom dictionary for dictionary-based compression.
    customDictionary: ?[]const u8 = null,
    /// In HC mode, whether to favor decompression speed.
    favorDecSpeed: bool = false,
    /// Whether to flush each block immediately without waiting for full blockMaxSize.
    autoFlush: bool = true,
};

/// Configuration options for general LZ4 decompression.
pub const DecompressionOptions = struct {
    /// Maximum permitted output buffer allocation size to protect against decompression bombs. Default is 128 MB.
    maxOutputSize: usize = 128 * 1024 * 1024,
    /// Optional custom dictionary for dictionary-based decompression.
    customDictionary: ?[]const u8 = null,
};

/// Configuration options for block-level compression (legacy alias).
pub const BlockCompressionOptions = struct {
    /// Compression level:
    /// - 1: Fast compression (default).
    /// - 2..12: High Compression (HC) mode with increasing search depth.
    level: i32 = constants.CLEVEL_DEFAULT,
    /// Acceleration factor for fast mode (level 1). Values > 1 increase speed at small cost to ratio.
    acceleration: u32 = constants.ACCELERATION_DEFAULT,
    /// In HC mode, whether to favor decompression speed.
    favorDecSpeed: bool = false,
    /// Optional dictionary buffer for dictionary-based compression.
    dict: ?[]const u8 = null,
};

/// Configuration preferences for LZ4 frame compression.
pub const FrameOptions = struct {
    /// Maximum size of data blocks within the frame. Default is 64 KB.
    blockMaxSize: BlockMaxSize = .max64KB,
    /// Whether blocks are independent (default) or linked (better ratio for small blocks).
    blockMode: BlockMode = .independent,
    /// Whether to append a 32-bit xxHash-32 checksum of the entire decoded content.
    contentChecksum: bool = true,
    /// Whether to append a 32-bit xxHash-32 checksum after each individual data block.
    blockChecksum: bool = false,
    /// Optional uncompressed content size to store in the frame header.
    contentSize: ?u64 = null,
    /// Optional dictionary identifier to store in the frame header.
    dictId: ?u32 = null,
    /// Compression level to use for individual blocks: 1 (fast), 2..12 (HC).
    compressionLevel: i32 = constants.CLEVEL_DEFAULT,
    /// Whether to flush each block immediately without waiting for full blockMaxSize.
    autoFlush: bool = true,
    /// When using HC compression, optimize match selection for faster decompression.
    favorDecSpeed: bool = false,
};

test "BlockMaxSize sizes" {
    try std.testing.expectEqual(65536, BlockMaxSize.max64KB.toBytes());
    try std.testing.expectEqual(262144, BlockMaxSize.max256KB.toBytes());
    try std.testing.expectEqual(1048576, BlockMaxSize.max1MB.toBytes());
    try std.testing.expectEqual(4194304, BlockMaxSize.max4MB.toBytes());

    try std.testing.expectEqual(BlockMaxSize.max64KB, BlockMaxSize.fromId(4).?);
    try std.testing.expect(BlockMaxSize.fromId(0) == null);
}
