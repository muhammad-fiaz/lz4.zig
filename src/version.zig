//! Version information for lz4.zig.
/// Standard upstream reference commit: https://github.com/lz4/lz4/tree/48bfbfe351c5d6ea87d4af5557705e87755844e0
const std = @import("std");

/// Semantic version representation.
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn format(
        self: Version,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }
};

/// Library package release version.
pub const version = Version{
    .major = 0,
    .minor = 0,
    .patch = 1,
};

/// Returns the library version string ("0.0.1").
pub fn versionString() []const u8 {
    return "0.0.1";
}

/// Returns the library integer version number (1).
pub fn versionNumber() u32 {
    return version.major * 10000 + version.minor * 100 + version.patch;
}

test "version sanity" {
    try std.testing.expectEqual(0, version.major);
    try std.testing.expectEqual(0, version.minor);
    try std.testing.expectEqual(1, version.patch);
    try std.testing.expectEqualStrings("0.0.1", versionString());
    try std.testing.expectEqual(@as(u32, 1), versionNumber());
}
