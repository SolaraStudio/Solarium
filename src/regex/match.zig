const std = @import("std");

pub const MatchError = error{
    NoMatch,
    InvalidCaptureIndex,
    OutOfMemory,
};

pub const Group = struct {
    start: usize,
    end: usize,

    pub fn len(self: Group) usize {
        return self.end - self.start;
    }

    pub fn isEmpty(self: Group) bool {
        return self.start == self.end;
    }
};

pub const Match = struct {
    start: usize,
    end: usize,
    groups: []Group,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, group_count: usize) !Match {
        const groups = try allocator.alloc(Group, group_count);
        for (groups) |*g| {
            g.* = .{ .start = 0, .end = 0 };
        }
        return .{
            .start = 0,
            .end = 0,
            .groups = groups,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Match) void {
        self.allocator.free(self.groups);
        self.groups = &.{};
    }

    pub fn len(self: Match) usize {
        return self.end - self.start;
    }

    pub fn isEmpty(self: Match) bool {
        return self.start == self.end;
    }

    pub fn groupCount(self: Match) usize {
        return self.groups.len;
    }

    pub fn group(self: Match, index: usize) ?Group {
        if (index >= self.groups.len) return null;
        return self.groups[index];
    }

    pub fn groupText(self: Match, source: []const u8, index: usize) ?[]const u8 {
        const g = self.group(index) orelse return null;
        if (g.start > source.len or g.end > source.len) return null;
        return source[g.start..g.end];
    }

    pub fn text(self: Match, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }

    pub fn captureCount(self: Match) usize {
        return self.groups.len;
    }
};

pub const MatchIterator = struct {
    source: []const u8,
    positions: []const usize,
    groups: []Group,
    current: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, max_matches: usize) !MatchIterator {
        return .{
            .source = source,
            .positions = try allocator.alloc(usize, max_matches * 2),
            .groups = try allocator.alloc(Group, max_matches),
            .current = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MatchIterator) void {
        self.allocator.free(self.positions);
        self.allocator.free(self.groups);
    }
};

pub const Captures = struct {
    text: []const u8,
    start: usize,
    end: usize,

    pub fn init(text: []const u8, start: usize, end: usize) Captures {
        return .{ .text = text, .start = start, .end = end };
    }

    pub fn slice(self: Captures) []const u8 {
        return self.text[self.start..self.end];
    }
};

pub fn makeMatch(
    allocator: std.mem.Allocator,
    start: usize,
    end: usize,
    group_count: usize,
) !Match {
    var m = try Match.init(allocator, group_count);
    m.start = start;
    m.end = end;
    return m;
}

test "Group len and isEmpty" {
    const g = Group{ .start = 5, .end = 10 };
    try std.testing.expectEqual(@as(usize, 5), g.len());
    try std.testing.expect(!g.isEmpty());

    const empty = Group{ .start = 5, .end = 5 };
    try std.testing.expect(empty.isEmpty());
}

test "Match init" {
    var m = try Match.init(std.testing.allocator, 3);
    defer m.deinit();
    try std.testing.expectEqual(@as(usize, 3), m.groupCount());
}

test "Match group and groupText" {
    var m = try Match.init(std.testing.allocator, 2);
    defer m.deinit();
    m.start = 0;
    m.end = 5;
    m.groups[0] = .{ .start = 0, .end = 5 };
    m.groups[1] = .{ .start = 1, .end = 3 };

    const g = m.group(0).?;
    try std.testing.expectEqual(@as(usize, 0), g.start);
    try std.testing.expectEqual(@as(usize, 5), g.end);

    const text = "hello world";
    try std.testing.expectEqualStrings("hello", m.groupText(text, 0).?);
    try std.testing.expectEqualStrings("el", m.groupText(text, 1).?);
}

test "Match group out of bounds" {
    var m = try Match.init(std.testing.allocator, 1);
    defer m.deinit();
    try std.testing.expect(m.group(5) == null);
    try std.testing.expect(m.groupText("test", 5) == null);
}

test "Match text slice" {
    var m = try Match.init(std.testing.allocator, 1);
    defer m.deinit();
    m.start = 6;
    m.end = 11;
    const text = "hello world";
    try std.testing.expectEqualStrings("world", m.text(text));
}

test "Match len and isEmpty" {
    var m = try Match.init(std.testing.allocator, 1);
    defer m.deinit();
    m.start = 0;
    m.end = 5;
    try std.testing.expectEqual(@as(usize, 5), m.len());
    try std.testing.expect(!m.isEmpty());

    m.end = 0;
    try std.testing.expect(m.isEmpty());
}

test "Captures slice" {
    const text = "hello world";
    const cap = Captures.init(text, 6, 11);
    try std.testing.expectEqualStrings("world", cap.slice());
}

test "makeMatch" {
    var m = try makeMatch(std.testing.allocator, 3, 8, 2);
    defer m.deinit();
    try std.testing.expectEqual(@as(usize, 3), m.start);
    try std.testing.expectEqual(@as(usize, 8), m.end);
    try std.testing.expectEqual(@as(usize, 2), m.groupCount());
}

test "MatchIterator init" {
    var it = try MatchIterator.init(std.testing.allocator, "test", 5);
    defer it.deinit();
    try std.testing.expectEqual(@as(usize, 0), it.current);
    try std.testing.expectEqual(@as(usize, 10), it.positions.len);
    try std.testing.expectEqual(@as(usize, 5), it.groups.len);
}
