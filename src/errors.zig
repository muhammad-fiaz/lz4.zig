//! Error sets for the LZ4 compression and decompression ecosystem.

const std = @import("std");

/// Errors that can occur during block or streaming compression.
pub const CompressionError = error{
    /// The destination buffer is not large enough to hold the compressed output.
    DstCapacityTooSmall,
    /// The input size exceeds the maximum supported by the format (2,113,929,216 bytes).
    InputTooLarge,
    /// Source data contains invalid or contradictory patterns for the requested mode.
    CorruptInput,
    /// An allocation failed during compression context setup.
    OutOfMemory,
};

/// Errors that can occur during block or streaming decompression.
pub const DecompressionError = error{
    /// Compressed input is corrupted or violates format grammar.
    MalformedInput,
    /// A match offset is zero or references bytes outside available history.
    OffsetOutOfBounds,
    /// Variable-length literal extension was truncated or overflowed.
    CorruptLiteralLength,
    /// Variable-length match extension was truncated or overflowed.
    CorruptMatchLength,
    /// The destination buffer capacity was exhausted before decompression finished.
    DstCapacityTooSmall,
    /// Input data ended unexpectedly before sequence completion.
    SourceBufferExhausted,
    /// Unexpected end of stream or missing required terminal literals.
    UnexpectedEndOfStream,
    /// An allocation failed during decompression.
    OutOfMemory,
};

/// Errors that can occur during frame encoding or decoding.
pub const FrameError = error{
    /// The stream does not start with a valid LZ4 frame or skippable magic number.
    InvalidMagic,
    /// The frame descriptor specifies a format version other than 01b.
    UnsupportedVersion,
    /// Reserved bits in FLG or BD descriptor bytes are not zero.
    ReservedBitsNonZero,
    /// The 1-byte header checksum does not match computed xxHash32 value.
    HeaderChecksumMismatch,
    /// The 4-byte block checksum does not match raw block xxHash32.
    BlockChecksumMismatch,
    /// The 4-byte content checksum does not match uncompressed xxHash32.
    ContentChecksumMismatch,
    /// The block maximum size identifier is outside 4..7 (64KB..4MB).
    InvalidBlockMaxSize,
    /// A data block's declared size exceeds the frame descriptor's maximum block size.
    BlockSizeTooLarge,
    /// Destination capacity is insufficient for frame operations.
    DstCapacityTooSmall,
    /// Source buffer has fewer bytes than required to read the next field.
    SrcBufferTooSmall,
    /// Missing 4-byte 0x00000000 EndMark at expected frame boundary.
    MissingEndMark,
    /// Frame truncated before complete block or footer was read.
    PrematureEndOfFrame,
    /// Frame requires a dictionary with DictID that does not match provided dictionary.
    DictionaryMismatch,
    /// General corruption in framed block payload.
    CorruptFrame,
    /// Memory allocation failed during frame processing.
    OutOfMemory,
};

/// Unified error set covering all native LZ4 operations.
pub const Error = CompressionError || DecompressionError || FrameError;

test "error sets integrity" {
    const err: Error = CompressionError.DstCapacityTooSmall;
    try std.testing.expect(err == CompressionError.DstCapacityTooSmall);
}
