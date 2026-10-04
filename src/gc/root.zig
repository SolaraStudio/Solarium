const std = @import("std");
const value_mod = @import("../values/value.zig");

pub const Value = value_mod.Value;

pub const RootKind = enum(u8) {
    stack,
    frame,
    global,
    temporary,
    handler,
    module,
    native,
    weak,
    pinned,

    pub fn toString(self: RootKind) []const u8 {
        return @tagName(self);
    }

    pub fn isStrong(self: RootKind) bool {
        return self != .weak;
    }

    pub fn isWeak(self: RootKind) bool {
        return self == .weak;
    }

    pub fn isPinned(self: RootKind) bool {
        return self == .pinned;
    }

    pub fn isTemporary(self: RootKind) bool {
        return self == .temporary;
    }
};

pub const RootEntry = struct {
    value: Value,
    kind: RootKind,
    tag: u32,
    marked: bool,

    pub fn init(value: Value, kind: RootKind) RootEntry {
        return .{
            .value = value,
            .kind = kind,
            .tag = 0,
            .marked = false,
        };
    }

    pub fn withTag(self: RootEntry, tag: u32) RootEntry {
        var r = self;
        r.tag = tag;
        return r;
    }

    pub fn mark(self: *RootEntry) void {
        self.marked = true;
    }

    pub fn unmark(self: *RootEntry) void {
        self.marked = false;
    }
};

pub const RootRange = struct {
    values: []Value,
    kind: RootKind,
    tag: u32,

    pub fn init(values: []Value, kind: RootKind) RootRange {
        return .{
            .values = values,
            .kind = kind,
            .tag = 0,
        };
    }

    pub fn withTag(self: RootRange, tag: u32) RootRange {
        var r = self;
        r.tag = tag;
        return r;
    }

    pub fn count(self: RootRange) usize {
        return self.values.len;
    }

    pub fn iter(self: RootRange) Iterator {
        return Iterator{ .range = self, .index = 0 };
    }

    pub const Iterator = struct {
        range: RootRange,
        index: usize,

        pub fn next(self: *Iterator) ?Value {
            if (self.index >= self.range.values.len) return null;
            const v = self.range.values[self.index];
            self.index += 1;
            return v;
        }
    };
};

pub const RootSet = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(RootEntry),
    ranges: std.ArrayList(RootRange),
    pinned: std.ArrayList(Value),
    max_entries: usize,

    pub fn init(allocator: std.mem.Allocator) RootSet {
        return .{
            .allocator = allocator,
            .entries = .empty,
            .ranges = .empty,
            .pinned = .empty,
            .max_entries = 65536,
        };
    }

    pub fn deinit(self: *RootSet) void {
        self.entries.deinit(self.allocator);
        self.ranges.deinit(self.allocator);
        self.pinned.deinit(self.allocator);
    }

    pub fn entryCount(self: RootSet) usize {
        return self.entries.items.len;
    }

    pub fn rangeCount(self: RootSet) usize {
        return self.ranges.items.len;
    }

    pub fn pinnedCount(self: RootSet) usize {
        return self.pinned.items.len;
    }

    pub fn add(self: *RootSet, value: Value, kind: RootKind) !void {
        if (self.entries.items.len >= self.max_entries) {
            return error.RootSetFull;
        }
        try self.entries.append(self.allocator, RootEntry.init(value, kind));
    }

    pub fn addTagged(self: *RootSet, value: Value, kind: RootKind, tag: u32) !void {
        if (self.entries.items.len >= self.max_entries) {
            return error.RootSetFull;
        }
        try self.entries.append(self.allocator, RootEntry.init(value, kind).withTag(tag));
    }

    pub fn addRange(self: *RootSet, range: RootRange) !void {
        try self.ranges.append(self.allocator, range);
    }

    pub fn addStackRange(self: *RootSet, values: []Value) !void {
        try self.addRange(RootRange.init(values, .stack));
    }

    pub fn pin(self: *RootSet, value: Value) !void {
        try self.pinned.append(self.allocator, value);
    }

    pub fn unpin(self: *RootSet, value: Value) void {
        var i: usize = self.pinned.items.len;
        while (i > 0) {
            i -= 1;
            if (self.pinned.items[i].strictEquals(value)) {
                _ = self.pinned.orderedRemove(i);
                return;
            }
        }
    }

    pub fn isPinned(self: RootSet, value: Value) bool {
        for (self.pinned.items) |p| {
            if (p.strictEquals(value)) return true;
        }
        return false;
    }

    pub fn clear(self: *RootSet) void {
        self.entries.clearRetainingCapacity();
        self.ranges.clearRetainingCapacity();
        self.pinned.clearRetainingCapacity();
    }

    pub fn clearTemporaries(self: *RootSet) void {
        var i: usize = self.entries.items.len;
        while (i > 0) {
            i -= 1;
            if (self.entries.items[i].kind == .temporary) {
                _ = self.entries.orderedRemove(i);
            }
        }
    }

    pub fn markAll(self: *RootSet) void {
        for (self.entries.items) |*e| {
            e.mark();
        }
    }

    pub fn unmarkAll(self: *RootSet) void {
        for (self.entries.items) |*e| {
            e.unmark();
        }
    }

    pub fn visitEntries(self: *RootSet, visitor: anytype) void {
        for (self.entries.items) |e| {
            if (e.kind.isStrong()) {
                visitor.visit(e.value);
            }
        }
    }

    pub fn visitRanges(self: *RootSet, visitor: anytype) void {
        for (self.ranges.items) |range| {
            if (!range.kind.isStrong()) continue;
            var it = range.iter();
            while (it.next()) |v| {
                visitor.visit(v);
            }
        }
    }

    pub fn visitPinned(self: *RootSet, visitor: anytype) void {
        for (self.pinned.items) |v| {
            visitor.visit(v);
        }
    }

    pub fn visitAll(self: *RootSet, visitor: anytype) void {
        self.visitEntries(visitor);
        self.visitRanges(visitor);
        self.visitPinned(visitor);
    }
};

