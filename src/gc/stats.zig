const std = @import("std");

pub const CollectionKind = enum(u8) {
    minor,
    major,
    full,
    incremental,
    explicit_,

    pub fn toString(self: CollectionKind) []const u8 {
        return @tagName(self);
    }

    pub fn isFull(self: CollectionKind) bool {
        return self == .full or self == .major;
    }

    pub fn isIncremental(self: CollectionKind) bool {
        return self == .incremental;
    }
};

pub const Phase = enum(u8) {
    idle,
    marking,
    sweeping,
    compacting,
    finalizing,

    pub fn toString(self: Phase) []const u8 {
        return @tagName(self);
    }

    pub fn isIdle(self: Phase) bool {
        return self == .idle;
    }

    pub fn isActive(self: Phase) bool {
        return self != .idle;
    }
};

pub const Counters = struct {
    allocated_bytes: u64 = 0,
    freed_bytes: u64 = 0,
    allocated_objects: u64 = 0,
    freed_objects: u64 = 0,
    live_objects: u64 = 0,
    peak_objects: u64 = 0,
    peak_bytes: u64 = 0,

    pub fn init() Counters {
        return .{};
    }

    pub fn recordAlloc(self: *Counters, size: u64) void {
        self.allocated_bytes += size;
        self.allocated_objects += 1;
        self.live_objects += 1;
        if (self.live_objects > self.peak_objects) {
            self.peak_objects = self.live_objects;
        }
        if (self.allocated_bytes - self.freed_bytes > self.peak_bytes) {
            self.peak_bytes = self.allocated_bytes - self.freed_bytes;
        }
    }

    pub fn recordFree(self: *Counters, size: u64) void {
        self.freed_bytes += size;
        self.freed_objects += 1;
        if (self.live_objects > 0) {
            self.live_objects -= 1;
        }
    }

    pub fn liveBytes(self: Counters) u64 {
        return self.allocated_bytes - self.freed_bytes;
    }

    pub fn netObjects(self: Counters) i64 {
        return @as(i64, @intCast(self.allocated_objects)) -
            @as(i64, @intCast(self.freed_objects));
    }

    pub fn averageSize(self: Counters) u64 {
        if (self.allocated_objects == 0) return 0;
        return self.allocated_bytes / self.allocated_objects;
    }

    pub fn reset(self: *Counters) void {
        self.* = Counters.init();
    }
};

pub const Timing = struct {
    total_ns: u64 = 0,
    mark_ns: u64 = 0,
    sweep_ns: u64 = 0,
    compact_ns: u64 = 0,
    finalize_ns: u64 = 0,
    pause_max_ns: u64 = 0,
    pause_count: u64 = 0,

    pub fn init() Timing {
        return .{};
    }

    pub fn recordPause(self: *Timing, ns: u64) void {
        if (ns > self.pause_max_ns) {
            self.pause_max_ns = ns;
        }
        self.pause_count += 1;
    }

    pub fn averagePause(self: Timing) u64 {
        if (self.pause_count == 0) return 0;
        return self.total_ns / self.pause_count;
    }

    pub fn reset(self: *Timing) void {
        self.* = Timing.init();
    }
};

pub const CollectionRecord = struct {
    kind: CollectionKind,
    duration_ns: u64,
    objects_before: u64,
    objects_after: u64,
    bytes_before: u64,
    bytes_after: u64,

    pub fn init(kind: CollectionKind) CollectionRecord {
        return .{
            .kind = kind,
            .duration_ns = 0,
            .objects_before = 0,
            .objects_after = 0,
            .bytes_before = 0,
            .bytes_after = 0,
        };
    }

    pub fn reclaimedObjects(self: CollectionRecord) u64 {
        if (self.objects_before > self.objects_after) {
            return self.objects_before - self.objects_after;
        }
        return 0;
    }

    pub fn reclaimedBytes(self: CollectionRecord) u64 {
        if (self.bytes_before > self.bytes_after) {
            return self.bytes_before - self.bytes_after;
        }
        return 0;
    }
};

