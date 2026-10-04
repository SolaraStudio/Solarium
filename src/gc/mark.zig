const std = @import("std");
const value_mod = @import("../values/value.zig");
const object_mod = @import("../objects/object.zig");
const heap_mod = @import("heap.zig");
const root_mod = @import("root.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Heap = heap_mod.Heap;
pub const ObjectKind = heap_mod.ObjectKind;
pub const RootSet = root_mod.RootSet;

pub const MarkError = error{
    OutOfMemory,
    InvalidObject,
    RecursionLimitExceeded,
};

pub const MAX_MARK_DEPTH: usize = 4096;
pub const MARK_STACK_INITIAL: usize = 256;

pub const Color = enum(u8) {
    white,
    grey,
    black,

    pub fn toString(self: Color) []const u8 {
        return @tagName(self);
    }

    pub fn isWhite(self: Color) bool {
        return self == .white;
    }

    pub fn isGrey(self: Color) bool {
        return self == .grey;
    }

    pub fn isBlack(self: Color) bool {
        return self == .black;
    }
};

pub const MarkStack = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(*Object),
    max_depth: usize,

    pub fn init(allocator: std.mem.Allocator) MarkStack {
        return .{
            .allocator = allocator,
            .items = .empty,
            .max_depth = MAX_MARK_DEPTH,
        };
    }

    pub fn deinit(self: *MarkStack) void {
        self.items.deinit(self.allocator);
    }

    pub fn push(self: *MarkStack, obj: *Object) MarkError!void {
        if (self.items.items.len >= self.max_depth) {
            return MarkError.RecursionLimitExceeded;
        }
        try self.items.append(self.allocator, obj);
    }

    pub fn pop(self: *MarkStack) ?*Object {
        return self.items.pop();
    }

    pub fn depth(self: MarkStack) usize {
        return self.items.items.len;
    }

    pub fn isEmpty(self: MarkStack) bool {
        return self.items.items.len == 0;
    }

    pub fn clear(self: *MarkStack) void {
        self.items.clearRetainingCapacity();
    }
};

pub const MarkStats = struct {
    objects_marked: usize = 0,
    objects_scanned: usize = 0,
    max_stack_depth: usize = 0,
    edges_traversed: usize = 0,

    pub fn init() MarkStats {
        return .{};
    }

    pub fn recordMark(self: *MarkStats) void {
        self.objects_marked += 1;
    }

    pub fn recordScan(self: *MarkStats) void {
        self.objects_scanned += 1;
    }

    pub fn recordEdge(self: *MarkStats) void {
        self.edges_traversed += 1;
    }

    pub fn recordDepth(self: *MarkStats, depth: usize) void {
        if (depth > self.max_stack_depth) {
            self.max_stack_depth = depth;
        }
    }
};

pub const Marker = struct {
    allocator: std.mem.Allocator,
    heap: *Heap,
    stack: MarkStack,
    stats: MarkStats,

    pub fn init(allocator: std.mem.Allocator, heap: *Heap) Marker {
        return .{
            .allocator = allocator,
            .heap = heap,
            .stack = MarkStack.init(allocator),
            .stats = MarkStats.init(),
        };
    }

    pub fn deinit(self: *Marker) void {
        self.stack.deinit();
    }

    pub fn reset(self: *Marker) void {
        self.stack.clear();
        self.stats = MarkStats.init();
    }

    pub fn markValue(self: *Marker, value: Value) MarkError!void {
        if (!value.isObject()) return;
        const obj = value.asObject().?;
        try self.markObject(@ptrCast(@alignCast(obj)));
    }

    pub fn markObject(self: *Marker, obj: *Object) MarkError!void {
        if (!self.heap.markObject(obj)) return;
        self.stats.recordMark();
        try self.stack.push(obj);
    }

    pub fn markRoots(self: *Marker, roots: *RootSet) MarkError!void {
        var visitor = RootVisitor{ .marker = self };
        roots.visitAll(&visitor);
    }

    pub fn process(self: *Marker) MarkError!void {
        while (self.stack.pop()) |obj| {
            self.stats.recordScan();
            self.stats.recordDepth(self.stack.depth());
            try self.scanObject(obj);
        }
    }

    pub fn scanObject(self: *Marker, obj: *Object) MarkError!void {
        _ = self;
        _ = obj;
    }

    pub fn run(self: *Marker, roots: *RootSet) MarkError!void {
        self.reset();
        try self.markRoots(roots);
        try self.process();
    }

    pub fn markedCount(self: Marker) usize {
        return self.stats.objects_marked;
    }

    pub fn getStats(self: Marker) MarkStats {
        return self.stats;
    }
};

