//! Example: Allocation-based convenience APIs for dynamic memory management.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const input = "Dynamically allocated slices returned directly from compress / decompress.";

    // 1. One-shot frame compression into allocated buffer
    const frame_slice = try lz4.compress(allocator, input);
    defer allocator.free(frame_slice);
    std.debug.print("Allocated compressed frame size: {d} bytes\n", .{frame_slice.len});

    // 2. One-shot frame decompression into allocated buffer
    const restored_frame = try lz4.decompress(allocator, frame_slice);
    defer allocator.free(restored_frame);
    std.debug.print("Allocated restored frame: '{s}'\n", .{restored_frame});

    // 3. Raw block allocation APIs
    const raw_block = try lz4.compressAlloc(allocator, input);
    defer allocator.free(raw_block);
    const restored_block = try lz4.decompressAlloc(allocator, raw_block, input.len + 16);
    defer allocator.free(restored_block);
    std.debug.print("Allocated raw block restored: '{s}'\n", .{restored_block});
}
