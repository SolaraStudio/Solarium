const std = @import("std");

pub const Stats = struct {
    alloc_count: u64 = 0,
    free_count: u64 = 0,
    resize_count: u64 = 0,
    total_allocated: usize = 0,
    total_freed: usize = 0,
    peak_used: usize = 0,
    current_used: usize = 0,
    failed_allocs: u64 = 0,

    pub fn reset(self: *Stats) void {
        self.* = .{};
    }

    pub fn netUsage(self: Stats) i64 {
        return @as(i64, @intCast(self.total_allocated)) - @as(i64, @intCast(self.total_freed));
    }

    pub fn liveAllocs(self: Stats) u64 {
        return self.alloc_count - self.free_count;
    }

    pub fn averageAlloc(self: Stats) usize {
        if (self.alloc_count == 0) return 0;
        return self.total_allocated / @as(usize, @intCast(self.alloc_count));
    }
};

pub const Tracker = struct {
    stats: Stats,

    pub fn init() Tracker {
        return .{ .stats = .{} };
    }

    pub fn recordAlloc(self: *Tracker, size: usize) void {
        self.stats.alloc_count += 1;
        self.stats.total_allocated += size;
        self.stats.current_used += size;
        if (self.stats.current_used > self.stats.peak_used) {
            self.stats.peak_used = self.stats.current_used;
        }
    }

    pub fn recordFree(self: *Tracker, size: usize) void {
        self.stats.free_count += 1;
        self.stats.total_freed += size;
        if (size <= self.stats.current_used) {
            self.stats.current_used -= size;
        } else {
            self.stats.current_used = 0;
        }
    }

    pub fn recordResize(self: *Tracker, old_size: usize, new_size: usize) void {
        self.stats.resize_count += 1;
        if (new_size > old_size) {
            const diff = new_size - old_size;
            self.stats.total_allocated += diff;
            self.stats.current_used += diff;
            if (self.stats.current_used > self.stats.peak_used) {
                self.stats.peak_used = self.stats.current_used;
            }
        } else {
            const diff = old_size - new_size;
            self.stats.total_freed += diff;
            if (diff <= self.stats.current_used) {
                self.stats.current_used -= diff;
            } else {
                self.stats.current_used = 0;
            }
        }
    }

    pub fn recordFailure(self: *Tracker) void {
        self.stats.failed_allocs += 1;
    }

    pub fn reset(self: *Tracker) void {
        self.stats.reset();
    }

    pub fn snapshot(self: Tracker) Stats {
        return self.stats;
    }
};

pub const Limits = struct {
    max_total_bytes: usize = 0,
    max_single_alloc: usize = 0,
    max_live_allocs: u64 = 0,

    pub fn unlimited() Limits {
        return .{};
    }

    pub fn bounded(total: usize, single: usize, live: u64) Limits {
        return .{
            .max_total_bytes = total,
            .max_single_alloc = single,
            .max_live_allocs = live,
        };
    }

    pub fn allowsAlloc(self: Limits, size: usize, current_stats: Stats) bool {
        if (self.max_single_alloc > 0 and size > self.max_single_alloc) return false;
        if (self.max_total_bytes > 0) {
            const projected = current_stats.total_allocated + size;
            if (projected > self.max_total_bytes) return false;
        }
        if (self.max_live_allocs > 0) {
            if (current_stats.liveAllocs() >= self.max_live_allocs) return false;
        }
        return true;
    }
};

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    tracker: Tracker,
    limits: Limits,

    pub fn init(backing: std.mem.Allocator) TrackingAllocator {
        return .{
            .backing = backing,
            .tracker = Tracker.init(),
            .limits = Limits.unlimited(),
        };
    }

    pub fn initWithLimits(backing: std.mem.Allocator, limits: Limits) TrackingAllocator {
        return .{
            .backing = backing,
            .tracker = Tracker.init(),
            .limits = limits,
        };
    }

    pub fn alloc(self: *TrackingAllocator, comptime T: type, count: usize) ![]T {
        const size = @sizeOf(T) * count;
        if (!self.limits.allowsAlloc(size, self.tracker.stats)) {
            self.tracker.recordFailure();
            return error.OutOfMemory;
        }
        const result = try self.backing.alloc(T, count);
        self.tracker.recordAlloc(size);
        return result;
    }

    pub fn free(self: *TrackingAllocator, slice: anytype) void {
        const size = @sizeOf(std.meta.Child(@TypeOf(slice))) * slice.len;
        self.backing.free(slice);
        self.tracker.recordFree(size);
    }

    pub fn realloc(self: *TrackingAllocator, old: anytype, new_len: usize) !@TypeOf(old) {
        const T = std.meta.Child(@TypeOf(old));
        const old_size = @sizeOf(T) * old.len;
        const new_size = @sizeOf(T) * new_len;
        if (new_size > old_size) {
            const diff = new_size - old_size;
            if (!self.limits.allowsAlloc(diff, self.tracker.stats)) {
                self.tracker.recordFailure();
                return error.OutOfMemory;
            }
        }
        const result = try self.backing.realloc(old, new_len);
        self.tracker.recordResize(old_size, new_size);
        return result;
    }

    pub fn dupe(self: *TrackingAllocator, comptime T: type, source: []const T) ![]T {
        const size = @sizeOf(T) * source.len;
        if (!self.limits.allowsAlloc(size, self.tracker.stats)) {
            self.tracker.recordFailure();
            return error.OutOfMemory;
        }
        const result = try self.backing.dupe(T, source);
        self.tracker.recordAlloc(size);
        return result;
    }

    pub fn stats(self: TrackingAllocator) Stats {
        return self.tracker.stats;
    }
};

