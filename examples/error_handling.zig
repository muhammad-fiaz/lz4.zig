//! Example: Safe error handling on corrupted, truncated, and invalid LZ4 inputs.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    var out_buf: [256]u8 = undefined;

    // 1. Handling truncated block input
    const truncated_block = [_]u8{ 0x30, 'X' }; // claims 3 literals, only 1 provided
    if (lz4.decompress(&truncated_block, &out_buf)) |_| {
        std.debug.print("Unexpected success on truncated input!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on truncated block: {s}\n", .{@errorName(err)});
    }

    // 2. Handling invalid magic number on frame decompression
    const bad_magic_frame = [_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66 };
    if (lz4.decompressFrame(&bad_magic_frame, &out_buf)) |_| {
        std.debug.print("Unexpected success on bad magic!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on invalid frame magic: {s}\n", .{@errorName(err)});
    }

    // 3. Handling destination buffer exhaustion
    var tiny_buf: [4]u8 = undefined;
    const large_text = "This uncompressed text exceeds 4 bytes capacity!";
    var valid_comp: [128]u8 = undefined;
    const comp_len = try lz4.compress(large_text, &valid_comp);

    if (lz4.decompress(valid_comp[0..comp_len], &tiny_buf)) |_| {
        std.debug.print("Unexpected success on small buffer!\n", .{});
    } else |err| {
        std.debug.print("Expected error caught on small buffer: {s}\n", .{@errorName(err)});
    }
}