pub const Stats = struct {
    allocator: std.mem.Allocator,
    counters: Counters,
    timing: Timing,
    phase: Phase,
    collections: u64,
    minor_collections: u64,
    major_collections: u64,
    full_collections: u64,
    last_record: ?CollectionRecord,
    records: std.ArrayList(CollectionRecord),
    max_records: usize,
    enabled: bool,

    pub fn init(allocator: std.mem.Allocator) Stats {
        return .{
            .allocator = allocator,
            .counters = Counters.init(),
            .timing = Timing.init(),
            .phase = .idle,
            .collections = 0,
            .minor_collections = 0,
            .major_collections = 0,
            .full_collections = 0,
            .last_record = null,
            .records = .empty,
            .max_records = 256,
            .enabled = true,
        };
    }

    pub fn deinit(self: *Stats) void {
        self.records.deinit(self.allocator);
    }

    pub fn enable(self: *Stats) void {
        self.enabled = true;
    }

    pub fn disable(self: *Stats) void {
        self.enabled = false;
    }

    pub fn isEnabled(self: Stats) bool {
        return self.enabled;
    }

    pub fn recordAlloc(self: *Stats, size: u64) void {
        if (!self.enabled) return;
        self.counters.recordAlloc(size);
    }

    pub fn recordFree(self: *Stats, size: u64) void {
        if (!self.enabled) return;
        self.counters.recordFree(size);
    }

    pub fn beginCollection(self: *Stats, kind: CollectionKind) void {
        self.phase = .marking;
        var rec = CollectionRecord.init(kind);
        rec.objects_before = self.counters.live_objects;
        rec.bytes_before = self.counters.liveBytes();
        self.last_record = rec;
    }

    pub fn endCollection(self: *Stats, duration_ns: u64) !void {
        self.phase = .idle;
        self.collections += 1;

        if (self.last_record) |*rec| {
            rec.duration_ns = duration_ns;
            rec.objects_after = self.counters.live_objects;
            rec.bytes_after = self.counters.liveBytes();

            switch (rec.kind) {
                .minor => self.minor_collections += 1,
                .major => self.major_collections += 1,
                .full => self.full_collections += 1,
                else => {},
            }

            self.timing.total_ns += duration_ns;
            self.timing.recordPause(duration_ns);

            if (self.records.items.len >= self.max_records) {
                _ = self.records.orderedRemove(0);
            }
            try self.records.append(self.allocator, rec.*);
        }
    }

    pub fn setPhase(self: *Stats, phase: Phase) void {
        self.phase = phase;
    }

    pub fn currentPhase(self: Stats) Phase {
        return self.phase;
    }

    pub fn liveObjects(self: Stats) u64 {
        return self.counters.live_objects;
    }

    pub fn liveBytes(self: Stats) u64 {
        return self.counters.liveBytes();
    }

    pub fn totalAllocated(self: Stats) u64 {
        return self.counters.allocated_bytes;
    }

    pub fn totalFreed(self: Stats) u64 {
        return self.counters.freed_bytes;
    }

    pub fn collectionCount(self: Stats) u64 {
        return self.collections;
    }

    pub fn recordCount(self: Stats) usize {
        return self.records.items.len;
    }

    pub fn lastCollection(self: Stats) ?CollectionRecord {
        return self.last_record;
    }

    pub fn averageCollectionTime(self: Stats) u64 {
        if (self.collections == 0) return 0;
        return self.timing.total_ns / self.collections;
    }

    pub fn maxPauseTime(self: Stats) u64 {
        return self.timing.pause_max_ns;
    }

    pub fn reset(self: *Stats) void {
        self.counters.reset();
        self.timing.reset();
        self.phase = .idle;
        self.collections = 0;
        self.minor_collections = 0;
        self.major_collections = 0;
        self.full_collections = 0;
        self.last_record = null;
        self.records.clearRetainingCapacity();
    }

    pub fn print(self: Stats) void {
        std.debug.print(
            "GC Stats:\n  Live objects: {d}\n  Live bytes: {d}\n  Total allocated: {d}\n  Total freed: {d}\n  Collections: {d}\n  Average time: {d}ns\n  Max pause: {d}ns\n",
            .{
                self.counters.live_objects,
                self.counters.liveBytes(),
                self.counters.allocated_bytes,
                self.counters.freed_bytes,
                self.collections,
                self.averageCollectionTime(),
                self.timing.pause_max_ns,
            },
        );
    }
};

pub fn createStats(allocator: std.mem.Allocator) !*Stats {
    const s = try allocator.create(Stats);
    s.* = Stats.init(allocator);
    return s;
}

pub fn destroyStats(s: *Stats) void {
    const allocator = s.allocator;
    s.deinit();
    allocator.destroy(s);
}

test "CollectionKind toString" {
    try std.testing.expectEqualStrings("minor", CollectionKind.minor.toString());
    try std.testing.expectEqualStrings("major", CollectionKind.major.toString());
}

test "CollectionKind isFull" {
    try std.testing.expect(CollectionKind.full.isFull());
    try std.testing.expect(CollectionKind.major.isFull());
    try std.testing.expect(!CollectionKind.minor.isFull());
}

test "CollectionKind isIncremental" {
    try std.testing.expect(CollectionKind.incremental.isIncremental());
    try std.testing.expect(!CollectionKind.minor.isIncremental());
}

test "Phase toString" {
    try std.testing.expectEqualStrings("idle", Phase.idle.toString());
    try std.testing.expectEqualStrings("marking", Phase.marking.toString());
}

test "Phase isIdle and isActive" {
    try std.testing.expect(Phase.idle.isIdle());
    try std.testing.expect(!Phase.idle.isActive());
    try std.testing.expect(Phase.marking.isActive());
}

test "Counters init" {
    const c = Counters.init();
    try std.testing.expectEqual(@as(u64, 0), c.live_objects);
    try std.testing.expectEqual(@as(u64, 0), c.liveBytes());
}

test "Counters recordAlloc" {
    var c = Counters.init();
    c.recordAlloc(100);
    try std.testing.expectEqual(@as(u64, 1), c.live_objects);
    try std.testing.expectEqual(@as(u64, 100), c.liveBytes());
}

