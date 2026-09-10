//! Example: Allocation-based convenience APIs for dynamic memory management.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const input = "Dynamically allocated slices returned directly from compressAlloc / decompressAlloc.";

    // 1. Compress into newly allocated buffer
    const comp_slice = try lz4.compressAlloc(allocator, input);
    defer allocator.free(comp_slice);
    std.debug.print("Allocated compressed buffer size: {d} bytes\n", .{comp_slice.len});

    // 2. Decompress into newly allocated buffer
    const decomp_slice = try lz4.decompressAlloc(allocator, comp_slice, input.len + 16);
    defer allocator.free(decomp_slice);
    std.debug.print("Allocated restored buffer: '{s}'\n", .{decomp_slice});
}
