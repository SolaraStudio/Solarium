const std = @import("std");
const value_mod = @import("../values/value.zig");
const heap_mod = @import("heap.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Heap = heap_mod.Heap;
pub const ObjectKind = heap_mod.ObjectKind;

pub const CompactError = error{
    OutOfMemory,
    InvalidObject,
    FragmentationDetected,
    NoFragmentation,
};

pub const CompactPolicy = enum(u8) {
    never,
    on_demand,
    when_fragmented,
    always,

    pub fn toString(self: CompactPolicy) []const u8 {
        return @tagName(self);
    }

    pub fn isAutomatic(self: CompactPolicy) bool {
        return self == .when_fragmented or self == .always;
    }

    pub fn isManual(self: CompactPolicy) bool {
        return self == .on_demand;
    }
};

pub const MoveRecord = struct {
    from_addr: usize,
    to_addr: usize,
    size: u64,
    kind: ObjectKind,

    pub fn init(from_addr: usize, to_addr: usize, size: u64, kind: ObjectKind) MoveRecord {
        return .{
            .from_addr = from_addr,
            .to_addr = to_addr,
            .size = size,
            .kind = kind,
        };
    }
};

pub const CompactStats = struct {
    objects_moved: usize = 0,
    objects_pinned: usize = 0,
    bytes_moved: u64 = 0,
    bytes_reclaimed: u64 = 0,
    fragmentation_before: f64 = 0.0,
    fragmentation_after: f64 = 0.0,

    pub fn init() CompactStats {
        return .{};
    }

    pub fn recordMove(self: *CompactStats, size: u64) void {
        self.objects_moved += 1;
        self.bytes_moved += size;
    }

    pub fn recordPinned(self: *CompactStats) void {
        self.objects_pinned += 1;
    }

    pub fn savedBytes(self: CompactStats) u64 {
        return self.bytes_reclaimed;
    }

    pub fn improvedFragmentation(self: CompactStats) f64 {
        return self.fragmentation_before - self.fragmentation_after;
    }
};

pub const CompactResult = struct {
    moved: usize,
    pinned: usize,
    bytes_moved: u64,
    bytes_reclaimed: u64,

    pub fn init() CompactResult {
        return .{
            .moved = 0,
            .pinned = 0,
            .bytes_moved = 0,
            .bytes_reclaimed = 0,
        };
    }

    pub fn nothingMoved(self: CompactResult) bool {
        return self.moved == 0;
    }
};

pub const Compactor = struct {
    allocator: std.mem.Allocator,
    heap: *Heap,
    stats: CompactStats,
    policy: CompactPolicy,
    moves: std.ArrayList(MoveRecord),
    fragmentation_threshold: f64,

    pub fn init(allocator: std.mem.Allocator, heap: *Heap) Compactor {
        return .{
            .allocator = allocator,
            .heap = heap,
            .stats = CompactStats.init(),
            .policy = .on_demand,
            .moves = .empty,
            .fragmentation_threshold = 0.25,
        };
    }

    pub fn deinit(self: *Compactor) void {
        self.moves.deinit(self.allocator);
    }

    pub fn reset(self: *Compactor) void {
        self.stats = CompactStats.init();
        self.moves.clearRetainingCapacity();
    }

    pub fn setPolicy(self: *Compactor, policy: CompactPolicy) void {
        self.policy = policy;
    }

    pub fn setThreshold(self: *Compactor, threshold: f64) void {
        self.fragmentation_threshold = std.math.clamp(threshold, 0.0, 1.0);
    }

    pub fn fragmentation(self: Compactor) f64 {
        const total_blocks = self.heap.blocks.items.len;
        if (total_blocks == 0) return 0.0;

        var free_blocks: usize = 0;
        for (self.heap.blocks.items) |b| {
            if (b.free) free_blocks += 1;
        }

        return @as(f64, @floatFromInt(free_blocks)) /
            @as(f64, @floatFromInt(total_blocks));
    }

    pub fn isFragmented(self: Compactor) bool {
        return self.fragmentation() > self.fragmentation_threshold;
    }

    pub fn shouldCompact(self: Compactor) bool {
        return switch (self.policy) {
            .never => false,
            .always => true,
            .on_demand => false,
            .when_fragmented => self.isFragmented(),
        };
    }

    pub fn compact(self: *Compactor) CompactError!CompactResult {
        self.reset();

        self.stats.fragmentation_before = self.fragmentation();

        var result = CompactResult.init();

        var it = self.heap.header_map.iterator();
        while (it.next()) |entry| {
            const header = entry.value_ptr.*;
            if (!header.isMarked()) continue;
            if (header.isPinned()) {
                self.stats.recordPinned();
                result.pinned += 1;
                continue;
            }
            self.stats.recordMove(header.size);
            result.moved += 1;
            result.bytes_moved += header.size;
        }

        self.heap.compact();

        self.stats.fragmentation_after = self.fragmentation();

        result.bytes_reclaimed = self.stats.savedBytes();

        return result;
    }

    pub fn compactIfNeeded(self: *Compactor) CompactError!?CompactResult {
        if (!self.shouldCompact()) return null;
        return try self.compact();
    }

    pub fn moveRecord(self: *Compactor, from: usize, to: usize, size: u64, kind: ObjectKind) !void {
        try self.moves.append(self.allocator, MoveRecord.init(from, to, size, kind));
    }

    pub fn moveCount(self: Compactor) usize {
        return self.moves.items.len;
    }

    pub fn getStats(self: Compactor) CompactStats {
        return self.stats;
    }

    pub fn isDone(self: Compactor) bool {
        return !self.isFragmented();
    }
};

pub fn createCompactor(allocator: std.mem.Allocator, heap: *Heap) !*Compactor {
    const c = try allocator.create(Compactor);
    c.* = Compactor.init(allocator, heap);
    return c;
}

pub fn destroyCompactor(c: *Compactor) void {
    const allocator = c.allocator;
    c.deinit();
    allocator.destroy(c);
}

pub fn canMove(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return false;
    return !h.isPinned();
}

pub fn shouldMove(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return false;
    return h.isMarked() and !h.isPinned();
}

test "CompactPolicy toString" {
    try std.testing.expectEqualStrings("never", CompactPolicy.never.toString());
    try std.testing.expectEqualStrings("on_demand", CompactPolicy.on_demand.toString());
    try std.testing.expectEqualStrings("when_fragmented", CompactPolicy.when_fragmented.toString());
    try std.testing.expectEqualStrings("always", CompactPolicy.always.toString());
}

test "CompactPolicy isAutomatic" {
    try std.testing.expect(CompactPolicy.when_fragmented.isAutomatic());
    try std.testing.expect(CompactPolicy.always.isAutomatic());
    try std.testing.expect(!CompactPolicy.never.isAutomatic());
}

test "CompactPolicy isManual" {
    try std.testing.expect(CompactPolicy.on_demand.isManual());
    try std.testing.expect(!CompactPolicy.always.isManual());
}

test "MoveRecord init" {
    const r = MoveRecord.init(100, 200, 64, .plain_object);
    try std.testing.expectEqual(@as(usize, 100), r.from_addr);
    try std.testing.expectEqual(@as(usize, 200), r.to_addr);
    try std.testing.expectEqual(@as(u64, 64), r.size);
}

test "CompactStats init" {
    const s = CompactStats.init();
    try std.testing.expectEqual(@as(usize, 0), s.objects_moved);
    try std.testing.expectEqual(@as(u64, 0), s.bytes_moved);
}

test "CompactStats recordMove" {
    var s = CompactStats.init();
    s.recordMove(100);
    s.recordMove(50);
    try std.testing.expectEqual(@as(usize, 2), s.objects_moved);
    try std.testing.expectEqual(@as(u64, 150), s.bytes_moved);
}

test "CompactStats recordPinned" {
    var s = CompactStats.init();
    s.recordPinned();
    try std.testing.expectEqual(@as(usize, 1), s.objects_pinned);
}

test "CompactStats improvedFragmentation" {
    var s = CompactStats.init();
    s.fragmentation_before = 0.5;
    s.fragmentation_after = 0.1;
    try std.testing.expectEqual(@as(f64, 0.4), s.improvedFragmentation());
}

test "CompactResult init" {
    const r = CompactResult.init();
    try std.testing.expect(r.nothingMoved());
}

test "Compactor init" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    try std.testing.expectEqual(@as(usize, 0), c.moveCount());
    try std.testing.expectEqual(CompactPolicy.on_demand, c.policy);
}

