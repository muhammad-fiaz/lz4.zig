//! High-level file compression and decompression convenience APIs.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const options_mod = @import("../options.zig");
const FrameOptions = options_mod.FrameOptions;
const io_writer = @import("writer.zig");
const io_reader = @import("reader.zig");

/// Compresses a file at `src_path` into an LZ4 frame file at `dst_path`.
pub fn compressFile(
    io: Io,
    src_path: []const u8,
    dst_path: []const u8,
    options: FrameOptions,
    allocator: Allocator,
) !void {
    const cwd = Io.Dir.cwd();

    const in_file = try cwd.openFile(io, src_path, .{ .mode = .read_only });
    defer in_file.close(io);

    const out_file = try cwd.createFile(io, dst_path, .{});
    defer out_file.close(io);

    var r_buf: [64 * 1024]u8 = undefined;
    var f_reader = in_file.reader(io, &r_buf);

    var w_buf: [64 * 1024]u8 = undefined;
    var f_writer = out_file.writer(io, &w_buf);

    _ = try io_writer.compressStream(&f_reader.interface, &f_writer.interface, options, allocator);
    try f_writer.interface.flush();
}

/// Decompresses an LZ4 frame file at `src_path` to `dst_path`.
pub fn decompressFile(
    io: Io,
    src_path: []const u8,
    dst_path: []const u8,
    allocator: Allocator,
) !void {
    const cwd = Io.Dir.cwd();

    const in_file = try cwd.openFile(io, src_path, .{ .mode = .read_only });
    defer in_file.close(io);

    const out_file = try cwd.createFile(io, dst_path, .{});
    defer out_file.close(io);

    var r_buf: [64 * 1024]u8 = undefined;
    var f_reader = in_file.reader(io, &r_buf);

    var w_buf: [64 * 1024]u8 = undefined;
    var f_writer = out_file.writer(io, &w_buf);

    _ = try io_reader.decompressStream(&f_reader.interface, &f_writer.interface, allocator);
    try f_writer.interface.flush();
}

test "compressFile and decompressFile roundtrip" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const src_file = "test_file_input.tmp";
    const comp_file = "test_file_output.lz4";
    const decomp_file = "test_file_restored.tmp";

    const cwd = Io.Dir.cwd();
    defer {
        cwd.deleteFile(io, src_file) catch {};
        cwd.deleteFile(io, comp_file) catch {};
        cwd.deleteFile(io, decomp_file) catch {};
    }

    const payload = "Hello from full end-to-end file compression in native Zig 0.17.0!\n";

    // Write source file
    {
        const f = try cwd.createFile(io, src_file, .{});
        defer f.close(io);
        var buf: [1024]u8 = undefined;
        var w = f.writer(io, &buf);
        try w.interface.writeAll(payload);
        try w.interface.flush();
    }

    // Compress
    try compressFile(io, src_file, comp_file, .{ .contentChecksum = true }, std.testing.allocator);

    // Decompress
    try decompressFile(io, comp_file, decomp_file, std.testing.allocator);

    // Verify
    {
        const f = try cwd.openFile(io, decomp_file, .{ .mode = .read_only });
        defer f.close(io);
        var r_buf: [1024]u8 = undefined;
        var r = f.reader(io, &r_buf);
        var read_buf: [1024]u8 = undefined;
        const bytes_read = try r.interface.readSliceShort(&read_buf);
        try std.testing.expectEqualStrings(payload, read_buf[0..bytes_read]);
    }
}
