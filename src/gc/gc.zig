const std = @import("std");
const value_mod = @import("../values/value.zig");
const stats_mod = @import("stats.zig");
const heap_mod = @import("heap.zig");
const root_mod = @import("root.zig");
const mark_mod = @import("mark.zig");
const sweep_mod = @import("sweep.zig");
const compact_mod = @import("compact.zig");
const barrier_mod = @import("barrier.zig");
const time_mod = @import("../utils/time.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Stats = stats_mod.Stats;
pub const CollectionKind = stats_mod.CollectionKind;
pub const Phase = stats_mod.Phase;
pub const Heap = heap_mod.Heap;
pub const ObjectKind = heap_mod.ObjectKind;
pub const HeapError = heap_mod.HeapError;
pub const RootSet = root_mod.RootSet;
pub const RootGuard = root_mod.RootGuard;
pub const Marker = mark_mod.Marker;
pub const Sweeper = sweep_mod.Sweeper;
pub const Compactor = compact_mod.Compactor;
pub const Barrier = barrier_mod.Barrier;

pub const GcError = error{
    OutOfMemory,
    HeapFull,
    InvalidSize,
    InvalidObject,
    RecursionLimitExceeded,
    ConcurrentModification,
    CollectorBusy,
};

pub const GcPolicy = enum(u8) {
    manual,
    automatic,
    adaptive,

    pub fn toString(self: GcPolicy) []const u8 {
        return @tagName(self);
    }

    pub fn isAutomatic(self: GcPolicy) bool {
        return self == .automatic or self == .adaptive;
    }

    pub fn isManual(self: GcPolicy) bool {
        return self == .manual;
    }
};

pub const GcOptions = struct {
    policy: GcPolicy = .adaptive,
    initial_threshold: u64 = 16 * 1024 * 1024,
    max_threshold: u64 = 128 * 1024 * 1024,
    growth_factor: f64 = 1.5,
    shrink_factor: f64 = 0.75,
    enable_compaction: bool = true,
    enable_barriers: bool = true,
    enable_stats: bool = true,

    pub fn default() GcOptions {
        return .{};
    }

    pub fn manual() GcOptions {
        return .{
            .policy = .manual,
            .enable_compaction = false,
            .enable_barriers = false,
        };
    }

    pub fn aggressive() GcOptions {
        return .{
            .policy = .automatic,
            .initial_threshold = 4 * 1024 * 1024,
            .max_threshold = 32 * 1024 * 1024,
            .growth_factor = 1.25,
            .enable_compaction = true,
            .enable_barriers = true,
        };
    }
};

pub const CollectionResult = struct {
    kind: CollectionKind,
    objects_before: u64,
    objects_after: u64,
    bytes_before: u64,
    bytes_after: u64,
    duration_ns: u64,
    triggered_compaction: bool,

    pub fn init(kind: CollectionKind) CollectionResult {
        return .{
            .kind = kind,
            .objects_before = 0,
            .objects_after = 0,
            .bytes_before = 0,
            .bytes_after = 0,
            .duration_ns = 0,
            .triggered_compaction = false,
        };
    }

    pub fn reclaimedObjects(self: CollectionResult) u64 {
        if (self.objects_before > self.objects_after) {
            return self.objects_before - self.objects_after;
        }
        return 0;
    }

    pub fn reclaimedBytes(self: CollectionResult) u64 {
        if (self.bytes_before > self.bytes_after) {
            return self.bytes_before - self.bytes_after;
        }
        return 0;
    }

    pub fn reclaimedRatio(self: CollectionResult) f64 {
        if (self.bytes_before == 0) return 0;
        return @as(f64, @floatFromInt(self.reclaimedBytes())) /
            @as(f64, @floatFromInt(self.bytes_before));
    }
};

pub const Gc = struct {
    allocator: std.mem.Allocator,
    heap: *Heap,
    roots: RootSet,
    marker: *Marker,
    sweeper: *Sweeper,
    compactor: *Compactor,
    barrier: *Barrier,
    stats: *Stats,
    options: GcOptions,
    next_threshold: u64,
    running: bool,
    last_result: ?CollectionResult,

    pub fn init(allocator: std.mem.Allocator) !Gc {
        return try initWithOptions(allocator, GcOptions.default());
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: GcOptions) !Gc {
        const stats = try stats_mod.createStats(allocator);
        errdefer stats_mod.destroyStats(stats);

        if (!options.enable_stats) {
            stats.disable();
        }

        const heap = try allocator.create(Heap);
        errdefer allocator.destroy(heap);
        heap.* = Heap.init(allocator, stats);

        const marker = try mark_mod.createMarker(allocator, heap);
        errdefer mark_mod.destroyMarker(marker);

        const sweeper = try sweep_mod.createSweeper(allocator, heap);
        errdefer sweep_mod.destroySweeper(sweeper);

        const compactor = try compact_mod.createCompactor(allocator, heap);
        errdefer compact_mod.destroyCompactor(compactor);

        const barrier = try barrier_mod.createBarrier(allocator, heap);
        errdefer barrier_mod.destroyBarrier(barrier);

        return .{
            .allocator = allocator,
            .heap = heap,
            .roots = RootSet.init(allocator),
            .marker = marker,
            .sweeper = sweeper,
            .compactor = compactor,
            .barrier = barrier,
            .stats = stats,
            .options = options,
            .next_threshold = options.initial_threshold,
            .running = false,
            .last_result = null,
        };
    }

    pub fn deinit(self: *Gc) void {
        self.roots.deinit();
        mark_mod.destroyMarker(self.marker);
        sweep_mod.destroySweeper(self.sweeper);
        compact_mod.destroyCompactor(self.compactor);
        barrier_mod.destroyBarrier(self.barrier);
        self.heap.deinit();
        self.allocator.destroy(self.heap);
        stats_mod.destroyStats(self.stats);
    }

    pub fn getAllocator(self: *Gc) std.mem.Allocator {
        return self.heap.allocator;
    }

    pub fn allocate(self: *Gc, kind: ObjectKind, size: u64) GcError!heap_mod.Allocation {
        if (self.shouldCollect()) {
            _ = try self.collect(.minor);
        }
        return self.heap.allocate(kind, size) catch |err| switch (err) {
            HeapError.OutOfMemory => GcError.OutOfMemory,
            HeapError.HeapFull => GcError.HeapFull,
            HeapError.InvalidSize => GcError.InvalidSize,
            else => GcError.InvalidObject,
        };
    }

    pub fn deallocate(self: *Gc, obj: *Object) GcError!void {
        self.heap.forceDeallocate(obj) catch |err| switch (err) {
            HeapError.ObjectNotFound => return GcError.InvalidObject,
            else => return GcError.InvalidObject,
        };
    }

    pub fn shouldCollect(self: Gc) bool {
        if (!self.options.policy.isAutomatic()) return false;
        return self.heap.currentSize() >= self.next_threshold;
    }

    pub fn collect(self: *Gc, kind: CollectionKind) GcError!CollectionResult {
        if (self.running) return GcError.CollectorBusy;
        self.running = true;
        defer self.running = false;

        const start_ns = time_mod.nowNanos();

        var result = CollectionResult.init(kind);
        result.objects_before = self.stats.liveObjects();
        result.bytes_before = self.stats.liveBytes();

        self.stats.beginCollection(kind);

        if (self.options.enable_barriers) {
            self.barrier.activate();
        }

        self.heap.unmarkAll();

        self.marker.run(&self.roots) catch |err| switch (err) {
            mark_mod.MarkError.OutOfMemory => return GcError.OutOfMemory,
            mark_mod.MarkError.RecursionLimitExceeded => return GcError.RecursionLimitExceeded,
            else => return GcError.InvalidObject,
        };

        self.sweeper.sweep() catch |err| switch (err) {
            sweep_mod.SweepError.OutOfMemory => return GcError.OutOfMemory,
            else => return GcError.InvalidObject,
        };

        if (self.options.enable_compaction and kind.isFull()) {
            const compact_result = self.compactor.compact() catch |err| switch (err) {
                compact_mod.CompactError.OutOfMemory => return GcError.OutOfMemory,
                else => return GcError.InvalidObject,
            };
            result.triggered_compaction = !compact_result.nothingMoved();
        }

        if (self.options.enable_barriers) {
            self.barrier.deactivate();
        }

        const end_ns = time_mod.nowNanos();
        result.duration_ns = @intCast(end_ns - start_ns);

        result.objects_after = self.stats.liveObjects();
        result.bytes_after = self.stats.liveBytes();

        self.stats.endCollection(result.duration_ns) catch {};

        self.adjustThreshold();

        self.last_result = result;

        return result;
    }

    fn adjustThreshold(self: *Gc) void {
        const current_bytes = self.heap.currentSize();

        if (self.options.policy == .adaptive) {
            const next = @as(f64, @floatFromInt(current_bytes)) * self.options.growth_factor;
            self.next_threshold = @intFromFloat(@min(next, @as(f64, @floatFromInt(self.options.max_threshold))));

            if (self.next_threshold < self.options.initial_threshold) {
                self.next_threshold = self.options.initial_threshold;
            }
        } else {
            self.next_threshold = self.options.initial_threshold;
        }
    }

    pub fn collectFull(self: *Gc) GcError!CollectionResult {
        return try self.collect(.full);
    }

    pub fn collectMinor(self: *Gc) GcError!CollectionResult {
        return try self.collect(.minor);
    }

    pub fn collectMajor(self: *Gc) GcError!CollectionResult {
        return try self.collect(.major);
    }

    pub fn addRoot(self: *Gc, value: Value) !void {
        try self.roots.add(value, .global);
    }

    pub fn addRootRange(self: *Gc, values: []Value) !void {
        try self.roots.addStackRange(values);
    }

    pub fn pinRoot(self: *Gc, value: Value) !void {
        try self.roots.pin(value);
    }

    pub fn unpinRoot(self: *Gc, value: Value) void {
        self.roots.unpin(value);
    }

    pub fn clearRoots(self: *Gc) void {
        self.roots.clear();
    }

    pub fn recordWrite(self: *Gc, container_addr: usize, value: Value) void {
        self.barrier.recordWrite(container_addr, value) catch {};
    }

    pub fn liveObjects(self: Gc) u64 {
        return self.stats.liveObjects();
    }

    pub fn liveBytes(self: Gc) u64 {
        return self.stats.liveBytes();
    }

    pub fn collectionCount(self: Gc) u64 {
        return self.stats.collectionCount();
    }

    pub fn currentThreshold(self: Gc) u64 {
        return self.next_threshold;
    }

    pub fn setThreshold(self: *Gc, threshold: u64) void {
        self.next_threshold = threshold;
    }

    pub fn lastResult(self: Gc) ?CollectionResult {
        return self.last_result;
    }

    pub fn setPolicy(self: *Gc, policy: GcPolicy) void {
        self.options.policy = policy;
    }

    pub fn printStats(self: Gc) void {
        self.stats.print();
    }

    pub fn reset(self: *Gc) void {
        self.heap.reset();
        self.roots.clear();
        self.stats.reset();
        self.next_threshold = self.options.initial_threshold;
        self.last_result = null;
    }
};

pub fn createGc(allocator: std.mem.Allocator) !*Gc {
    const gc = try allocator.create(Gc);
    gc.* = try Gc.init(allocator);
    return gc;
}

pub fn createGcWithOptions(allocator: std.mem.Allocator, options: GcOptions) !*Gc {
    const gc = try allocator.create(Gc);
    gc.* = try Gc.initWithOptions(allocator, options);
    return gc;
}

pub fn destroyGc(gc: *Gc) void {
    const allocator = gc.allocator;
    gc.deinit();
    allocator.destroy(gc);
}

pub fn createDefault() GcOptions {
    return GcOptions.default();
}

test "GcPolicy toString" {
    try std.testing.expectEqualStrings("manual", GcPolicy.manual.toString());
    try std.testing.expectEqualStrings("automatic", GcPolicy.automatic.toString());
    try std.testing.expectEqualStrings("adaptive", GcPolicy.adaptive.toString());
}

test "GcPolicy predicates" {
    try std.testing.expect(GcPolicy.automatic.isAutomatic());
    try std.testing.expect(GcPolicy.adaptive.isAutomatic());
    try std.testing.expect(GcPolicy.manual.isManual());
    try std.testing.expect(!GcPolicy.manual.isAutomatic());
}

test "GcOptions default" {
    const o = GcOptions.default();
    try std.testing.expectEqual(GcPolicy.adaptive, o.policy);
    try std.testing.expect(o.enable_compaction);
    try std.testing.expect(o.enable_barriers);
}

test "GcOptions manual" {
    const o = GcOptions.manual();
    try std.testing.expect(o.policy.isManual());
    try std.testing.expect(!o.enable_compaction);
}

test "GcOptions aggressive" {
    const o = GcOptions.aggressive();
    try std.testing.expect(o.policy.isAutomatic());
    try std.testing.expectEqual(@as(u64, 4 * 1024 * 1024), o.initial_threshold);
}

test "CollectionResult init" {
    const r = CollectionResult.init(.minor);
    try std.testing.expectEqual(CollectionKind.minor, r.kind);
    try std.testing.expectEqual(@as(u64, 0), r.reclaimedBytes());
}

test "CollectionResult reclaimedRatio" {
    var r = CollectionResult.init(.minor);
    r.bytes_before = 1000;
    r.bytes_after = 400;
    try std.testing.expectEqual(@as(f64, 0.6), r.reclaimedRatio());
}

test "Gc init" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    try std.testing.expectEqual(@as(u64, 0), gc.liveObjects());
    try std.testing.expectEqual(@as(u64, 0), gc.liveBytes());
}