test "Compactor setPolicy" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setPolicy(.always);
    try std.testing.expectEqual(CompactPolicy.always, c.policy);
}

test "Compactor setThreshold" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setThreshold(0.5);
    try std.testing.expectEqual(@as(f64, 0.5), c.fragmentation_threshold);
}

test "Compactor setThreshold clamps" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setThreshold(5.0);
    try std.testing.expectEqual(@as(f64, 1.0), c.fragmentation_threshold);
}

test "Compactor fragmentation empty" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), c.fragmentation());
}

test "Compactor isFragmented" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    try std.testing.expect(!c.isFragmented());
}

test "Compactor shouldCompact never" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setPolicy(.never);
    try std.testing.expect(!c.shouldCompact());
}

test "Compactor shouldCompact always" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setPolicy(.always);
    try std.testing.expect(c.shouldCompact());
}

test "Compactor compact empty" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    const r = try c.compact();
    try std.testing.expect(r.nothingMoved());
}

test "Compactor compact single marked" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 64);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    _ = h.markObject(alloc.toObject());

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    const r = try c.compact();
    try std.testing.expectEqual(@as(usize, 1), r.moved);
}

test "Compactor compact skips pinned" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 64);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    _ = h.markObject(alloc.toObject());
    _ = h.pinObject(alloc.toObject());

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    const r = try c.compact();
    try std.testing.expectEqual(@as(usize, 0), r.moved);
    try std.testing.expectEqual(@as(usize, 1), r.pinned);
}

test "Compactor compactIfNeeded policy never" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setPolicy(.never);
    const r = try c.compactIfNeeded();
    try std.testing.expect(r == null);
}

test "Compactor compactIfNeeded policy always" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    c.setPolicy(.always);
    const r = try c.compactIfNeeded();
    try std.testing.expect(r != null);
}

test "Compactor moveRecord" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    try c.moveRecord(100, 200, 64, .plain_object);
    try std.testing.expectEqual(@as(usize, 1), c.moveCount());
}

test "Compactor isDone empty" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var c = Compactor.init(std.testing.allocator, &h);
    defer c.deinit();

    try std.testing.expect(c.isDone());
}

test "canMove shouldMove" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    try std.testing.expect(canMove(alloc.toObject(), &h));
    try std.testing.expect(!shouldMove(alloc.toObject(), &h));

    _ = h.markObject(alloc.toObject());
    try std.testing.expect(shouldMove(alloc.toObject(), &h));
}

test "createCompactor and destroyCompactor" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const c = try createCompactor(std.testing.allocator, &h);
    destroyCompactor(c);
}