test "Stats default zero" {
    const s = Stats{};
    try std.testing.expectEqual(@as(u64, 0), s.alloc_count);
    try std.testing.expectEqual(@as(usize, 0), s.total_allocated);
}

test "Tracker recordAlloc" {
    var t = Tracker.init();
    t.recordAlloc(100);
    try std.testing.expectEqual(@as(u64, 1), t.stats.alloc_count);
    try std.testing.expectEqual(@as(usize, 100), t.stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 100), t.stats.current_used);
    try std.testing.expectEqual(@as(usize, 100), t.stats.peak_used);
}

test "Tracker recordFree" {
    var t = Tracker.init();
    t.recordAlloc(100);
    t.recordFree(50);
    try std.testing.expectEqual(@as(u64, 1), t.stats.free_count);
    try std.testing.expectEqual(@as(usize, 50), t.stats.current_used);
}

test "Tracker peak stays" {
    var t = Tracker.init();
    t.recordAlloc(100);
    t.recordAlloc(200);
    t.recordFree(250);
    try std.testing.expectEqual(@as(usize, 300), t.stats.peak_used);
    try std.testing.expectEqual(@as(usize, 50), t.stats.current_used);
}

test "Tracker recordResize grow" {
    var t = Tracker.init();
    t.recordAlloc(100);
    t.recordResize(100, 200);
    try std.testing.expectEqual(@as(u64, 1), t.stats.resize_count);
    try std.testing.expectEqual(@as(usize, 200), t.stats.current_used);
}

test "Tracker recordResize shrink" {
    var t = Tracker.init();
    t.recordAlloc(200);
    t.recordResize(200, 100);
    try std.testing.expectEqual(@as(usize, 100), t.stats.current_used);
}

test "Tracker reset" {
    var t = Tracker.init();
    t.recordAlloc(100);
    t.reset();
    try std.testing.expectEqual(@as(u64, 0), t.stats.alloc_count);
}

test "Stats netUsage" {
    const s = Stats{ .total_allocated = 100, .total_freed = 40 };
    try std.testing.expectEqual(@as(i64, 60), s.netUsage());
}

test "Stats liveAllocs" {
    const s = Stats{ .alloc_count = 10, .free_count = 6 };
    try std.testing.expectEqual(@as(u64, 4), s.liveAllocs());
}

test "Stats averageAlloc" {
    const s = Stats{ .alloc_count = 4, .total_allocated = 400 };
    try std.testing.expectEqual(@as(usize, 100), s.averageAlloc());
}

test "Limits unlimited allows anything" {
    const l = Limits.unlimited();
    try std.testing.expect(l.allowsAlloc(1024 * 1024 * 1024, Stats{}));
}

test "Limits max_single_alloc" {
    const l = Limits.bounded(0, 1000, 0);
    try std.testing.expect(l.allowsAlloc(500, Stats{}));
    try std.testing.expect(!l.allowsAlloc(2000, Stats{}));
}

test "Limits max_total_bytes" {
    const l = Limits.bounded(1000, 0, 0);
    const s = Stats{ .total_allocated = 900 };
    try std.testing.expect(l.allowsAlloc(50, s));
    try std.testing.expect(!l.allowsAlloc(200, s));
}

test "Limits max_live_allocs" {
    const l = Limits.bounded(0, 0, 5);
    const s = Stats{ .alloc_count = 5, .free_count = 0 };
    try std.testing.expect(!l.allowsAlloc(10, s));
}

test "TrackingAllocator alloc and free" {
    var ta = TrackingAllocator.init(std.testing.allocator);
    const slice = try ta.alloc(u32, 10);
    defer ta.free(slice);
    try std.testing.expectEqual(@as(u64, 1), ta.stats().alloc_count);
}

test "TrackingAllocator dupe" {
    var ta = TrackingAllocator.init(std.testing.allocator);
    const copy = try ta.dupe(u8, "hello");
    defer ta.free(copy);
    try std.testing.expectEqualStrings("hello", copy);
}

test "TrackingAllocator with limits rejects" {
    const limits = Limits.bounded(0, 100, 0);
    var ta = TrackingAllocator.initWithLimits(std.testing.allocator, limits);
    try std.testing.expectError(error.OutOfMemory, ta.alloc(u8, 200));
    try std.testing.expectEqual(@as(u64, 1), ta.stats().failed_allocs);
}

test "TrackingAllocator realloc" {
    var ta = TrackingAllocator.init(std.testing.allocator);
    var slice = try ta.alloc(u8, 10);
    slice = try ta.realloc(slice, 20);
    defer ta.free(slice);
    try std.testing.expectEqual(@as(usize, 20), slice.len);
    try std.testing.expectEqual(@as(u64, 1), ta.stats().resize_count);
}