test "Gc initWithOptions" {
    var gc = try Gc.initWithOptions(std.testing.allocator, GcOptions.manual());
    defer gc.deinit();

    try std.testing.expect(gc.options.policy.isManual());
}

test "Gc allocate" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    const alloc = try gc.allocate(.plain_object, 64);
    defer gc.deallocate(alloc.toObject()) catch {};

    try std.testing.expectEqual(@as(u64, 64), gc.liveBytes());
}

test "Gc allocate triggers collection" {
    var gc = try Gc.initWithOptions(std.testing.allocator, .{
        .policy = .automatic,
        .initial_threshold = 32,
        .max_threshold = 1024,
        .enable_compaction = false,
        .enable_barriers = false,
    });
    defer gc.deinit();

    const a1 = try gc.allocate(.plain_object, 64);
    const a2 = try gc.allocate(.plain_object, 64);
    defer gc.deallocate(a1.toObject()) catch {};
    defer gc.deallocate(a2.toObject()) catch {};

    try std.testing.expect(gc.collectionCount() >= 1);
}

test "Gc collect empty" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    const r = try gc.collect(.full);
    try std.testing.expectEqual(CollectionKind.full, r.kind);
}

test "Gc collect reclaims unreachable" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    _ = try gc.allocate(.plain_object, 64);
    _ = try gc.allocate(.array, 64);

    try std.testing.expectEqual(@as(u64, 2), gc.liveObjects());

    _ = try gc.collect(.full);

    try std.testing.expectEqual(@as(u64, 0), gc.liveObjects());
}

