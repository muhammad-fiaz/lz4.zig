//! Hash tables and chain tables for match finders.

const std = @import("std");
const constants = @import("constants.zig");

/// Hash table for fast compression.
pub const FastTable = struct {
    table: [constants.HASH_SIZE_DEFAULT]u32,

    pub fn init() FastTable {
        var self: FastTable = undefined;
        self.clear();
        return self;
    }

    pub fn clear(self: *FastTable) void {
        @memset(&self.table, 0);
    }
};

/// Hash table and chain table for High Compression (HC) mode.
pub const HcTable = struct {
    hash_table: [constants.HASH_SIZE_HC]u32,
    chain_table: [65536]u16,

    pub fn init() HcTable {
        var self: HcTable = undefined;
        self.clear();
        return self;
    }

    pub fn clear(self: *HcTable) void {
        @memset(&self.hash_table, 0);
        @memset(&self.chain_table, 0);
    }
};
