const std = @import("std");

pub const Position = struct {
    offset: u32,
    line: u32,
    column: u32,

    pub fn init() Position {
        return .{ .offset = 0, .line = 1, .column = 1 };
    }

    pub fn advance(self: *Position, byte: u8) void {
        self.offset += 1;
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else if (byte == '\r') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    pub fn advanceN(self: *Position, bytes: []const u8) void {
        for (bytes) |b| self.advance(b);
    }

    pub fn advanceAscii(self: *Position, count: u32) void {
        self.offset += count;
        self.column += count;
    }

    pub fn toOffset(self: Position) u32 {
        return self.offset;
    }

    pub fn reset(self: *Position) void {
        self.offset = 0;
        self.line = 1;
        self.column = 1;
    }

    pub fn clone(self: Position) Position {
        return .{ .offset = self.offset, .line = self.line, .column = self.column };
    }

    pub fn eql(self: Position, other: Position) bool {
        return self.offset == other.offset and
            self.line == other.line and
            self.column == other.column;
    }

    pub fn order(self: Position, other: Position) std.math.Order {
        return std.math.order(self.offset, other.offset);
    }
};

pub const Span = struct {
    start: Position,
    end: Position,

    pub fn init(start: Position, end: Position) Span {
        return .{ .start = start, .end = end };
    }

    pub fn empty() Span {
        const p = Position.init();
        return .{ .start = p, .end = p };
    }

    pub fn len(self: Span) u32 {
        return self.end.offset - self.start.offset;
    }

    pub fn isEmpty(self: Span) bool {
        return self.start.offset == self.end.offset;
    }

    pub fn contains(self: Span, offset: u32) bool {
        return offset >= self.start.offset and offset < self.end.offset;
    }

    pub fn containsPosition(self: Span, pos: Position) bool {
        return self.contains(pos.offset);
    }

    pub fn overlaps(self: Span, other: Span) bool {
        return self.start.offset < other.end.offset and other.start.offset < self.end.offset;
    }

    pub fn merge(self: Span, other: Span) Span {
        const s = if (self.start.offset <= other.start.offset) self.start else other.start;
        const e = if (self.end.offset >= other.end.offset) self.end else other.end;
        return .{ .start = s, .end = e };
    }
};

pub const Location = struct {
    line: u32,
    column: u32,

    pub fn init(line: u32, column: u32) Location {
        return .{ .line = line, .column = column };
    }

    pub fn format(
        self: Location,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{d}:{d}", .{ self.line, self.column });
    }
};

pub fn offsetToLine(source: []const u8, target_offset: u32) u32 {
    var line: u32 = 1;
    var i: u32 = 0;
    const limit = @min(target_offset, @as(u32, @intCast(source.len)));
    while (i < limit) : (i += 1) {
        if (source[i] == '\n') line += 1;
    }
    return line;
}

pub fn offsetToColumn(source: []const u8, target_offset: u32) u32 {
    var column: u32 = 1;
    var i: u32 = 0;
    const limit = @min(target_offset, @as(u32, @intCast(source.len)));
    while (i < limit) : (i += 1) {
        if (source[i] == '\n') {
            column = 1;
        } else {
            column += 1;
        }
    }
    return column;
}

pub fn offsetToLocation(source: []const u8, target_offset: u32) Location {
    var line: u32 = 1;
    var column: u32 = 1;
    var i: u32 = 0;
    const limit = @min(target_offset, @as(u32, @intCast(source.len)));
    while (i < limit) : (i += 1) {
        if (source[i] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }
    return .{ .line = line, .column = column };
}

test "Position init" {
    const p = Position.init();
    try std.testing.expectEqual(@as(u32, 0), p.offset);
    try std.testing.expectEqual(@as(u32, 1), p.line);
    try std.testing.expectEqual(@as(u32, 1), p.column);
}

test "Position advance ascii" {
    var p = Position.init();
    p.advance('a');
    try std.testing.expectEqual(@as(u32, 1), p.offset);
    try std.testing.expectEqual(@as(u32, 1), p.line);
    try std.testing.expectEqual(@as(u32, 2), p.column);
}

test "Position advance newline" {
    var p = Position.init();
    p.advance('a');
    p.advance('\n');
    p.advance('b');
    try std.testing.expectEqual(@as(u32, 3), p.offset);
    try std.testing.expectEqual(@as(u32, 2), p.line);
    try std.testing.expectEqual(@as(u32, 2), p.column);
}

test "Position advance carriage return" {
    var p = Position.init();
    p.advance('a');
    p.advance('\r');
    try std.testing.expectEqual(@as(u32, 2), p.line);
    try std.testing.expectEqual(@as(u32, 1), p.column);
}

test "Position advanceN" {
    var p = Position.init();
    p.advanceN("abc");
    try std.testing.expectEqual(@as(u32, 3), p.offset);
    try std.testing.expectEqual(@as(u32, 4), p.column);
}

test "Position clone" {
    var p = Position.init();
    p.advance('a');
    const c = p.clone();
    try std.testing.expect(p.eql(c));
    p.advance('b');
    try std.testing.expect(!p.eql(c));
}

test "Position reset" {
    var p = Position.init();
    p.advanceN("abc");
    p.reset();
    try std.testing.expectEqual(@as(u32, 0), p.offset);
    try std.testing.expectEqual(@as(u32, 1), p.line);
}

test "Position order" {
    const a = Position{ .offset = 1, .line = 1, .column = 2 };
    const b = Position{ .offset = 2, .line = 1, .column = 3 };
    try std.testing.expectEqual(std.math.Order.lt, a.order(b));
}

test "Span init" {
    const s = Span.init(
        Position{ .offset = 0, .line = 1, .column = 1 },
        Position{ .offset = 5, .line = 1, .column = 6 },
    );
    try std.testing.expectEqual(@as(u32, 5), s.len());
}

test "Span empty" {
    const s = Span.empty();
    try std.testing.expect(s.isEmpty());
    try std.testing.expectEqual(@as(u32, 0), s.len());
}

test "Span contains" {
    const s = Span.init(
        Position{ .offset = 10, .line = 1, .column = 11 },
        Position{ .offset = 20, .line = 1, .column = 21 },
    );
    try std.testing.expect(s.contains(10));
    try std.testing.expect(s.contains(15));
    try std.testing.expect(s.contains(19));
    try std.testing.expect(!s.contains(20));
    try std.testing.expect(!s.contains(9));
}

test "Span overlaps" {
    const a = Span.init(
        Position{ .offset = 0, .line = 1, .column = 1 },
        Position{ .offset = 10, .line = 1, .column = 11 },
    );
    const b = Span.init(
        Position{ .offset = 5, .line = 1, .column = 6 },
        Position{ .offset = 15, .line = 1, .column = 16 },
    );
    const c = Span.init(
        Position{ .offset = 20, .line = 1, .column = 21 },
        Position{ .offset = 30, .line = 1, .column = 31 },
    );
    try std.testing.expect(a.overlaps(b));
    try std.testing.expect(!a.overlaps(c));
}

test "Span merge" {
    const a = Span.init(
        Position{ .offset = 0, .line = 1, .column = 1 },
        Position{ .offset = 10, .line = 1, .column = 11 },
    );
    const b = Span.init(
        Position{ .offset = 5, .line = 1, .column = 6 },
        Position{ .offset = 20, .line = 1, .column = 21 },
    );
    const m = a.merge(b);
    try std.testing.expectEqual(@as(u32, 0), m.start.offset);
    try std.testing.expectEqual(@as(u32, 20), m.end.offset);
}

test "Location init" {
    const l = Location.init(3, 15);
    try std.testing.expectEqual(@as(u32, 3), l.line);
    try std.testing.expectEqual(@as(u32, 15), l.column);
}

test "offsetToLine" {
    const src = "line1\nline2\nline3";
    try std.testing.expectEqual(@as(u32, 1), offsetToLine(src, 0));
    try std.testing.expectEqual(@as(u32, 1), offsetToLine(src, 4));
    try std.testing.expectEqual(@as(u32, 2), offsetToLine(src, 6));
    try std.testing.expectEqual(@as(u32, 3), offsetToLine(src, 12));
}

test "offsetToColumn" {
    const src = "abc\ndef";
    try std.testing.expectEqual(@as(u32, 1), offsetToColumn(src, 0));
    try std.testing.expectEqual(@as(u32, 4), offsetToColumn(src, 3));
    try std.testing.expectEqual(@as(u32, 1), offsetToColumn(src, 4));
    try std.testing.expectEqual(@as(u32, 2), offsetToColumn(src, 5));
}

test "offsetToLocation" {
    const src = "abc\ndefgh";
    const loc = offsetToLocation(src, 6);
    try std.testing.expectEqual(@as(u32, 2), loc.line);
    try std.testing.expectEqual(@as(u32, 3), loc.column);
}
