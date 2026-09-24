const std = @import("std");

pub const MAX_CODEPOINT: u21 = 0x10FFFF;
pub const MAX_ASCII: u21 = 0x7F;
pub const SURROGATE_START: u21 = 0xD800;
pub const SURROGATE_END: u21 = 0xDFFF;
pub const REPLACEMENT_CHAR: u21 = 0xFFFD;

pub const DecodeResult = struct {
    codepoint: u21,
    length: u3,
};

pub fn byteLength(cp: u21) u3 {
    if (cp <= 0x7F) return 1;
    if (cp <= 0x7FF) return 2;
    if (cp <= 0xFFFF) return 3;
    return 4;
}

pub fn isValidCodepoint(cp: u21) bool {
    if (cp > MAX_CODEPOINT) return false;
    if (cp >= SURROGATE_START and cp <= SURROGATE_END) return false;
    return true;
}

pub fn encode(cp: u21, buffer: []u8) ?u3 {
    if (!isValidCodepoint(cp)) return null;
    const len = byteLength(cp);
    if (buffer.len < len) return null;

    switch (len) {
        1 => {
            buffer[0] = @intCast(cp);
        },
        2 => {
            buffer[0] = @intCast(0xC0 | (cp >> 6));
            buffer[1] = @intCast(0x80 | (cp & 0x3F));
        },
        3 => {
            buffer[0] = @intCast(0xE0 | (cp >> 12));
            buffer[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
            buffer[2] = @intCast(0x80 | (cp & 0x3F));
        },
        4 => {
            buffer[0] = @intCast(0xF0 | (cp >> 18));
            buffer[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
            buffer[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
            buffer[3] = @intCast(0x80 | (cp & 0x3F));
        },
        else => return null,
    }
    return len;
}

pub fn decode(s: []const u8) ?DecodeResult {
    if (s.len == 0) return null;
    const b0 = s[0];

    if (b0 < 0x80) {
        return .{ .codepoint = b0, .length = 1 };
    }

    if (b0 < 0xC2) return null;

    if (b0 < 0xE0) {
        if (s.len < 2) return null;
        if (!isContinuation(s[1])) return null;
        const cp: u21 = (@as(u21, b0 & 0x1F) << 6) | @as(u21, s[1] & 0x3F);
        return .{ .codepoint = cp, .length = 2 };
    }

    if (b0 < 0xF0) {
        if (s.len < 3) return null;
        if (!isContinuation(s[1]) or !isContinuation(s[2])) return null;
        if (b0 == 0xE0 and s[1] < 0xA0) return null;
        if (b0 == 0xED and s[1] >= 0xA0) return null;
        const cp: u21 = (@as(u21, b0 & 0x0F) << 12) |
            (@as(u21, s[1] & 0x3F) << 6) |
            @as(u21, s[2] & 0x3F);
        return .{ .codepoint = cp, .length = 3 };
    }

    if (b0 < 0xF5) {
        if (s.len < 4) return null;
        if (!isContinuation(s[1]) or !isContinuation(s[2]) or !isContinuation(s[3])) return null;
        if (b0 == 0xF0 and s[1] < 0x90) return null;
        if (b0 == 0xF4 and s[1] >= 0x90) return null;
        const cp: u21 = (@as(u21, b0 & 0x07) << 18) |
            (@as(u21, s[1] & 0x3F) << 12) |
            (@as(u21, s[2] & 0x3F) << 6) |
            @as(u21, s[3] & 0x3F);
        return .{ .codepoint = cp, .length = 4 };
    }

    return null;
}

pub fn isContinuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

pub fn isAscii(b: u8) bool {
    return b < 0x80;
}

pub fn validate(s: []const u8) bool {
    var i: usize = 0;
    while (i < s.len) {
        const result = decode(s[i..]) orelse return false;
        i += result.length;
    }
    return true;
}

pub fn codepointCount(s: []const u8) ?usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        const result = decode(s[i..]) orelse return null;
        i += result.length;
        count += 1;
    }
    return count;
}

pub fn byteLengthOf(s: []const u8) usize {
    return s.len;
}

pub fn encodeSlice(cp: u21, out: []u8) ?[]u8 {
    const n = encode(cp, out) orelse return null;
    return out[0..n];
}

pub const Iterator = struct {
    bytes: []const u8,
    pos: usize,

    pub fn init(s: []const u8) Iterator {
        return .{ .bytes = s, .pos = 0 };
    }

    pub fn next(self: *Iterator) ?DecodeResult {
        if (self.pos >= self.bytes.len) return null;
        const result = decode(self.bytes[self.pos..]) orelse {
            self.pos = self.bytes.len;
            return null;
        };
        self.pos += result.length;
        return result;
    }

    pub fn peek(self: Iterator) ?DecodeResult {
        if (self.pos >= self.bytes.len) return null;
        return decode(self.bytes[self.pos..]);
    }

    pub fn reset(self: *Iterator) void {
        self.pos = 0;
    }

    pub fn remaining(self: Iterator) usize {
        return self.bytes.len - self.pos;
    }
};

pub fn countCodepoints(s: []const u8) usize {
    return codepointCount(s) orelse 0;
}

pub fn byteOffsetOfCodepoint(s: []const u8, index: usize) ?usize {
    var i: usize = 0;
    var n: usize = 0;
    while (i < s.len) {
        if (n == index) return i;
        const result = decode(s[i..]) orelse return null;
        i += result.length;
        n += 1;
    }
    if (n == index) return i;
    return null;
}

pub fn codepointAt(s: []const u8, index: usize) ?u21 {
    const offset = byteOffsetOfCodepoint(s, index) orelse return null;
    if (offset >= s.len) return null;
    const result = decode(s[offset..]) orelse return null;
    return result.codepoint;
}

test "byteLength" {
    try std.testing.expectEqual(@as(u3, 1), byteLength(0x41));
    try std.testing.expectEqual(@as(u3, 2), byteLength(0x80));
    try std.testing.expectEqual(@as(u3, 3), byteLength(0x800));
    try std.testing.expectEqual(@as(u3, 4), byteLength(0x10000));
    try std.testing.expectEqual(@as(u3, 4), byteLength(0x10FFFF));
}

test "isValidCodepoint" {
    try std.testing.expect(isValidCodepoint('A'));
    try std.testing.expect(isValidCodepoint(0x7F));
    try std.testing.expect(isValidCodepoint(0x80));
    try std.testing.expect(isValidCodepoint(0x10FFFF));
    try std.testing.expect(!isValidCodepoint(0xD800));
    try std.testing.expect(!isValidCodepoint(0xDFFF));
    try std.testing.expect(!isValidCodepoint(0x110000));
}

test "encode ascii" {
    var buf: [4]u8 = undefined;
    const n = encode('A', &buf).?;
    try std.testing.expectEqual(@as(u3, 1), n);
    try std.testing.expectEqual(@as(u8, 'A'), buf[0]);
}

test "encode two-byte" {
    var buf: [4]u8 = undefined;
    const n = encode(0x80, &buf).?;
    try std.testing.expectEqual(@as(u3, 2), n);
}

test "encode three-byte" {
    var buf: [4]u8 = undefined;
    const n = encode(0x20AC, &buf).?;
    try std.testing.expectEqual(@as(u3, 3), n);
}

test "encode four-byte" {
    var buf: [4]u8 = undefined;
    const n = encode(0x1F600, &buf).?;
    try std.testing.expectEqual(@as(u3, 4), n);
}

test "encode rejects surrogate" {
    var buf: [4]u8 = undefined;
    try std.testing.expect(encode(0xD800, &buf) == null);
    try std.testing.expect(encode(0xDFFF, &buf) == null);
}

test "encode rejects too large" {
    var buf: [4]u8 = undefined;
    try std.testing.expect(encode(0x110000, &buf) == null);
}

test "encode buffer too small" {
    var buf: [1]u8 = undefined;
    try std.testing.expect(encode(0x80, &buf) == null);
}

test "decode ascii" {
    const r = decode("A").?;
    try std.testing.expectEqual(@as(u21, 'A'), r.codepoint);
    try std.testing.expectEqual(@as(u3, 1), r.length);
}

test "decode two-byte" {
    var buf: [4]u8 = undefined;
    _ = encode(0x80, &buf);
    const r = decode(buf[0..2]).?;
    try std.testing.expectEqual(@as(u21, 0x80), r.codepoint);
}

test "decode empty" {
    try std.testing.expect(decode("") == null);
}

test "decode invalid continuation" {
    try std.testing.expect(decode(&[_]u8{ 0xC2, 0x00 }) == null);
    try std.testing.expect(decode(&[_]u8{0xC2}) == null);
}

test "round trip" {
    const cps = [_]u21{ 'A', 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0x10FFFF };
    for (cps) |cp| {
        if (!isValidCodepoint(cp)) continue;
        var buf: [4]u8 = undefined;
        const n = encode(cp, &buf).?;
        const r = decode(buf[0..n]).?;
        try std.testing.expectEqual(cp, r.codepoint);
    }
}

test "validate" {
    try std.testing.expect(validate("hello"));
    try std.testing.expect(validate(""));
    try std.testing.expect(!validate(&[_]u8{ 0xC2, 0x00 }));
}

test "codepointCount" {
    try std.testing.expectEqual(@as(?usize, 5), codepointCount("hello"));
    try std.testing.expectEqual(@as(?usize, 0), codepointCount(""));
    try std.testing.expect(codepointCount(&[_]u8{ 0xC2, 0x00 }) == null);
}

test "Iterator" {
    var it = Iterator.init("héllo");
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 5), count);
}

