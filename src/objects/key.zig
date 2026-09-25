const std = @import("std");
const value_mod = @import("../values/value.zig");
const string_mod = @import("../values/string.zig");
const Value = value_mod.Value;
const Symbol = value_mod.Symbol;

pub const PropertyKey = union(enum) {
    string: []const u8,
    symbol: *Symbol,
    index: u32,

    pub fn fromString(s: []const u8) PropertyKey {
        return .{ .string = s };
    }

    pub fn fromSymbol(s: *Symbol) PropertyKey {
        return .{ .symbol = s };
    }

    pub fn fromIndex(i: u32) PropertyKey {
        return .{ .index = i };
    }

    pub fn fromValue(v: Value) ?PropertyKey {
        return switch (v) {
            .string => |s| blk: {
                const concrete = string_mod.asConcrete(s);
                break :blk .{ .string = concrete.bytes };
            },
            .symbol => |s| .{ .symbol = s },
            .number => |n| {
                if (n >= 0 and n < 4294967295.0 and @floor(n) == n) {
                    return .{ .index = @intFromFloat(n) };
                }
                return null;
            },
            else => null,
        };
    }

    pub fn isString(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .string;
    }

    pub fn isSymbol(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .symbol;
    }

    pub fn isIndex(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .index;
    }

    pub fn asString(self: PropertyKey) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn asSymbol(self: PropertyKey) ?*Symbol {
        return switch (self) {
            .symbol => |s| s,
            else => null,
        };
    }

    pub fn asIndex(self: PropertyKey) ?u32 {
        return switch (self) {
            .index => |i| i,
            else => null,
        };
    }

    pub fn eql(self: PropertyKey, other: PropertyKey) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);
        if (t1 != t2) return false;

        return switch (self) {
            .string => |a| std.mem.eql(u8, a, other.string),
            .symbol => |a| a == other.symbol,
            .index => |a| a == other.index,
        };
    }

    pub fn hash(self: PropertyKey) u64 {
        return switch (self) {
            .string => |s| blk: {
                var h: u64 = 14695981039346656037;
                for (s) |b| {
                    h ^= b;
                    h *%= 1099511628211;
                }
                break :blk h;
            },
            .symbol => |s| @intFromPtr(s),
            .index => |i| @as(u64, i) *% 0x9E3779B97F4A7C15,
        };
    }
};

pub fn fromString(s: []const u8) PropertyKey {
    return PropertyKey.fromString(s);
}

pub fn fromIndex(i: u32) PropertyKey {
    return PropertyKey.fromIndex(i);
}

pub fn eql(a: PropertyKey, b: PropertyKey) bool {
    return a.eql(b);
}

test "fromString" {
    const k = PropertyKey.fromString("foo");
    try std.testing.expect(k.isString());
    try std.testing.expectEqualStrings("foo", k.asString().?);
}

test "fromIndex" {
    const k = PropertyKey.fromIndex(42);
    try std.testing.expect(k.isIndex());
    try std.testing.expectEqual(@as(u32, 42), k.asIndex().?);
}

test "fromSymbol" {
    var dummy: u8 = 0;
    const sym: *Symbol = @ptrCast(&dummy);
    const k = PropertyKey.fromSymbol(sym);
    try std.testing.expect(k.isSymbol());
    try std.testing.expectEqual(sym, k.asSymbol().?);
}

test "fromValue symbol" {
    var dummy: u8 = 0;
    const sym: *Symbol = @ptrCast(&dummy);
    const k = PropertyKey.fromValue(Value.fromSymbol(sym)).?;
    try std.testing.expect(k.isSymbol());
}

test "fromValue index" {
    const k = PropertyKey.fromValue(Value.fromNumber(42.0)).?;
    try std.testing.expect(k.isIndex());
    try std.testing.expectEqual(@as(u32, 42), k.asIndex().?);
}

test "fromValue rejects negative" {
    try std.testing.expectEqual(@as(?PropertyKey, null), PropertyKey.fromValue(Value.fromNumber(-1.0)));
}

test "fromValue rejects non-integer" {
    try std.testing.expectEqual(@as(?PropertyKey, null), PropertyKey.fromValue(Value.fromNumber(1.5)));
}

test "fromValue rejects bool" {
    try std.testing.expectEqual(@as(?PropertyKey, null), PropertyKey.fromValue(Value.TRUE));
}

test "eql same string" {
    try std.testing.expect(PropertyKey.fromString("foo").eql(PropertyKey.fromString("foo")));
}

test "eql different string" {
    try std.testing.expect(!PropertyKey.fromString("foo").eql(PropertyKey.fromString("bar")));
}

test "eql different kinds" {
    try std.testing.expect(!PropertyKey.fromString("42").eql(PropertyKey.fromIndex(42)));
}

test "eql same index" {
    try std.testing.expect(PropertyKey.fromIndex(42).eql(PropertyKey.fromIndex(42)));
}

test "hash deterministic string" {
    try std.testing.expectEqual(PropertyKey.fromString("foo").hash(), PropertyKey.fromString("foo").hash());
}

test "hash different strings" {
    try std.testing.expect(PropertyKey.fromString("foo").hash() != PropertyKey.fromString("bar").hash());
}

test "hash deterministic index" {
    try std.testing.expectEqual(PropertyKey.fromIndex(42).hash(), PropertyKey.fromIndex(42).hash());
}
