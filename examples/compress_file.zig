//! Example: Compressing an existing file on disk into an LZ4 frame file.

const std = @import("std");
const lz4 = @import("lz4");
const Io = std.Io;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = Io.Dir.cwd();
    const src_file = "example_input.txt";
    const dst_file = "example_output.lz4";

    defer {
        cwd.deleteFile(io, src_file) catch {};
        cwd.deleteFile(io, dst_file) catch {};
    }

    // Create sample source file
    {
        const out = try cwd.createFile(io, src_file, .{});
        defer out.close(io);
        var buf: [256]u8 = undefined;
        var w = out.writer(io, &buf);
        try w.interface.writeAll("Native Zig LZ4 file compression using std.Io and LZ4 frame format!\n");
        try w.interface.flush();
    }

    // Compress file to destination
    try lz4.compressFile(io, src_file, dst_file, .{}, allocator);

    std.debug.print("Successfully compressed '{s}' to '{s}'\n", .{ src_file, dst_file });
}
