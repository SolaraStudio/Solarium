const std = @import("std");
const value_mod = @import("../values/value.zig");
const heap_mod = @import("heap.zig");
const stats_mod = @import("stats.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Heap = heap_mod.Heap;
pub const ObjectKind = heap_mod.ObjectKind;
pub const Stats = stats_mod.Stats;

pub const SweepError = error{
    OutOfMemory,
    InvalidObject,
    ConcurrentModification,
};

pub const SweepPolicy = enum(u8) {
    eager,
    lazy,
    incremental,

    pub fn toString(self: SweepPolicy) []const u8 {
        return @tagName(self);
    }

    pub fn isEager(self: SweepPolicy) bool {
        return self == .eager;
    }

    pub fn isLazy(self: SweepPolicy) bool {
        return self == .lazy;
    }

    pub fn isIncremental(self: SweepPolicy) bool {
        return self == .incremental;
    }
};

pub const SweepStats = struct {
    objects_swept: usize = 0,
    objects_freed: usize = 0,
    objects_survived: usize = 0,
    bytes_freed: u64 = 0,
    bytes_survived: u64 = 0,

    pub fn init() SweepStats {
        return .{};
    }

    pub fn recordSweep(self: *SweepStats, size: u64, freed: bool) void {
        self.objects_swept += 1;
        if (freed) {
            self.objects_freed += 1;
            self.bytes_freed += size;
        } else {
            self.objects_survived += 1;
            self.bytes_survived += size;
        }
    }

    pub fn freeRatio(self: SweepStats) f64 {
        if (self.objects_swept == 0) return 0;
        return @as(f64, @floatFromInt(self.objects_freed)) /
            @as(f64, @floatFromInt(self.objects_swept));
    }

    pub fn totalBytes(self: SweepStats) u64 {
        return self.bytes_freed + self.bytes_survived;
    }
};

pub const DeadObject = struct {
    ptr: *Object,
    size: u64,
    kind: ObjectKind,

    pub fn init(ptr: *Object, size: u64, kind: ObjectKind) DeadObject {
        return .{
            .ptr = ptr,
            .size = size,
            .kind = kind,
        };
    }
};

pub const Sweeper = struct {
    allocator: std.mem.Allocator,
    heap: *Heap,
    stats: SweepStats,
    policy: SweepPolicy,
    dead: std.ArrayList(DeadObject),
    max_dead: usize,

    pub fn init(allocator: std.mem.Allocator, heap: *Heap) Sweeper {
        return .{
            .allocator = allocator,
            .heap = heap,
            .stats = SweepStats.init(),
            .policy = .eager,
            .dead = .empty,
            .max_dead = 65536,
        };
    }

    pub fn deinit(self: *Sweeper) void {
        self.dead.deinit(self.allocator);
    }

    pub fn reset(self: *Sweeper) void {
        self.stats = SweepStats.init();
        self.dead.clearRetainingCapacity();
    }

    pub fn setPolicy(self: *Sweeper, policy: SweepPolicy) void {
        self.policy = policy;
    }

    pub fn collectDead(self: *Sweeper) SweepError!void {
        self.dead.clearRetainingCapacity();

        var it = self.heap.header_map.iterator();
        while (it.next()) |entry| {
            const addr = entry.key_ptr.*;
            const header = entry.value_ptr.*;

            if (header.isMarked()) continue;
            if (header.isPinned()) continue;

            const ptr: *Object = @ptrFromInt(addr);
            try self.dead.append(self.allocator, DeadObject.init(ptr, header.size, header.kind));

            if (self.dead.items.len >= self.max_dead) break;
        }
    }

    pub fn sweep(self: *Sweeper) SweepError!void {
        self.reset();
        try self.collectDead();

        for (self.dead.items) |d| {
            self.heap.forceDeallocate(d.ptr) catch {
                continue;
            };
            self.stats.recordSweep(d.size, true);
        }

        var it = self.heap.header_map.iterator();
        var survivors: usize = 0;
        var survivor_bytes: u64 = 0;
        while (it.next()) |entry| {
            const h = entry.value_ptr.*;
            if (h.isMarked()) {
                survivors += 1;
                survivor_bytes += h.size;
            }
        }

        self.stats.objects_survived = survivors;
        self.stats.bytes_survived = survivor_bytes;
    }

    pub fn sweepOne(self: *Sweeper) SweepError!bool {
        var it = self.heap.header_map.iterator();
        while (it.next()) |entry| {
            const addr = entry.key_ptr.*;
            const header = entry.value_ptr.*;

            if (header.isMarked()) continue;
            if (header.isPinned()) continue;

            const ptr: *Object = @ptrFromInt(addr);
            const size = header.size;
            self.heap.forceDeallocate(ptr) catch return false;
            self.stats.recordSweep(size, true);
            return true;
        }
        return false;
    }

    pub fn sweepIncremental(self: *Sweeper, budget: usize) SweepError!usize {
        var freed: usize = 0;
        while (freed < budget) {
            const did_free = try self.sweepOne();
            if (!did_free) break;
            freed += 1;
        }
        return freed;
    }

    pub fn deadCount(self: Sweeper) usize {
        return self.dead.items.len;
    }

    pub fn getStats(self: Sweeper) SweepStats {
        return self.stats;
    }

    pub fn isDone(self: Sweeper) bool {
        var it = self.heap.header_map.valueIterator();
        while (it.next()) |h| {
            if (!h.*.isMarked() and !h.*.isPinned()) return false;
        }
        return true;
    }
};

pub fn createSweeper(allocator: std.mem.Allocator, heap: *Heap) !*Sweeper {
    const s = try allocator.create(Sweeper);
    s.* = Sweeper.init(allocator, heap);
    return s;
}

pub fn destroySweeper(s: *Sweeper) void {
    const allocator = s.allocator;
    s.deinit();
    allocator.destroy(s);
}

pub fn isDead(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return true;
    return !h.isMarked() and !h.isPinned();
}

pub fn isAlive(obj: *Object, heap: *Heap) bool {
    const h = heap.findHeader(obj) orelse return false;
    return h.isMarked() or h.isPinned();
}

test "SweepPolicy toString" {
    try std.testing.expectEqualStrings("eager", SweepPolicy.eager.toString());
    try std.testing.expectEqualStrings("lazy", SweepPolicy.lazy.toString());
    try std.testing.expectEqualStrings("incremental", SweepPolicy.incremental.toString());
}

test "SweepPolicy predicates" {
    try std.testing.expect(SweepPolicy.eager.isEager());
    try std.testing.expect(SweepPolicy.lazy.isLazy());
    try std.testing.expect(SweepPolicy.incremental.isIncremental());
    try std.testing.expect(!SweepPolicy.eager.isLazy());
}

test "SweepStats init" {
    const s = SweepStats.init();
    try std.testing.expectEqual(@as(usize, 0), s.objects_swept);
    try std.testing.expectEqual(@as(u64, 0), s.bytes_freed);
}

test "SweepStats recordSweep freed" {
    var s = SweepStats.init();
    s.recordSweep(100, true);
    try std.testing.expectEqual(@as(usize, 1), s.objects_freed);
    try std.testing.expectEqual(@as(u64, 100), s.bytes_freed);
}

test "SweepStats recordSweep survived" {
    var s = SweepStats.init();
    s.recordSweep(50, false);
    try std.testing.expectEqual(@as(usize, 1), s.objects_survived);
    try std.testing.expectEqual(@as(u64, 50), s.bytes_survived);
}

test "SweepStats freeRatio" {
    var s = SweepStats.init();
    s.recordSweep(100, true);
    s.recordSweep(100, false);
    try std.testing.expectEqual(@as(f64, 0.5), s.freeRatio());
}

test "SweepStats freeRatio empty" {
    const s = SweepStats.init();
    try std.testing.expectEqual(@as(f64, 0.0), s.freeRatio());
}

test "SweepStats totalBytes" {
    var s = SweepStats.init();
    s.recordSweep(100, true);
    s.recordSweep(50, false);
    try std.testing.expectEqual(@as(u64, 150), s.totalBytes());
}

test "DeadObject init" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    const d = DeadObject.init(alloc.toObject(), 32, .plain_object);
    try std.testing.expectEqual(@as(u64, 32), d.size);
    try std.testing.expectEqual(ObjectKind.plain_object, d.kind);
}