pub const RootGuard = struct {
    roots: *RootSet,
    value: Value,
    added: bool,

    pub fn init(roots: *RootSet, value: Value) RootGuard {
        return .{
            .roots = roots,
            .value = value,
            .added = false,
        };
    }

    pub fn protect(self: *RootGuard) !void {
        if (self.added) return;
        try self.roots.add(self.value, .temporary);
        self.added = true;
    }

    pub fn release(self: *RootGuard) void {
        if (!self.added) return;
        self.roots.clearTemporaries();
        self.added = false;
    }
};

pub fn createRootSet(allocator: std.mem.Allocator) !*RootSet {
    const rs = try allocator.create(RootSet);
    rs.* = RootSet.init(allocator);
    return rs;
}

pub fn destroyRootSet(rs: *RootSet) void {
    const allocator = rs.allocator;
    rs.deinit();
    allocator.destroy(rs);
}

pub const CountingVisitor = struct {
    count: usize,

    pub fn init() CountingVisitor {
        return .{ .count = 0 };
    }

    pub fn visit(self: *CountingVisitor, value: Value) void {
        _ = value;
        self.count += 1;
    }
};

test "RootKind toString" {
    try std.testing.expectEqualStrings("stack", RootKind.stack.toString());
    try std.testing.expectEqualStrings("global", RootKind.global.toString());
}

test "RootKind isStrong" {
    try std.testing.expect(RootKind.stack.isStrong());
    try std.testing.expect(!RootKind.weak.isStrong());
}

test "RootKind isWeak" {
    try std.testing.expect(RootKind.weak.isWeak());
    try std.testing.expect(!RootKind.stack.isWeak());
}

test "RootKind isPinned" {
    try std.testing.expect(RootKind.pinned.isPinned());
    try std.testing.expect(!RootKind.stack.isPinned());
}

test "RootEntry init" {
    const e = RootEntry.init(Value.TRUE, .stack);
    try std.testing.expect(e.kind == .stack);
    try std.testing.expect(!e.marked);
}

test "RootEntry withTag" {
    const e = RootEntry.init(Value.TRUE, .stack).withTag(42);
    try std.testing.expectEqual(@as(u32, 42), e.tag);
}

test "RootEntry mark and unmark" {
    var e = RootEntry.init(Value.TRUE, .stack);
    e.mark();
    try std.testing.expect(e.marked);
    e.unmark();
    try std.testing.expect(!e.marked);
}

test "RootRange init" {
    var values = [_]Value{ Value.TRUE, Value.FALSE };
    const r = RootRange.init(&values, .stack);
    try std.testing.expectEqual(@as(usize, 2), r.count());
}