test "Counters recordFree" {
    var c = Counters.init();
    c.recordAlloc(100);
    c.recordFree(50);
    try std.testing.expectEqual(@as(u64, 0), c.live_objects);
    try std.testing.expectEqual(@as(u64, 50), c.liveBytes());
}

test "Counters peak tracking" {
    var c = Counters.init();
    c.recordAlloc(100);
    c.recordAlloc(200);
    c.recordFree(250);

    try std.testing.expectEqual(@as(u64, 2), c.peak_objects);
}

test "Counters averageSize" {
    var c = Counters.init();
    c.recordAlloc(100);
    c.recordAlloc(200);
    try std.testing.expectEqual(@as(u64, 150), c.averageSize());
}

test "Counters reset" {
    var c = Counters.init();
    c.recordAlloc(100);
    c.reset();
    try std.testing.expectEqual(@as(u64, 0), c.live_objects);
}

test "Timing init" {
    const t = Timing.init();
    try std.testing.expectEqual(@as(u64, 0), t.pause_count);
}

test "Timing recordPause" {
    var t = Timing.init();
    t.recordPause(100);
    t.recordPause(50);
    try std.testing.expectEqual(@as(u64, 100), t.pause_max_ns);
    try std.testing.expectEqual(@as(u64, 2), t.pause_count);
}

test "Timing averagePause" {
    var t = Timing.init();
    t.total_ns = 1000;
    t.pause_count = 4;
    try std.testing.expectEqual(@as(u64, 250), t.averagePause());
}

test "CollectionRecord init" {
    const r = CollectionRecord.init(.minor);
    try std.testing.expectEqual(CollectionKind.minor, r.kind);
}

test "CollectionRecord reclaimed" {
    var r = CollectionRecord.init(.major);
    r.objects_before = 100;
    r.objects_after = 60;
    r.bytes_before = 10000;
    r.bytes_after = 6000;

    try std.testing.expectEqual(@as(u64, 40), r.reclaimedObjects());
    try std.testing.expectEqual(@as(u64, 4000), r.reclaimedBytes());
}

test "Stats init" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();
    try std.testing.expectEqual(@as(u64, 0), s.collectionCount());
    try std.testing.expect(s.isEnabled());
}

test "Stats enable disable" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.disable();
    try std.testing.expect(!s.isEnabled());
    s.enable();
    try std.testing.expect(s.isEnabled());
}

test "Stats recordAlloc when disabled" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.disable();
    s.recordAlloc(100);
    try std.testing.expectEqual(@as(u64, 0), s.liveObjects());
}

test "Stats recordAlloc when enabled" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.recordAlloc(100);
    try std.testing.expectEqual(@as(u64, 1), s.liveObjects());
}

test "Stats beginCollection sets phase" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.beginCollection(.minor);
    try std.testing.expectEqual(Phase.marking, s.currentPhase());
}

test "Stats endCollection records" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.beginCollection(.minor);
    try s.endCollection(1000);

    try std.testing.expectEqual(@as(u64, 1), s.collectionCount());
    try std.testing.expectEqual(Phase.idle, s.currentPhase());
}

test "Stats minor major full counts" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.beginCollection(.minor);
    try s.endCollection(100);

    s.beginCollection(.major);
    try s.endCollection(200);

    s.beginCollection(.full);
    try s.endCollection(300);

    try std.testing.expectEqual(@as(u64, 1), s.minor_collections);
    try std.testing.expectEqual(@as(u64, 1), s.major_collections);
    try std.testing.expectEqual(@as(u64, 1), s.full_collections);
}

test "Stats average collection time" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.beginCollection(.minor);
    try s.endCollection(100);

    s.beginCollection(.minor);
    try s.endCollection(200);

    try std.testing.expectEqual(@as(u64, 150), s.averageCollectionTime());
}

test "Stats maxPauseTime" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.beginCollection(.minor);
    try s.endCollection(100);

    s.beginCollection(.minor);
    try s.endCollection(500);

    try std.testing.expectEqual(@as(u64, 500), s.maxPauseTime());
}

test "Stats record limit" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();
    s.max_records = 3;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        s.beginCollection(.minor);
        try s.endCollection(100);
    }

    try std.testing.expectEqual(@as(usize, 3), s.recordCount());
}

test "Stats reset" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.recordAlloc(100);
    s.beginCollection(.minor);
    try s.endCollection(50);
    s.reset();

    try std.testing.expectEqual(@as(u64, 0), s.liveObjects());
    try std.testing.expectEqual(@as(u64, 0), s.collectionCount());
}

test "Stats setPhase" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    s.setPhase(.sweeping);
    try std.testing.expectEqual(Phase.sweeping, s.currentPhase());
}

test "Stats lastCollection" {
    var s = Stats.init(std.testing.allocator);
    defer s.deinit();

    try std.testing.expect(s.lastCollection() == null);

    s.beginCollection(.minor);
    try s.endCollection(100);

    try std.testing.expect(s.lastCollection() != null);
}

test "createStats and destroyStats" {
    const s = try createStats(std.testing.allocator);
    destroyStats(s);
}
