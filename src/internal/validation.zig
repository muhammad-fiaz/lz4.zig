//! Safety and invariant validation for LZ4 blocks and frames.

const std = @import("std");
const constants = @import("constants.zig");
const errors = @import("../errors.zig");

/// Validate input size against the LZ4 format limit (2,113,929,216 bytes).
pub inline fn validateInputSize(size: usize) errors.CompressionError!void {
    if (size > constants.MAX_INPUT_SIZE) {
        return errors.CompressionError.InputTooLarge;
    }
}

/// Validate that a match offset is non-zero and within the allowed maximum distance.
pub inline fn validateOffset(offset: usize, max_allowed: usize) errors.DecompressionError!void {
    if (offset == 0 or offset > max_allowed or offset > constants.MAX_DISTANCE) {
        return errors.DecompressionError.OffsetOutOfBounds;
    }
}

/// Validate destination buffer capacity for worst-case compression.
pub inline fn validateDstCapacity(dst_len: usize, required_len: usize) errors.CompressionError!void {
    if (dst_len < required_len) {
        return errors.CompressionError.DstCapacityTooSmall;
    }
}

test "validation checks" {
    try std.testing.expectError(errors.CompressionError.InputTooLarge, validateInputSize(constants.MAX_INPUT_SIZE + 1));
    try std.testing.expectError(errors.DecompressionError.OffsetOutOfBounds, validateOffset(0, 100));
    try std.testing.expectError(errors.DecompressionError.OffsetOutOfBounds, validateOffset(101, 100));
    try validateOffset(50, 100);
}