test "RootRange withTag" {
    var values = [_]Value{Value.TRUE};
    const r = RootRange.init(&values, .stack).withTag(10);
    try std.testing.expectEqual(@as(u32, 10), r.tag);
}

test "RootRange Iterator" {
    var values = [_]Value{ Value.fromNumber(1.0), Value.fromNumber(2.0) };
    const r = RootRange.init(&values, .stack);
    var it = r.iter();

    const v1 = it.next().?;
    const v2 = it.next().?;
    try std.testing.expectEqual(@as(f64, 1.0), v1.asNumber().?);
    try std.testing.expectEqual(@as(f64, 2.0), v2.asNumber().?);
    try std.testing.expect(it.next() == null);
}

test "RootSet init" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();
    try std.testing.expectEqual(@as(usize, 0), rs.entryCount());
}

test "RootSet add" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    try std.testing.expectEqual(@as(usize, 1), rs.entryCount());
}

test "RootSet addTagged" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.addTagged(Value.TRUE, .frame, 42);
    try std.testing.expectEqual(@as(u32, 42), rs.entries.items[0].tag);
}

test "RootSet addRange" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    var values = [_]Value{Value.TRUE};
    try rs.addRange(RootRange.init(&values, .stack));
    try std.testing.expectEqual(@as(usize, 1), rs.rangeCount());
}

test "RootSet pin and unpin" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.pin(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), rs.pinnedCount());
    try std.testing.expect(rs.isPinned(Value.TRUE));

    rs.unpin(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 0), rs.pinnedCount());
}

test "RootSet isPinned false" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try std.testing.expect(!rs.isPinned(Value.TRUE));
}

test "RootSet clear" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    try rs.pin(Value.FALSE);
    rs.clear();

    try std.testing.expectEqual(@as(usize, 0), rs.entryCount());
    try std.testing.expectEqual(@as(usize, 0), rs.pinnedCount());
}

test "RootSet clearTemporaries" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    try rs.add(Value.FALSE, .temporary);
    try rs.add(Value.fromNumber(1.0), .temporary);

    rs.clearTemporaries();
    try std.testing.expectEqual(@as(usize, 1), rs.entryCount());
}

test "RootSet markAll unmarkAll" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    rs.markAll();
    try std.testing.expect(rs.entries.items[0].marked);

    rs.unmarkAll();
    try std.testing.expect(!rs.entries.items[0].marked);
}

test "RootSet visitEntries" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    try rs.add(Value.FALSE, .global);
    try rs.add(Value.fromNumber(1.0), .weak);

    var visitor = CountingVisitor.init();
    rs.visitEntries(&visitor);
    try std.testing.expectEqual(@as(usize, 2), visitor.count);
}

test "RootSet visitRanges" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    var values = [_]Value{ Value.TRUE, Value.FALSE };
    try rs.addRange(RootRange.init(&values, .stack));

    var visitor = CountingVisitor.init();
    rs.visitRanges(&visitor);
    try std.testing.expectEqual(@as(usize, 2), visitor.count);
}

test "RootSet visitPinned" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.pin(Value.TRUE);
    try rs.pin(Value.FALSE);

    var visitor = CountingVisitor.init();
    rs.visitPinned(&visitor);
    try std.testing.expectEqual(@as(usize, 2), visitor.count);
}

test "RootSet visitAll" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    try rs.add(Value.TRUE, .stack);
    try rs.pin(Value.FALSE);

    var values = [_]Value{Value.fromNumber(1.0)};
    try rs.addRange(RootRange.init(&values, .global));

    var visitor = CountingVisitor.init();
    rs.visitAll(&visitor);
    try std.testing.expectEqual(@as(usize, 3), visitor.count);
}

test "RootGuard" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    var guard = RootGuard.init(&rs, Value.TRUE);
    try guard.protect();
    try std.testing.expectEqual(@as(usize, 1), rs.entryCount());

    guard.release();
    try std.testing.expectEqual(@as(usize, 0), rs.entryCount());
}

test "RootGuard double protect" {
    var rs = RootSet.init(std.testing.allocator);
    defer rs.deinit();

    var guard = RootGuard.init(&rs, Value.TRUE);
    try guard.protect();
    try guard.protect();
    try std.testing.expectEqual(@as(usize, 1), rs.entryCount());
}

test "createRootSet and destroyRootSet" {
    const rs = try createRootSet(std.testing.allocator);
    destroyRootSet(rs);
}