test "Iterator peek" {
    var it = Iterator.init("ABC");
    const p = it.peek().?;
    try std.testing.expectEqual(@as(u21, 'A'), p.codepoint);
    _ = it.next();
    const p2 = it.peek().?;
    try std.testing.expectEqual(@as(u21, 'B'), p2.codepoint);
}

test "Iterator reset" {
    var it = Iterator.init("AB");
    _ = it.next();
    it.reset();
    try std.testing.expectEqual(@as(u21, 'A'), it.peek().?.codepoint);
}

test "Iterator remaining" {
    var it = Iterator.init("ABC");
    try std.testing.expectEqual(@as(usize, 3), it.remaining());
    _ = it.next();
    try std.testing.expectEqual(@as(usize, 2), it.remaining());
}

test "byteOffsetOfCodepoint" {
    try std.testing.expectEqual(@as(?usize, 0), byteOffsetOfCodepoint("abc", 0));
    try std.testing.expectEqual(@as(?usize, 1), byteOffsetOfCodepoint("abc", 1));
    try std.testing.expectEqual(@as(?usize, 3), byteOffsetOfCodepoint("abc", 3));
    try std.testing.expect(byteOffsetOfCodepoint("abc", 10) == null);
}

test "codepointAt" {
    try std.testing.expectEqual(@as(?u21, 'a'), codepointAt("abc", 0));
    try std.testing.expectEqual(@as(?u21, 'b'), codepointAt("abc", 1));
    try std.testing.expect(codepointAt("abc", 10) == null);
}
