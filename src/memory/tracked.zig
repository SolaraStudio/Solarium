const std = @import("std");
const allocator_mod = @import("allocator.zig");

pub const Tracked = struct {
    backing: std.mem.Allocator,
    tracker: allocator_mod.Tracker,

    pub fn init(backing: std.mem.Allocator) Tracked {
        return .{
            .backing = backing,
            .tracker = allocator_mod.Tracker.init(),
        };
    }

    pub fn deinit(self: *Tracked) void {
        _ = self;
    }

    pub fn alloc(self: *Tracked, comptime T: type, count: usize) ![]T {
        const bytes = @sizeOf(T) * count;
        const result = try self.backing.alloc(T, count);
        self.tracker.recordAlloc(bytes);
        return result;
    }

    pub fn free(self: *Tracked, slice: anytype) void {
        const T = std.meta.Child(@TypeOf(slice));
        const bytes = @sizeOf(T) * slice.len;
        self.backing.free(slice);
        self.tracker.recordFree(bytes);
    }

    pub fn realloc(self: *Tracked, old: anytype, new_len: usize) !@TypeOf(old) {
        const T = std.meta.Child(@TypeOf(old));
        const old_bytes = @sizeOf(T) * old.len;
        const new_bytes = @sizeOf(T) * new_len;
        const result = try self.backing.realloc(old, new_len);
        self.tracker.recordResize(old_bytes, new_bytes);
        return result;
    }

    pub fn dupe(self: *Tracked, comptime T: type, source: []const T) ![]T {
        const bytes = @sizeOf(T) * source.len;
        const result = try self.backing.dupe(T, source);
        self.tracker.recordAlloc(bytes);
        return result;
    }

    pub fn dupeZ(self: *Tracked, comptime T: type, source: []const T) ![:0]T {
        const bytes = @sizeOf(T) * source.len;
        const result = try self.backing.dupeZ(T, source);
        self.tracker.recordAlloc(bytes);
        return result;
    }

    pub fn create(self: *Tracked, comptime T: type) !*T {
        const ptr = try self.backing.create(T);
        self.tracker.recordAlloc(@sizeOf(T));
        return ptr;
    }

    pub fn destroy(self: *Tracked, ptr: anytype) void {
        const T = std.meta.Child(@TypeOf(ptr));
        self.backing.destroy(ptr);
        self.tracker.recordFree(@sizeOf(T));
    }

    pub fn stats(self: Tracked) allocator_mod.Stats {
        return self.tracker.stats;
    }

    pub fn reset(self: *Tracked) void {
        self.tracker.reset();
    }

    pub fn print(self: Tracked) void {
        const s = self.tracker.stats;
        std.debug.print(
            "Allocations: {d} live, {d} total, {d} bytes live, {d} bytes peak\n",
            .{ s.liveAllocs(), s.alloc_count, s.current_used, s.peak_used },
        );
    }
};

pub const CountedAllocator = struct {
    backing: std.mem.Allocator,
    allocation_count: u64,
    free_count: u64,

    pub fn init(backing: std.mem.Allocator) CountedAllocator {
        return .{
            .backing = backing,
            .allocation_count = 0,
            .free_count = 0,
        };
    }

    pub fn alloc(self: *CountedAllocator, comptime T: type, count: usize) ![]T {
        self.allocation_count += 1;
        return self.backing.alloc(T, count);
    }

    pub fn free(self: *CountedAllocator, slice: anytype) void {
        self.free_count += 1;
        self.backing.free(slice);
    }

    pub fn liveCount(self: CountedAllocator) u64 {
        return self.allocation_count - self.free_count;
    }
};

