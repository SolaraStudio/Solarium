const std = @import("std");

pub const Arena = struct {
    buffer: []u8,
    offset: usize,
    backing: std.mem.Allocator,
    owns_buffer: bool,

    pub fn init(backing: std.mem.Allocator, size: usize) !Arena {
        const buffer = try backing.alloc(u8, size);
        return .{
            .buffer = buffer,
            .offset = 0,
            .backing = backing,
            .owns_buffer = true,
        };
    }

    pub fn initStatic(buffer: []u8) Arena {
        return .{
            .buffer = buffer,
            .offset = 0,
            .backing = std.heap.page_allocator,
            .owns_buffer = false,
        };
    }

    pub fn deinit(self: *Arena) void {
        if (self.owns_buffer and self.buffer.len > 0) {
            self.backing.free(self.buffer);
        }
        self.buffer = &.{};
        self.offset = 0;
    }

    pub fn alloc(self: *Arena, size: usize, alignment: usize) ?[]u8 {
        if (size == 0) return &.{};
        const aligned = std.mem.alignForward(usize, self.offset, alignment);
        const end = aligned + size;
        if (end > self.buffer.len) return null;
        const slice = self.buffer[aligned..end];
        self.offset = end;
        return slice;
    }

    pub fn allocTyped(self: *Arena, comptime T: type, count: usize) ?[]T {
        const bytes = self.alloc(@sizeOf(T) * count, @alignOf(T)) orelse return null;
        const ptr: [*]T = @alignCast(@ptrCast(bytes.ptr));
        return ptr[0..count];
    }

    pub fn create(self: *Arena, comptime T: type) ?*T {
        const slice = self.allocTyped(T, 1) orelse return null;
        return &slice[0];
    }

    pub fn dupe(self: *Arena, bytes: []const u8) ?[]u8 {
        const out = self.alloc(bytes.len, 1) orelse return null;
        @memcpy(out, bytes);
        return out;
    }

    pub fn dupeZ(self: *Arena, bytes: []const u8) ?[:0]u8 {
        const out = self.alloc(bytes.len + 1, 1) orelse return null;
        @memcpy(out[0..bytes.len], bytes);
        out[bytes.len] = 0;
        return out[0..bytes.len :0];
    }

    pub fn reset(self: *Arena) void {
        self.offset = 0;
    }

    pub fn used(self: Arena) usize {
        return self.offset;
    }

    pub fn capacity(self: Arena) usize {
        return self.buffer.len;
    }

    pub fn remaining(self: Arena) usize {
        return self.buffer.len - self.offset;
    }

    pub fn isEmpty(self: Arena) bool {
        return self.offset == 0;
    }

    pub fn usagePercent(self: Arena) f64 {
        if (self.buffer.len == 0) return 0;
        return @as(f64, @floatFromInt(self.offset)) / @as(f64, @floatFromInt(self.buffer.len)) * 100.0;
    }

    pub fn snapshot(self: Arena) usize {
        return self.offset;
    }

    pub fn restore(self: *Arena, mark: usize) void {
        if (mark <= self.offset) {
            self.offset = mark;
        }
    }
};

pub const ScopedArena = struct {
    arena: *Arena,
    mark: usize,

    pub fn init(arena: *Arena) ScopedArena {
        return .{ .arena = arena, .mark = arena.snapshot() };
    }

    pub fn deinit(self: *ScopedArena) void {
        self.arena.restore(self.mark);
    }
};

test "init and deinit" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();
    try std.testing.expectEqual(@as(usize, 1024), arena.capacity());
    try std.testing.expectEqual(@as(usize, 0), arena.used());
}

test "alloc basic" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const a = arena.alloc(10, 1).?;
    try std.testing.expectEqual(@as(usize, 10), a.len);
    try std.testing.expectEqual(@as(usize, 10), arena.used());
}

test "alloc alignment" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    _ = arena.alloc(1, 1).?;
    const b = arena.alloc(8, 8).?;
    const addr = @intFromPtr(b.ptr);
    try std.testing.expectEqual(@as(usize, 0), addr % 8);
}

test "alloc exhausted" {
    var arena = try Arena.init(std.testing.allocator, 16);
    defer arena.deinit();

    _ = arena.alloc(10, 1).?;
    try std.testing.expect(arena.alloc(10, 1) == null);
}

test "allocTyped" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const s = arena.allocTyped(u32, 10).?;
    try std.testing.expectEqual(@as(usize, 10), s.len);
}

test "create" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const p = arena.create(u32).?;
    p.* = 42;
    try std.testing.expectEqual(@as(u32, 42), p.*);
}

test "dupe" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const copy = arena.dupe("hello").?;
    try std.testing.expectEqualStrings("hello", copy);
}

test "dupeZ" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const copy = arena.dupeZ("hello").?;
    try std.testing.expectEqualStrings("hello", copy);
    try std.testing.expectEqual(@as(u8, 0), copy.ptr[copy.len]);
}

test "reset" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    _ = arena.alloc(100, 1);
    try std.testing.expectEqual(@as(usize, 100), arena.used());
    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.used());
}

test "remaining" {
    var arena = try Arena.init(std.testing.allocator, 100);
    defer arena.deinit();

    _ = arena.alloc(30, 1);
    try std.testing.expectEqual(@as(usize, 70), arena.remaining());
}

test "isEmpty" {
    var arena = try Arena.init(std.testing.allocator, 100);
    defer arena.deinit();

    try std.testing.expect(arena.isEmpty());
    _ = arena.alloc(10, 1);
    try std.testing.expect(!arena.isEmpty());
}

test "snapshot and restore" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    _ = arena.alloc(100, 1);
    const mark = arena.snapshot();
    _ = arena.alloc(200, 1);
    try std.testing.expectEqual(@as(usize, 300), arena.used());
    arena.restore(mark);
    try std.testing.expectEqual(@as(usize, 100), arena.used());
}

test "initStatic" {
    var buf: [64]u8 = undefined;
    var arena = Arena.initStatic(&buf);
    defer arena.deinit();

    _ = arena.alloc(32, 1).?;
    try std.testing.expectEqual(@as(usize, 32), arena.used());
}

test "ScopedArena" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    _ = arena.alloc(50, 1);

    {
        var scope = ScopedArena.init(&arena);
        defer scope.deinit();
        _ = arena.alloc(100, 1);
        try std.testing.expectEqual(@as(usize, 150), arena.used());
    }

    try std.testing.expectEqual(@as(usize, 50), arena.used());
}

test "alloc zero returns empty" {
    var arena = try Arena.init(std.testing.allocator, 1024);
    defer arena.deinit();

    const s = arena.alloc(0, 1).?;
    try std.testing.expectEqual(@as(usize, 0), s.len);
    try std.testing.expectEqual(@as(usize, 0), arena.used());
}

test "usagePercent" {
    var arena = try Arena.init(std.testing.allocator, 100);
    defer arena.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), arena.usagePercent());
    _ = arena.alloc(50, 1);
    try std.testing.expectEqual(@as(f64, 50.0), arena.usagePercent());
}