test "Sweeper init" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try std.testing.expectEqual(@as(usize, 0), s.deadCount());
    try std.testing.expectEqual(SweepPolicy.eager, s.policy);
}

test "Sweeper setPolicy" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    s.setPolicy(.incremental);
    try std.testing.expectEqual(SweepPolicy.incremental, s.policy);
}

test "Sweeper collectDead" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    const a2 = try h.allocate(.array, 32);
    const a3 = try h.allocate(.string, 32);
    defer {
        h.forceDeallocate(a1.toObject()) catch {};
        h.forceDeallocate(a2.toObject()) catch {};
        h.forceDeallocate(a3.toObject()) catch {};
    }

    _ = h.markObject(a1.toObject());

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try s.collectDead();
    try std.testing.expectEqual(@as(usize, 2), s.deadCount());
}

test "Sweeper collectDead skips marked" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    const a2 = try h.allocate(.array, 32);
    defer {
        h.forceDeallocate(a1.toObject()) catch {};
        h.forceDeallocate(a2.toObject()) catch {};
    }

    _ = h.markObject(a1.toObject());
    _ = h.markObject(a2.toObject());

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try s.collectDead();
    try std.testing.expectEqual(@as(usize, 0), s.deadCount());
}

test "Sweeper collectDead skips pinned" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(a1.toObject()) catch {};

    _ = h.pinObject(a1.toObject());

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try s.collectDead();
    try std.testing.expectEqual(@as(usize, 0), s.deadCount());
}

