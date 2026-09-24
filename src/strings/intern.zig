const std = @import("std");

pub const StringId = struct {
    index: u32,
    generation: u32,

    pub fn eql(self: StringId, other: StringId) bool {
        return self.index == other.index and self.generation == other.generation;
    }
};

pub const Entry = struct {
    text: []const u8,
    id: StringId,
};

pub const Interner = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry),
    lookup: std.StringHashMap(u32),
    generation: u32,

    pub fn init(allocator: std.mem.Allocator) Interner {
        return .{
            .allocator = allocator,
            .entries = .empty,
            .lookup = std.StringHashMap(u32).init(allocator),
            .generation = 1,
        };
    }

    pub fn deinit(self: *Interner) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.text);
        }
        self.entries.deinit(self.allocator);
        self.lookup.deinit();
    }

    pub fn intern(self: *Interner, text: []const u8) !StringId {
        if (self.lookup.get(text)) |index| {
            return self.entries.items[index].id;
        }

        const owned = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(owned);

        const index: u32 = @intCast(self.entries.items.len);
        const id = StringId{ .index = index, .generation = self.generation };

        try self.entries.append(self.allocator, .{ .text = owned, .id = id });
        try self.lookup.put(owned, index);

        return id;
    }

    pub fn lookupId(self: *Interner, id: StringId) ?[]const u8 {
        if (id.index >= self.entries.items.len) return null;
        if (id.generation != self.generation) return null;
        return self.entries.items[id.index].text;
    }

    pub fn contains(self: *Interner, text: []const u8) bool {
        return self.lookup.contains(text);
    }

    pub fn count(self: Interner) usize {
        return self.entries.items.len;
    }

    pub fn clear(self: *Interner) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.text);
        }
        self.entries.clearRetainingCapacity();
        self.lookup.clearRetainingCapacity();
        self.generation += 1;
    }
};

pub const StaticInterner = struct {
    strings: []const []const u8,

    pub fn init(strings: []const []const u8) StaticInterner {
        return .{ .strings = strings };
    }

    pub fn find(self: StaticInterner, text: []const u8) ?u32 {
        for (self.strings, 0..) |s, i| {
            if (std.mem.eql(u8, s, text)) return @intCast(i);
        }
        return null;
    }

    pub fn at(self: StaticInterner, index: u32) ?[]const u8 {
        if (index >= self.strings.len) return null;
        return self.strings[index];
    }

    pub fn count(self: StaticInterner) usize {
        return self.strings.len;
    }
};

pub const COMMON_STRINGS = [_][]const u8{
    "length",
    "name",
    "prototype",
    "constructor",
    "toString",
    "valueOf",
    "undefined",
    "null",
    "true",
    "false",
    "NaN",
    "Infinity",
    "Object",
    "Array",
    "Function",
    "String",
    "Number",
    "Boolean",
    "Symbol",
    "BigInt",
    "Error",
    "TypeError",
    "RangeError",
    "ReferenceError",
    "SyntaxError",
    "EvalError",
    "URIError",
    "Promise",
    "Map",
    "Set",
    "WeakMap",
    "WeakSet",
    "Date",
    "RegExp",
    "JSON",
    "Math",
    "console",
    "log",
    "warn",
    "error",
};

test "intern basic" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const id = try interner.intern("hello");
    try std.testing.expectEqual(@as(u32, 0), id.index);
    try std.testing.expectEqual(@as(u32, 1), id.generation);
}

test "intern deduplicates" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const id1 = try interner.intern("hello");
    const id2 = try interner.intern("hello");
    try std.testing.expect(id1.eql(id2));
    try std.testing.expectEqual(@as(usize, 1), interner.count());
}

test "intern different strings" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const id1 = try interner.intern("hello");
    const id2 = try interner.intern("world");
    try std.testing.expect(!id1.eql(id2));
    try std.testing.expectEqual(@as(usize, 2), interner.count());
}

test "lookupId" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const id = try interner.intern("hello");
    const text = interner.lookupId(id).?;
    try std.testing.expectEqualStrings("hello", text);
}

test "lookupId invalid" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const bad = StringId{ .index = 999, .generation = 1 };
    try std.testing.expect(interner.lookupId(bad) == null);
}

test "lookupId wrong generation" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const id = try interner.intern("hello");
    interner.clear();

    try std.testing.expect(interner.lookupId(id) == null);
}

test "contains" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    _ = try interner.intern("hello");
    try std.testing.expect(interner.contains("hello"));
    try std.testing.expect(!interner.contains("world"));
}

test "clear" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    _ = try interner.intern("hello");
    _ = try interner.intern("world");
    try std.testing.expectEqual(@as(usize, 2), interner.count());

    interner.clear();
    try std.testing.expectEqual(@as(usize, 0), interner.count());
    try std.testing.expect(!interner.contains("hello"));
}

test "clear bumps generation" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    const before = interner.generation;
    interner.clear();
    try std.testing.expectEqual(before + 1, interner.generation);
}

test "many interns" {
    var interner = Interner.init(std.testing.allocator);
    defer interner.deinit();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var buf: [16]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "str{d}", .{i});
        _ = try interner.intern(s);
    }
    try std.testing.expectEqual(@as(usize, 100), interner.count());
}

test "StringId eql" {
    const a = StringId{ .index = 1, .generation = 1 };
    const b = StringId{ .index = 1, .generation = 1 };
    const c = StringId{ .index = 2, .generation = 1 };
    const d = StringId{ .index = 1, .generation = 2 };
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
    try std.testing.expect(!a.eql(d));
}

test "StaticInterner find" {
    const interner = StaticInterner.init(&COMMON_STRINGS);
    try std.testing.expectEqual(@as(?u32, 0), interner.find("length"));
    try std.testing.expectEqual(@as(?u32, 1), interner.find("name"));
    try std.testing.expect(interner.find("nonexistent") == null);
}

test "StaticInterner at" {
    const interner = StaticInterner.init(&COMMON_STRINGS);
    try std.testing.expectEqualStrings("length", interner.at(0).?);
    try std.testing.expectEqualStrings("name", interner.at(1).?);
    try std.testing.expect(interner.at(9999) == null);
}

test "StaticInterner count" {
    const interner = StaticInterner.init(&COMMON_STRINGS);
    try std.testing.expectEqual(COMMON_STRINGS.len, interner.count());
}
