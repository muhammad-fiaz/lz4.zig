//! Decoder robustness fuzzer and property test suite for lz4.zig.
//!
//! Validates that the decoder treats arbitrary, untrusted, or corrupted input safely
//! without crashing, panicking, hanging, or performing out-of-bounds memory accesses.

const std = @import("std");
const lz4 = @import("lz4");

/// Fuzz raw block decompression against arbitrary input.
pub fn fuzzBlockDecompress(data: []const u8) void {
    var out_buf: [4096]u8 = undefined;
    _ = lz4.decompressInto(data, &out_buf) catch {};
}

/// Fuzz frame decompression against arbitrary input.
pub fn fuzzFrameDecompress(data: []const u8) void {
    var out_buf: [8192]u8 = undefined;
    _ = lz4.decompressFrame(data, &out_buf) catch {};
}

test "fuzz: arbitrary garbage never panics or crashes decoders" {
    var prng = std.Random.DefaultPrng.init(0x1337BEEF);
    const random = prng.random();

    var garbage: [1024]u8 = undefined;

    for (0..300) |_| {
        random.bytes(&garbage);
        const sub_len = random.uintLessThan(usize, garbage.len + 1);
        const slice = garbage[0..sub_len];

        fuzzBlockDecompress(slice);
        fuzzFrameDecompress(slice);
    }
}

test "fuzz: targeted bit mutations on valid compressed streams" {
    var prng = std.Random.DefaultPrng.init(0x5EEDC0DE);
    const random = prng.random();

    const original = "Reliable compression and decompression under heavy fuzz mutations!";
    var frame_buf: [512]u8 = undefined;
    const frame_len = try lz4.compressFrame(original, &frame_buf, .{
        .contentChecksum = true,
        .blockChecksum = true,
    });

    var mutated: [512]u8 = undefined;

    for (0..200) |_| {
        @memcpy(mutated[0..frame_len], frame_buf[0..frame_len]);

        // Flip 1 to 4 random bytes
        const flips = random.uintLessThan(usize, 4) + 1;
        for (0..flips) |_| {
            const idx = random.uintLessThan(usize, frame_len);
            mutated[idx] ^= random.int(u8);
        }

        var out: [256]u8 = undefined;
        // Must either succeed (if benign) or safely return an error without panic
        _ = lz4.decompressFrame(mutated[0..frame_len], &out) catch {};
    }
}

test "fuzz: truncated compressed frames" {
    const original = "Testing prefix truncation safety across every byte offset in the frame!";
    var frame_buf: [512]u8 = undefined;
    const frame_len = try lz4.compressFrame(original, &frame_buf, .{
        .contentChecksum = true,
        .blockChecksum = true,
    });

    // Test every single truncated length from 0 to frame_len - 1
    for (0..frame_len) |cut| {
        var out: [256]u8 = undefined;
        _ = lz4.decompressFrame(frame_buf[0..cut], &out) catch {};
    }
}

test "fuzz: raw block truncation" {
    const original = "Testing block truncation safety across literal tokens and match sequences!";
    var block_buf: [512]u8 = undefined;
    const block_len = try lz4.compress(original, &block_buf);

    for (0..block_len) |cut| {
        var out: [256]u8 = undefined;
        _ = lz4.decompressInto(block_buf[0..cut], &out) catch {};
    }
}