test "Sweeper sweep" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    const a2 = try h.allocate(.array, 32);
    const a3 = try h.allocate(.string, 32);

    _ = h.markObject(a1.toObject());

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try s.sweep();

    const st = s.getStats();
    try std.testing.expectEqual(@as(usize, 2), st.objects_freed);
    try std.testing.expectEqual(@as(usize, 1), st.objects_survived);
    try std.testing.expectEqual(@as(usize, 1), h.objectCount());

    _ = a2;
    _ = a3;
    h.forceDeallocate(a1.toObject()) catch {};
}

test "Sweeper sweepOne" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    _ = try h.allocate(.plain_object, 32);

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    const did = try s.sweepOne();
    try std.testing.expect(did);
    try std.testing.expectEqual(@as(usize, 0), h.objectCount());
}

test "Sweeper sweepOne empty" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    const did = try s.sweepOne();
    try std.testing.expect(!did);
}

test "Sweeper sweepIncremental" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    _ = try h.allocate(.plain_object, 32);
    _ = try h.allocate(.array, 32);
    _ = try h.allocate(.string, 32);

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    const freed = try s.sweepIncremental(2);
    try std.testing.expectEqual(@as(usize, 2), freed);
    try std.testing.expectEqual(@as(usize, 1), h.objectCount());

    h.reset();
}

test "Sweeper isDone" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    _ = h.markObject(alloc.toObject());

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try std.testing.expect(s.isDone());

    h.reset();

}

test "Sweeper isDone false" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    _ = try h.allocate(.plain_object, 32);

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();

    try std.testing.expect(!s.isDone());

    h.reset();
}

test "isDead isAlive" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    try std.testing.expect(isDead(alloc.toObject(), &h));
    try std.testing.expect(!isAlive(alloc.toObject(), &h));

    _ = h.markObject(alloc.toObject());
    try std.testing.expect(!isDead(alloc.toObject(), &h));
    try std.testing.expect(isAlive(alloc.toObject(), &h));
}

test "createSweeper and destroySweeper" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const s = try createSweeper(std.testing.allocator, &h);
    destroySweeper(s);
}

test "Sweeper max_dead limit" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = try h.allocate(.plain_object, 32);
    }

    var s = Sweeper.init(std.testing.allocator, &h);
    defer s.deinit();
    s.max_dead = 3;

    try s.collectDead();
    try std.testing.expectEqual(@as(usize, 3), s.deadCount());

    h.reset();
}
