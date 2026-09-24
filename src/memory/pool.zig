const std = @import("std");

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        slots: []Slot,
        free_head: ?u32,
        backing: std.mem.Allocator,
        live_count: usize,
        peak_count: usize,
        total_acquired: u64,
        total_released: u64,

        const Slot = struct {
            data: T,
            next_free: ?u32,
            in_use: bool,
        };

        pub fn init(backing: std.mem.Allocator, capacity: usize) !Self {
            const slots = try backing.alloc(Slot, capacity);
            for (slots, 0..) |*slot, i| {
                slot.in_use = false;
                slot.next_free = if (i + 1 < capacity) @intCast(i + 1) else null;
            }
            return .{
                .slots = slots,
                .free_head = if (capacity > 0) 0 else null,
                .backing = backing,
                .live_count = 0,
                .peak_count = 0,
                .total_acquired = 0,
                .total_released = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.backing.free(self.slots);
            self.slots = &.{};
            self.free_head = null;
        }

        pub fn capacity(self: Self) usize {
            return self.slots.len;
        }

        pub fn available(self: Self) usize {
            return self.slots.len - self.live_count;
        }

        pub fn liveCount(self: Self) usize {
            return self.live_count;
        }

        pub fn peakCount(self: Self) usize {
            return self.peak_count;
        }

        pub fn isFull(self: Self) bool {
            return self.free_head == null;
        }

        pub fn isEmpty(self: Self) bool {
            return self.live_count == 0;
        }

        pub fn acquire(self: *Self) ?*T {
            const head = self.free_head orelse return null;
            const slot = &self.slots[head];
            self.free_head = slot.next_free;
            slot.in_use = true;
            slot.next_free = null;
            self.live_count += 1;
            self.total_acquired += 1;
            if (self.live_count > self.peak_count) {
                self.peak_count = self.live_count;
            }
            return &slot.data;
        }

        pub fn acquireOrError(self: *Self) !*T {
            return self.acquire() orelse error.PoolExhausted;
        }

        pub fn release(self: *Self, ptr: *T) void {
            const addr = @intFromPtr(ptr);
            const base = @intFromPtr(self.slots.ptr);
            const data_offset = @offsetOf(Slot, "data");
            if (addr < base + data_offset) return;
            const slot_index = (addr - base - data_offset) / @sizeOf(Slot);
            if (slot_index >= self.slots.len) return;
            const slot = &self.slots[slot_index];
            if (!slot.in_use) return;
            slot.in_use = false;
            slot.next_free = self.free_head;
            self.free_head = @intCast(slot_index);
            self.live_count -= 1;
            self.total_released += 1;
        }

        pub fn acquireWithValue(self: *Self, value: T) ?*T {
            const ptr = self.acquire() orelse return null;
            ptr.* = value;
            return ptr;
        }

        pub fn clear(self: *Self) void {
            for (self.slots, 0..) |*slot, i| {
                slot.in_use = false;
                slot.next_free = if (i + 1 < self.slots.len) @intCast(i + 1) else null;
            }
            self.free_head = if (self.slots.len > 0) 0 else null;
            self.live_count = 0;
        }

        pub fn resetStats(self: *Self) void {
            self.total_acquired = 0;
            self.total_released = 0;
            self.peak_count = self.live_count;
        }

        pub fn usagePercent(self: Self) f64 {
            if (self.slots.len == 0) return 0;
            return @as(f64, @floatFromInt(self.live_count)) / @as(f64, @floatFromInt(self.slots.len)) * 100.0;
        }
    };
}

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        pool: Pool(T),

        pub fn init(backing: std.mem.Allocator, capacity: usize) !Self {
            return .{ .pool = try Pool(T).init(backing, capacity) };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn push(self: *Self, value: T) !void {
            const ptr = self.pool.acquireOrError() catch return error.StackFull;
            ptr.* = value;
        }

        pub fn pop(self: *Self) ?T {
            var i: usize = 0;
            while (i < self.pool.slots.len) : (i += 1) {
                if (self.pool.slots[i].in_use) {
                    const v = self.pool.slots[i].data;
                    self.pool.release(&self.pool.slots[i].data);
                    return v;
                }
            }
            return null;
        }

        pub fn count(self: Self) usize {
            return self.pool.liveCount();
        }
    };
}

test "Pool init" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();
    try std.testing.expectEqual(@as(usize, 10), p.capacity());
    try std.testing.expectEqual(@as(usize, 10), p.available());
    try std.testing.expect(p.isEmpty());
}

test "Pool acquire" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();

    const a = p.acquire().?;
    a.* = 42;
    try std.testing.expectEqual(@as(u32, 42), a.*);
    try std.testing.expectEqual(@as(usize, 1), p.liveCount());
    try std.testing.expectEqual(@as(usize, 9), p.available());
}

test "Pool release" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();

    const a = p.acquire().?;
    p.release(a);
    try std.testing.expectEqual(@as(usize, 0), p.liveCount());
    try std.testing.expect(p.isEmpty());
}

test "Pool exhausted" {
    var p = try Pool(u32).init(std.testing.allocator, 2);
    defer p.deinit();

    _ = p.acquire().?;
    _ = p.acquire().?;
    try std.testing.expect(p.isFull());
    try std.testing.expect(p.acquire() == null);
}

test "Pool reuse" {
    var p = try Pool(u32).init(std.testing.allocator, 1);
    defer p.deinit();

    const a = p.acquire().?;
    p.release(a);
    const b = p.acquire().?;
    try std.testing.expectEqual(@as(usize, 1), p.liveCount());
    _ = b;
}

test "Pool peak count" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();

    const a = p.acquire().?;
    const b = p.acquire().?;
    const c = p.acquire().?;
    try std.testing.expectEqual(@as(usize, 3), p.peakCount());
    p.release(a);
    p.release(b);
    p.release(c);
    try std.testing.expectEqual(@as(usize, 3), p.peakCount());
}

test "Pool acquireWithValue" {
    var p = try Pool(u32).init(std.testing.allocator, 4);
    defer p.deinit();

    const a = p.acquireWithValue(42).?;
    try std.testing.expectEqual(@as(u32, 42), a.*);
}

test "Pool clear" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();

    _ = p.acquire().?;
    _ = p.acquire().?;
    p.clear();
    try std.testing.expectEqual(@as(usize, 0), p.liveCount());
    try std.testing.expectEqual(@as(usize, 10), p.available());
}

test "Pool usagePercent" {
    var p = try Pool(u32).init(std.testing.allocator, 10);
    defer p.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), p.usagePercent());
    _ = p.acquire().?;
    try std.testing.expectEqual(@as(f64, 10.0), p.usagePercent());
}

test "Pool many alloc release" {
    var p = try Pool(u64).init(std.testing.allocator, 100);
    defer p.deinit();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const ptr = p.acquire().?;
        ptr.* = i;
    }
    try std.testing.expect(p.isFull());

    i = 0;
    while (i < 100) : (i += 1) {
        p.release(&p.slots[i].data);
    }
    try std.testing.expect(p.isEmpty());
}
