//! Example: Decompressing an existing LZ4 compressed file into a restored file.

const std = @import("std");
const lz4 = @import("lz4");
const Io = std.Io;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = Io.Dir.cwd();
    const lz4_file = "example_archive.lz4";
    const restored_file = "example_restored.txt";

    defer {
        cwd.deleteFile(io, lz4_file) catch {};
        cwd.deleteFile(io, restored_file) catch {};
    }

    const content = "Decompressing files from disk safely with native Zig LZ4!\n";

    // 1. Create compressed archive
    {
        var frame_buf: [512]u8 = undefined;
        const frame_len = try lz4.compressInto(content, &frame_buf);

        const file = try cwd.createFile(io, lz4_file, .{});
        defer file.close(io);
        var buf: [256]u8 = undefined;
        var w = file.writer(io, &buf);
        try w.interface.writeAll(frame_buf[0..frame_len]);
        try w.interface.flush();
    }

    // 2. Decompress
    try lz4.decompressFile(io, lz4_file, restored_file, allocator);

    std.debug.print("Successfully decompressed '{s}' to '{s}'\n", .{ lz4_file, restored_file });
}
