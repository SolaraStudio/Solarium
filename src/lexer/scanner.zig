const std = @import("std");
const position = @import("position.zig");

pub const Position = position.Position;

pub const Scanner = struct {
    source: []const u8,
    pos: Position,
    index: u32,

    pub fn init(source: []const u8) Scanner {
        return .{
            .source = source,
            .pos = Position.init(),
            .index = 0,
        };
    }

    pub fn atEnd(self: Scanner) bool {
        return self.index >= self.source.len;
    }

    pub fn remaining(self: Scanner) u32 {
        if (self.index >= self.source.len) return 0;
        return @intCast(self.source.len - self.index);
    }

    pub fn peek(self: Scanner) ?u8 {
        if (self.index >= self.source.len) return null;
        return self.source[self.index];
    }

    pub fn peekAt(self: Scanner, ahead: u32) ?u8 {
        const target = self.index + ahead;
        if (target >= self.source.len) return null;
        return self.source[target];
    }

    pub fn peekByte(self: Scanner, offset: u32) u8 {
        const target = self.index + offset;
        if (target >= self.source.len) return 0;
        return self.source[target];
    }

    pub fn advance(self: *Scanner) ?u8 {
        if (self.index >= self.source.len) return null;
        const b = self.source[self.index];
        self.pos.advance(b);
        self.index += 1;
        return b;
    }

    pub fn advanceAscii(self: *Scanner, count: u32) void {
        var i: u32 = 0;
        while (i < count and self.index < self.source.len) : (i += 1) {
            _ = self.advance();
        }
    }

    pub fn advanceNewline(self: *Scanner) void {
        if (self.atEnd()) return;
        const b = self.source[self.index];
        if (b == '\r') {
            self.index += 1;
            if (self.index < self.source.len and self.source[self.index] == '\n') {
                self.index += 1;
            }
            self.pos.offset += if (b == '\r') 1 else 0;
            self.pos.line += 1;
            self.pos.column = 1;
        } else if (b == '\n') {
            self.index += 1;
            self.pos.offset += 1;
            self.pos.line += 1;
            self.pos.column = 1;
        }
    }

    pub fn match(self: *Scanner, expected: u8) bool {
        if (self.atEnd()) return false;
        if (self.source[self.index] != expected) return false;
        _ = self.advance();
        return true;
    }

    pub fn matchString(self: *Scanner, expected: []const u8) bool {
        if (self.index + expected.len > self.source.len) return false;
        if (!std.mem.eql(u8, self.source[self.index .. self.index + expected.len], expected)) return false;
        self.advanceAscii(@intCast(expected.len));
        return true;
    }

    pub fn current(self: Scanner) u8 {
        if (self.index >= self.source.len) return 0;
        return self.source[self.index];
    }

    pub fn currentPosition(self: Scanner) Position {
        return self.pos;
    }

    pub fn setIndex(self: *Scanner, index: u32) void {
        if (index > self.source.len) return;
        self.index = index;
    }

    pub fn slice(self: Scanner, start: u32) []const u8 {
        if (start > self.source.len) return &.{};
        const end = self.index;
        if (end < start) return &.{};
        return self.source[start..end];
    }

    pub fn sourceSlice(self: Scanner, start: u32, end: u32) []const u8 {
        if (start > self.source.len) return &.{};
        if (end > self.source.len) return &.{};
        if (end < start) return &.{};
        return self.source[start..end];
    }

    pub fn reset(self: *Scanner) void {
        self.index = 0;
        self.pos.reset();
    }

    pub fn getLine(self: Scanner) u32 {
        return self.pos.line;
    }

    pub fn getColumn(self: Scanner) u32 {
        return self.pos.column;
    }

    pub fn getOffset(self: Scanner) u32 {
        return self.index;
    }

    pub fn peekIsDigit(self: Scanner) bool {
        const b = self.peek() orelse return false;
        return b >= '0' and b <= '9';
    }

    pub fn peekIsHexDigit(self: Scanner) bool {
        const b = self.peek() orelse return false;
        return (b >= '0' and b <= '9') or
            (b >= 'a' and b <= 'f') or
            (b >= 'A' and b <= 'F');
    }

    pub fn peekIsLetter(self: Scanner) bool {
        const b = self.peek() orelse return false;
        return (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z');
    }

    pub fn peekIsWhitespace(self: Scanner) bool {
        const b = self.peek() orelse return false;
        return b == ' ' or b == '\t' or b == '\n' or b == '\r' or
            b == 0x0B or b == 0x0C;
    }

    pub fn peekIsLineTerminator(self: Scanner) bool {
        const b = self.peek() orelse return false;
        return b == '\n' or b == '\r';
    }

    pub fn skipWhitespace(self: *Scanner) void {
        while (!self.atEnd()) {
            const b = self.source[self.index];
            if (b == ' ' or b == '\t' or b == 0x0B or b == 0x0C) {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    pub fn skipLineTerminators(self: *Scanner) void {
        while (!self.atEnd()) {
            const b = self.source[self.index];
            if (b == '\n' or b == '\r') {
                self.advanceNewline();
            } else {
                break;
            }
        }
    }

    pub fn skipHorizontalWhitespace(self: *Scanner) bool {
        const before = self.index;
        while (!self.atEnd()) {
            const b = self.source[self.index];
            if (b == ' ' or b == '\t') {
                _ = self.advance();
            } else {
                break;
            }
        }
        return self.index != before;
    }

    pub fn skipInlineComment(self: *Scanner) bool {
        if (self.index + 1 >= self.source.len) return false;
        if (self.source[self.index] != '/') return false;
        if (self.source[self.index + 1] != '/') return false;
        self.advanceAscii(2);
        while (!self.atEnd()) {
            const b = self.source[self.index];
            if (b == '\n' or b == '\r') break;
            _ = self.advance();
        }
        return true;
    }

    pub fn skipBlockComment(self: *Scanner) bool {
        if (self.index + 1 >= self.source.len) return false;
        if (self.source[self.index] != '/') return false;
        if (self.source[self.index + 1] != '*') return false;
        self.advanceAscii(2);
        while (!self.atEnd()) {
            const b = self.source[self.index];
            if (b == '*' and self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                self.advanceAscii(2);
                return true;
            }
            if (b == '\n' or b == '\r') {
                self.advanceNewline();
            } else {
                _ = self.advance();
            }
        }
        return true;
    }

    pub fn lineNumberAt(self: Scanner, offset: u32) u32 {
        _ = self;
        _ = offset;
        return 0;
    }
};

test "Scanner init" {
    const s = Scanner.init("hello");
    try std.testing.expectEqual(@as(u32, 0), s.index);
    try std.testing.expectEqual(@as(usize, 5), s.source.len);
}

test "Scanner atEnd" {
    var s = Scanner.init("");
    try std.testing.expect(s.atEnd());
    s = Scanner.init("a");
    try std.testing.expect(!s.atEnd());
}

test "Scanner peek" {
    const s = Scanner.init("abc");
    try std.testing.expectEqual(@as(?u8, 'a'), s.peek());
}

test "Scanner peekAt" {
    const s = Scanner.init("abc");
    try std.testing.expectEqual(@as(?u8, 'a'), s.peekAt(0));
    try std.testing.expectEqual(@as(?u8, 'b'), s.peekAt(1));
    try std.testing.expectEqual(@as(?u8, 'c'), s.peekAt(2));
    try std.testing.expectEqual(@as(?u8, null), s.peekAt(3));
}

test "Scanner advance" {
    var s = Scanner.init("abc");
    try std.testing.expectEqual(@as(?u8, 'a'), s.advance());
    try std.testing.expectEqual(@as(u32, 1), s.index);
    try std.testing.expectEqual(@as(u32, 2), s.pos.column);
}

test "Scanner advance at end" {
    var s = Scanner.init("a");
    _ = s.advance();
    try std.testing.expectEqual(@as(?u8, null), s.advance());
}

test "Scanner advance newline tracking" {
    var s = Scanner.init("a\nb");
    _ = s.advance();
    _ = s.advance();
    try std.testing.expectEqual(@as(u32, 2), s.pos.line);
    try std.testing.expectEqual(@as(u32, 1), s.pos.column);
}

test "Scanner match" {
    var s = Scanner.init("abc");
    try std.testing.expect(s.match('a'));
    try std.testing.expectEqual(@as(u32, 1), s.index);
    try std.testing.expect(!s.match('x'));
}

test "Scanner matchString" {
    var s = Scanner.init("hello");
    try std.testing.expect(s.matchString("he"));
    try std.testing.expectEqual(@as(u32, 2), s.index);
    try std.testing.expect(s.matchString("llo"));
    try std.testing.expectEqual(@as(u32, 5), s.index);
}

test "Scanner matchString mismatch" {
    var s = Scanner.init("hello");
    try std.testing.expect(!s.matchString("world"));
    try std.testing.expectEqual(@as(u32, 0), s.index);
}

test "Scanner slice" {
    var s = Scanner.init("hello");
    s.advanceAscii(3);
    try std.testing.expectEqualStrings("hel", s.slice(0));
    try std.testing.expectEqualStrings("el", s.slice(1));
}

test "Scanner sourceSlice" {
    const s = Scanner.init("hello");
    try std.testing.expectEqualStrings("ell", s.sourceSlice(1, 4));
}

test "Scanner skipWhitespace" {
    var s = Scanner.init("   abc");
    s.skipWhitespace();
    try std.testing.expectEqual(@as(?u8, 'a'), s.peek());
}

test "Scanner skipInlineComment" {
    var s = Scanner.init("// comment\na");
    try std.testing.expect(s.skipInlineComment());
    try std.testing.expectEqual(@as(?u8, '\n'), s.peek());
}

test "Scanner skipBlockComment" {
    var s = Scanner.init("/* comment */a");
    try std.testing.expect(s.skipBlockComment());
    try std.testing.expectEqual(@as(?u8, 'a'), s.peek());
}

test "Scanner skipBlockComment with newline" {
    var s = Scanner.init("/* line1\nline2 */a");
    try std.testing.expect(s.skipBlockComment());
    try std.testing.expectEqual(@as(u32, 2), s.pos.line);
    try std.testing.expectEqual(@as(?u8, 'a'), s.peek());
}

test "Scanner reset" {
    var s = Scanner.init("abc");
    s.advanceAscii(2);
    s.reset();
    try std.testing.expectEqual(@as(u32, 0), s.index);
    try std.testing.expectEqual(@as(u32, 1), s.pos.line);
}

test "Scanner peekIsDigit" {
    const s = Scanner.init("5");
    try std.testing.expect(s.peekIsDigit());
    const s2 = Scanner.init("a");
    try std.testing.expect(!s2.peekIsDigit());
}

test "Scanner peekIsHexDigit" {
    const s = Scanner.init("f");
    try std.testing.expect(s.peekIsHexDigit());
    const s2 = Scanner.init("g");
    try std.testing.expect(!s2.peekIsHexDigit());
}

test "Scanner peekIsWhitespace" {
    const s = Scanner.init(" ");
    try std.testing.expect(s.peekIsWhitespace());
    const s2 = Scanner.init("a");
    try std.testing.expect(!s2.peekIsWhitespace());
}

test "Scanner getters" {
    var s = Scanner.init("abc");
    s.advanceAscii(2);
    try std.testing.expectEqual(@as(u32, 2), s.getOffset());
    try std.testing.expectEqual(@as(u32, 1), s.getLine());
    try std.testing.expectEqual(@as(u32, 3), s.getColumn());
}

test "Scanner remaining" {
    var s = Scanner.init("abc");
    try std.testing.expectEqual(@as(u32, 3), s.remaining());
    s.advanceAscii(1);
    try std.testing.expectEqual(@as(u32, 2), s.remaining());
}