pub const RootVisitor = struct {
    marker: *Marker,

    pub fn visit(self: *RootVisitor, value: Value) void {
        self.marker.markValue(value) catch {};
    }
};

pub fn createMarker(allocator: std.mem.Allocator, heap: *Heap) !*Marker {
    const m = try allocator.create(Marker);
    m.* = Marker.init(allocator, heap);
    return m;
}

pub fn destroyMarker(m: *Marker) void {
    const allocator = m.allocator;
    m.deinit();
    allocator.destroy(m);
}

pub fn isWhite(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return true;
    return !h.isMarked();
}

pub fn isBlack(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return false;
    return h.isMarked();
}

test "Color toString" {
    try std.testing.expectEqualStrings("white", Color.white.toString());
    try std.testing.expectEqualStrings("grey", Color.grey.toString());
    try std.testing.expectEqualStrings("black", Color.black.toString());
}

test "Color predicates" {
    try std.testing.expect(Color.white.isWhite());
    try std.testing.expect(Color.grey.isGrey());
    try std.testing.expect(Color.black.isBlack());
    try std.testing.expect(!Color.white.isBlack());
}

test "MarkStack init" {
    var s = MarkStack.init(std.testing.allocator);
    defer s.deinit();
    try std.testing.expect(s.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), s.depth());
}

test "MarkStack push and pop" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var s = MarkStack.init(std.testing.allocator);
    defer s.deinit();

    try s.push(alloc.toObject());
    try std.testing.expectEqual(@as(usize, 1), s.depth());

    const popped = s.pop();
    try std.testing.expect(popped != null);
    try std.testing.expect(s.isEmpty());
}

test "MarkStats init" {
    const s = MarkStats.init();
    try std.testing.expectEqual(@as(usize, 0), s.objects_marked);
}

test "MarkStats recordMark" {
    var s = MarkStats.init();
    s.recordMark();
    s.recordMark();
    try std.testing.expectEqual(@as(usize, 2), s.objects_marked);
}

test "MarkStats recordDepth" {
    var s = MarkStats.init();
    s.recordDepth(5);
    s.recordDepth(10);
    s.recordDepth(3);
    try std.testing.expectEqual(@as(usize, 10), s.max_stack_depth);
}

test "Marker init" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try std.testing.expectEqual(@as(usize, 0), m.markedCount());
}

test "Marker markObject" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.markObject(alloc.toObject());
    try std.testing.expectEqual(@as(usize, 1), m.markedCount());
}

test "Marker markObject twice" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.markObject(alloc.toObject());
    try m.markObject(alloc.toObject());
    try std.testing.expectEqual(@as(usize, 1), m.markedCount());
}

test "Marker markValue non-object" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.markValue(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 0), m.markedCount());
}

test "Marker process" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.markObject(alloc.toObject());
    try m.process();
    try std.testing.expectEqual(@as(usize, 0), m.stack.depth());
}

test "Marker run with empty roots" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var roots = RootSet.init(std.testing.allocator);
    defer roots.deinit();

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.run(&roots);
    try std.testing.expectEqual(@as(usize, 0), m.markedCount());
}

test "Marker reset" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var m = Marker.init(std.testing.allocator, &h);
    defer m.deinit();

    try m.markObject(alloc.toObject());
    m.reset();
    try std.testing.expectEqual(@as(usize, 0), m.markedCount());
}

test "isWhite isBlack" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    try std.testing.expect(isWhite(alloc.toObject(), &h));
    try std.testing.expect(!isBlack(alloc.toObject(), &h));

    _ = h.markObject(alloc.toObject());
    try std.testing.expect(!isWhite(alloc.toObject(), &h));
    try std.testing.expect(isBlack(alloc.toObject(), &h));
}

test "createMarker and destroyMarker" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const m = try createMarker(std.testing.allocator, &h);
    destroyMarker(m);
}

test "MAX_MARK_DEPTH" {
    try std.testing.expectEqual(@as(usize, 4096), MAX_MARK_DEPTH);
}

test "MARK_STACK_INITIAL" {
    try std.testing.expectEqual(@as(usize, 256), MARK_STACK_INITIAL);
}
