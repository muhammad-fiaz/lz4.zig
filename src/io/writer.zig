//! Streaming frame compression pipeline using standard library Reader and Writer interfaces.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const bounds = @import("../utils/bounds.zig");
const options_mod = @import("../options.zig");
const FrameOptions = options_mod.FrameOptions;
const streaming_frame = @import("../frame/streaming.zig");

/// Compresses data streamed from `r` into an LZ4 frame written to `w`.
/// Processes data incrementally in blocks of `options.blockMaxSize`.
/// Returns total bytes written to `w`.
pub fn compressStream(
    r: *Reader,
    w: *Writer,
    options: FrameOptions,
    allocator: Allocator,
) !usize {
    var stream = try streaming_frame.FrameCompressStream.init(allocator, options);
    defer stream.deinit();

    const block_max_size = options.blockMaxSize.toBytes();
    const in_chunk_buf = try allocator.alloc(u8, block_max_size);
    defer allocator.free(in_chunk_buf);

    const worst_case = bounds.compressFrameBound(block_max_size, options);
    const out_chunk_buf = try allocator.alloc(u8, worst_case);
    defer allocator.free(out_chunk_buf);

    var total_written: usize = 0;

    // Write Frame Header
    const hdr_len = try stream.writeHeader(out_chunk_buf);
    try w.writeAll(out_chunk_buf[0..hdr_len]);
    total_written += hdr_len;

    // Stream input chunks
    while (true) {
        const bytes_read = try r.readSliceShort(in_chunk_buf);
        if (bytes_read == 0) break;

        const comp_len = try stream.update(in_chunk_buf[0..bytes_read], out_chunk_buf);
        if (comp_len > 0) {
            try w.writeAll(out_chunk_buf[0..comp_len]);
            total_written += comp_len;
        }
    }

    // Finish frame (EndMark + Content Checksum)
    const fin_len = try stream.finish(out_chunk_buf);
    if (fin_len > 0) {
        try w.writeAll(out_chunk_buf[0..fin_len]);
        total_written += fin_len;
    }

    try w.flush();
    return total_written;
}

test "compressStream with fixed reader and writer" {
    const reader_mod = @import("reader.zig");

    const message = "Streaming compression pipeline reading from Reader and outputting to Writer!";
    var in_reader = Reader.fixed(message);

    var frame_buf: [1024]u8 = undefined;
    var out_writer = Writer.fixed(&frame_buf);

    const frame_len = try compressStream(&in_reader, &out_writer, .{ .contentChecksum = true }, std.testing.allocator);
    try std.testing.expect(frame_len > 0);

    var verify_reader = Reader.fixed(frame_buf[0..frame_len]);
    var decomp_buf: [512]u8 = undefined;
    var verify_writer = Writer.fixed(&decomp_buf);

    const decomp_len = try reader_mod.decompressStream(&verify_reader, &verify_writer, std.testing.allocator);
    try std.testing.expectEqualStrings(message, decomp_buf[0..decomp_len]);
}