test "Gc collect keeps rooted" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    const alloc = try gc.allocate(.plain_object, 64);
    try gc.addRoot(alloc.toValue());

    _ = try gc.collect(.full);

    try std.testing.expectEqual(@as(u64, 1), gc.liveObjects());

    gc.clearRoots();
    gc.deallocate(alloc.toObject()) catch {};
}

test "Gc addRoot and clearRoots" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    try gc.addRoot(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), gc.roots.entryCount());

    gc.clearRoots();
    try std.testing.expectEqual(@as(usize, 0), gc.roots.entryCount());
}

test "Gc pinRoot" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    try gc.pinRoot(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), gc.roots.pinnedCount());
}

test "Gc currentThreshold" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    try std.testing.expectEqual(@as(u64, 16 * 1024 * 1024), gc.currentThreshold());
}

test "Gc setThreshold" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    gc.setThreshold(1024);
    try std.testing.expectEqual(@as(u64, 1024), gc.currentThreshold());
}

test "Gc setPolicy" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    gc.setPolicy(.manual);
    try std.testing.expect(gc.options.policy.isManual());
}

test "Gc lastResult" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    try std.testing.expect(gc.lastResult() == null);

    _ = try gc.collect(.full);

    try std.testing.expect(gc.lastResult() != null);
}

test "Gc recordWrite" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    gc.recordWrite(0, Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), gc.barrier.getStats().writes_observed);
}

test "Gc reset" {
    var gc = try Gc.init(std.testing.allocator);
    defer gc.deinit();

    _ = try gc.allocate(.plain_object, 64);
    try gc.addRoot(Value.TRUE);

    gc.reset();

    try std.testing.expectEqual(@as(u64, 0), gc.liveBytes());
    try std.testing.expectEqual(@as(usize, 0), gc.roots.entryCount());
}

test "createGc and destroyGc" {
    const gc = try createGc(std.testing.allocator);
    destroyGc(gc);
}

test "createGcWithOptions" {
    const gc = try createGcWithOptions(std.testing.allocator, GcOptions.aggressive());
    destroyGc(gc);
}

test "createDefault" {
    const o = createDefault();
    try std.testing.expectEqual(GcPolicy.adaptive, o.policy);
}
