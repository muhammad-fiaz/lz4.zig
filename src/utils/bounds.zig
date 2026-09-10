//! Buffer capacity and bound calculations for LZ4 block and frame encoding.

const std = @import("std");
const constants = @import("../internal/constants.zig");
const options_mod = @import("../options.zig");
const FrameOptions = options_mod.FrameOptions;

/// Returns the maximum worst-case compressed output size for a block of `input_size`.
///
/// Formula: `input_size + (input_size / 255) + 16`
/// If `input_size > MAX_INPUT_SIZE`, returns 0.
pub fn compressBound(input_size: usize) usize {
    if (input_size > constants.MAX_INPUT_SIZE) return 0;
    return input_size + (input_size / 255) + 16;
}

/// Alias for `compressBound`.
pub const compressBlockBound = compressBound;

/// Returns the worst-case maximum output size required to store an entire LZ4 frame
/// for `input_size` with the given `options`.
pub fn compressFrameBound(input_size: usize, options: FrameOptions) usize {
    // Header size: magic(4) + FLG(1) + BD(1) + [contentSize(8)] + [dictID(4)] + HC(1)
    var header_size: usize = constants.FRAME_HEADER_MIN_SIZE;
    if (options.contentSize != null) header_size += constants.CONTENT_SIZE_SIZE;
    if (options.dictId != null) header_size += constants.DICT_ID_SIZE;

    // Footer size: EndMark(4) + [ContentChecksum(4)]
    var footer_size: usize = constants.FRAME_FOOTER_MIN_SIZE;
    if (options.contentChecksum) footer_size += constants.CONTENT_CHECKSUM_SIZE;

    const block_max_size = options.blockMaxSize.toBytes();
    const num_blocks = if (input_size == 0) 1 else (input_size + block_max_size - 1) / block_max_size;

    // Each block has 4-byte header, plus optional 4-byte block checksum
    const block_overhead = constants.BLOCK_HEADER_SIZE +
        (if (options.blockChecksum) constants.BLOCK_CHECKSUM_SIZE else 0);

    // Worst-case block payload is compressBound(block_size)
    const worst_case_block = compressBound(block_max_size);

    return header_size + footer_size + (num_blocks * (block_overhead + worst_case_block));
}

test "compressBound values" {
    try std.testing.expectEqual(16, compressBound(0));
    try std.testing.expectEqual(17, compressBound(1));
    try std.testing.expectEqual(1024 + (1024 / 255) + 16, compressBound(1024));
    try std.testing.expectEqual(0, compressBound(constants.MAX_INPUT_SIZE + 1));
}

test "compressFrameBound values" {
    const opts = FrameOptions{};
    const bound = compressFrameBound(1024, opts);
    try std.testing.expect(bound > 1024);
}