pub const Bytes = struct {
    value: usize,

    pub fn init(value: usize) Bytes {
        return .{ .value = value };
    }

    pub fn fromKilobytes(kb: usize) Bytes {
        return .{ .value = kb * 1024 };
    }

    pub fn fromMegabytes(mb: usize) Bytes {
        return .{ .value = mb * 1024 * 1024 };
    }

    pub fn fromGigabytes(gb: usize) Bytes {
        return .{ .value = gb * 1024 * 1024 * 1024 };
    }

    pub fn toKilobytes(self: Bytes) f64 {
        return @as(f64, @floatFromInt(self.value)) / 1024.0;
    }

    pub fn toMegabytes(self: Bytes) f64 {
        return @as(f64, @floatFromInt(self.value)) / (1024.0 * 1024.0);
    }

    pub fn toGigabytes(self: Bytes) f64 {
        return @as(f64, @floatFromInt(self.value)) / (1024.0 * 1024.0 * 1024.0);
    }

    pub fn add(self: Bytes, other: Bytes) Bytes {
        return .{ .value = self.value + other.value };
    }

    pub fn sub(self: Bytes, other: Bytes) Bytes {
        return .{ .value = if (self.value >= other.value) self.value - other.value else 0 };
    }
};

test "Tracked init" {
    var t = Tracked.init(std.testing.allocator);
    const s = t.stats();
    try std.testing.expectEqual(@as(u64, 0), s.alloc_count);
}

test "Tracked alloc and free" {
    var t = Tracked.init(std.testing.allocator);
    const slice = try t.alloc(u32, 10);
    defer t.free(slice);
    try std.testing.expectEqual(@as(u64, 1), t.stats().alloc_count);
}

test "Tracked dupe" {
    var t = Tracked.init(std.testing.allocator);
    const copy = try t.dupe(u8, "hello");
    defer t.free(copy);
    try std.testing.expectEqualStrings("hello", copy);
}

test "Tracked create and destroy" {
    var t = Tracked.init(std.testing.allocator);
    const ptr = try t.create(u32);
    ptr.* = 42;
    try std.testing.expectEqual(@as(u32, 42), ptr.*);
    t.destroy(ptr);
}

test "Tracked reset stats" {
    var t = Tracked.init(std.testing.allocator);
    const slice = try t.alloc(u8, 100);
    defer t.free(slice);
    t.reset();
    try std.testing.expectEqual(@as(u64, 0), t.stats().alloc_count);
}

test "CountedAllocator counts" {
    var c = CountedAllocator.init(std.testing.allocator);
    const slice = try c.alloc(u8, 10);
    defer c.free(slice);
    try std.testing.expectEqual(@as(u64, 1), c.allocation_count);
    try std.testing.expectEqual(@as(u64, 0), c.liveCount());
}

test "Bytes init" {
    const b = Bytes.init(1024);
    try std.testing.expectEqual(@as(usize, 1024), b.value);
}

test "Bytes fromKilobytes" {
    const b = Bytes.fromKilobytes(2);
    try std.testing.expectEqual(@as(usize, 2048), b.value);
}

test "Bytes fromMegabytes" {
    const b = Bytes.fromMegabytes(1);
    try std.testing.expectEqual(@as(usize, 1024 * 1024), b.value);
}

test "Bytes fromGigabytes" {
    const b = Bytes.fromGigabytes(1);
    try std.testing.expectEqual(@as(usize, 1024 * 1024 * 1024), b.value);
}

test "Bytes toKilobytes" {
    const b = Bytes.init(2048);
    try std.testing.expectEqual(@as(f64, 2.0), b.toKilobytes());
}

test "Bytes toMegabytes" {
    const b = Bytes.init(1024 * 1024 * 2);
    try std.testing.expectEqual(@as(f64, 2.0), b.toMegabytes());
}

test "Bytes add and sub" {
    const a = Bytes.init(100);
    const b = Bytes.init(50);
    try std.testing.expectEqual(@as(usize, 150), a.add(b).value);
    try std.testing.expectEqual(@as(usize, 50), a.sub(b).value);
    try std.testing.expectEqual(@as(usize, 0), b.sub(a).value);
}
