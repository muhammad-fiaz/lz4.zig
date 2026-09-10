//! Example: Custom dictionary-assisted compression and decompression.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const dict =
        \\HTTP/1.1 200 OK
        \\Content-Type: application/json
        \\Server: ZigLZ4
    ;

    // Attach dictionary to reusable compressor and decompressor
    var compressor = lz4.Compressor.init(allocator, .{ .level = 9 });
    defer compressor.deinit();
    compressor.attachDictionary(dict);

    var decompressor = lz4.Decompressor.init(allocator, .{});
    defer decompressor.deinit();
    decompressor.attachDictionary(dict);

    const message =
        \\HTTP/1.1 200 OK
        \\Content-Type: application/json
        \\Server: ZigLZ4
        \\
        \\{"status":"ok","code":200}
    ;

    // Compress
    var comp_buf: [256]u8 = undefined;
    const comp_len = try lz4.compressUsingDict(message, &comp_buf, dict, .{ .level = 9 });
    std.debug.print("Original message: {d} bytes\n", .{message.len});
    std.debug.print("Dictionary compressed: {d} bytes\n", .{comp_len});

    // Decompress
    var restored: [256]u8 = undefined;
    const decomp_len = try lz4.decompressBlockWithDict(comp_buf[0..comp_len], &restored, dict);

    std.debug.print("Restored message: '{s}' ({d} bytes)\n", .{
        restored[0..decomp_len],
        decomp_len,
    });
}
