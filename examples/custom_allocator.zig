//! Example: Explicit allocator and memory control using ArenaAllocator or GPA.

const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    // Demonstrate explicit allocator injection using an ArenaAllocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const data = "Explicit memory management with custom arena allocation in Zig.";

    // Allocation happens entirely inside caller's arena
    const compressed = try lz4.compressAlloc(arena_allocator, data);
    std.debug.print("Arena compressed size: {d} bytes\n", .{compressed.len});

    const decompressed = try lz4.decompressAlloc(arena_allocator, compressed, data.len + 32);
    std.debug.print("Arena restored: '{s}'\n", .{decompressed});

    // Entire arena is cleanly freed on function exit without individual deallocations
}
