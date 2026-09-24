const std = @import("std");
const utf8 = @import("utf8.zig");

pub const HIGH_SURROGATE_MIN: u16 = 0xD800;
pub const HIGH_SURROGATE_MAX: u16 = 0xDBFF;
pub const LOW_SURROGATE_MIN: u16 = 0xDC00;
pub const LOW_SURROGATE_MAX: u16 = 0xDFFF;
pub const SURROGATE_BIAS: u21 = 0x10000;
pub const MAX_CODEPOINT: u21 = 0x10FFFF;

pub fn isHighSurrogate(u: u16) bool {
    return u >= HIGH_SURROGATE_MIN and u <= HIGH_SURROGATE_MAX;
}

pub fn isLowSurrogate(u: u16) bool {
    return u >= LOW_SURROGATE_MIN and u <= LOW_SURROGATE_MAX;
}

pub fn isSurrogate(u: u16) bool {
    return isHighSurrogate(u) or isLowSurrogate(u);
}

pub fn combineSurrogates(high: u16, low: u16) ?u21 {
    if (!isHighSurrogate(high) or !isLowSurrogate(low)) return null;
    const h: u21 = @as(u21, high - HIGH_SURROGATE_MIN);
    const l: u21 = @as(u21, low - LOW_SURROGATE_MIN);
    return (h << 10) + l + SURROGATE_BIAS;
}

pub const SurrogatePair = struct {
    high: u16,
    low: u16,
};

pub fn splitSurrogate(cp: u21) ?SurrogatePair {
    if (cp < SURROGATE_BIAS) return null;
    if (cp > MAX_CODEPOINT) return null;
    const v = cp - SURROGATE_BIAS;
    const high: u16 = @intCast((v >> 10) + HIGH_SURROGATE_MIN);
    const low: u16 = @intCast((v & 0x3FF) + LOW_SURROGATE_MIN);
    return .{ .high = high, .low = low };
}

pub fn unitLength(cp: u21) u2 {
    if (cp < SURROGATE_BIAS) return 1;
    return 2;
}

pub fn encode(cp: u21, buffer: []u16) ?u2 {
    if (cp > MAX_CODEPOINT) return null;
    if (cp >= utf8.SURROGATE_START and cp <= utf8.SURROGATE_END) return null;

    if (cp < SURROGATE_BIAS) {
        if (buffer.len < 1) return null;
        buffer[0] = @intCast(cp);
        return 1;
    }

    const pair = splitSurrogate(cp) orelse return null;
    if (buffer.len < 2) return null;
    buffer[0] = pair.high;
    buffer[1] = pair.low;
    return 2;
}

pub const DecodeResult = struct {
    codepoint: u21,
    length: u2,
};

pub fn decode(s: []const u16) ?DecodeResult {
    if (s.len == 0) return null;
    const u0 = s[0];

    if (!isSurrogate(u0)) {
        return .{ .codepoint = u0, .length = 1 };
    }

    if (isHighSurrogate(u0)) {
        if (s.len < 2) return null;
        const u1 = s[1];
        if (!isLowSurrogate(u1)) return null;
        const cp = combineSurrogates(u0, u1) orelse return null;
        return .{ .codepoint = cp, .length = 2 };
    }

    return null;
}

pub fn validate(s: []const u16) bool {
    var i: usize = 0;
    while (i < s.len) {
        const result = decode(s[i..]) orelse return false;
        i += result.length;
    }
    return true;
}

pub fn codepointCount(s: []const u16) ?usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        const result = decode(s[i..]) orelse return null;
        i += result.length;
        count += 1;
    }
    return count;
}

pub fn utf8ToUtf16(allocator: std.mem.Allocator, input: []const u8) ![]u16 {
    var list = std.ArrayList(u16).init(allocator);
    errdefer list.deinit();

    var it = utf8.Iterator.init(input);
    while (it.next()) |r| {
        var buf: [2]u16 = undefined;
        const n = encode(r.codepoint, &buf) orelse return error.InvalidCodepoint;
        try list.appendSlice(buf[0..n]);
    }
    return list.toOwnedSlice();
}

pub fn utf16ToUtf8(allocator: std.mem.Allocator, input: []const u16) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    var i: usize = 0;
    while (i < input.len) {
        const r = decode(input[i..]) orelse return error.InvalidUtf16;
        var buf: [4]u8 = undefined;
        const n = utf8.encode(r.codepoint, &buf) orelse return error.InvalidCodepoint;
        try list.appendSlice(buf[0..n]);
        i += r.length;
    }
    return list.toOwnedSlice();
}

pub const Iterator = struct {
    units: []const u16,
    pos: usize,

    pub fn init(s: []const u16) Iterator {
        return .{ .units = s, .pos = 0 };
    }

    pub fn next(self: *Iterator) ?DecodeResult {
        if (self.pos >= self.units.len) return null;
        const result = decode(self.units[self.pos..]) orelse {
            self.pos = self.units.len;
            return null;
        };
        self.pos += result.length;
        return result;
    }

    pub fn peek(self: Iterator) ?DecodeResult {
        if (self.pos >= self.units.len) return null;
        return decode(self.units[self.pos..]);
    }

    pub fn reset(self: *Iterator) void {
        self.pos = 0;
    }
};

test "isHighSurrogate" {
    try std.testing.expect(isHighSurrogate(0xD800));
    try std.testing.expect(isHighSurrogate(0xDBFF));
    try std.testing.expect(!isHighSurrogate(0xDC00));
    try std.testing.expect(!isHighSurrogate('A'));
}

test "isLowSurrogate" {
    try std.testing.expect(isLowSurrogate(0xDC00));
    try std.testing.expect(isLowSurrogate(0xDFFF));
    try std.testing.expect(!isLowSurrogate(0xD800));
    try std.testing.expect(!isLowSurrogate('A'));
}

test "isSurrogate" {
    try std.testing.expect(isSurrogate(0xD800));
    try std.testing.expect(isSurrogate(0xDC00));
    try std.testing.expect(!isSurrogate('A'));
}

test "combineSurrogates" {
    const cp = combineSurrogates(0xD83D, 0xDE00).?;
    try std.testing.expectEqual(@as(u21, 0x1F600), cp);
}

test "combineSurrogates rejects invalid" {
    try std.testing.expect(combineSurrogates(0xDC00, 0xD800) == null);
    try std.testing.expect(combineSurrogates('A', 'B') == null);
}

test "splitSurrogate" {
    const pair = splitSurrogate(0x1F600).?;
    try std.testing.expectEqual(@as(u16, 0xD83D), pair.high);
    try std.testing.expectEqual(@as(u16, 0xDE00), pair.low);
}

test "splitSurrogate rejects BMP" {
    try std.testing.expect(splitSurrogate(0x41) == null);
    try std.testing.expect(splitSurrogate(0xFFFF) == null);
}

test "unitLength" {
    try std.testing.expectEqual(@as(u2, 1), unitLength('A'));
    try std.testing.expectEqual(@as(u2, 1), unitLength(0xFFFF));
    try std.testing.expectEqual(@as(u2, 2), unitLength(0x10000));
    try std.testing.expectEqual(@as(u2, 2), unitLength(0x1F600));
}

test "encode BMP" {
    var buf: [2]u16 = undefined;
    const n = encode('A', &buf).?;
    try std.testing.expectEqual(@as(u2, 1), n);
    try std.testing.expectEqual(@as(u16, 'A'), buf[0]);
}

test "encode surrogate pair" {
    var buf: [2]u16 = undefined;
    const n = encode(0x1F600, &buf).?;
    try std.testing.expectEqual(@as(u2, 2), n);
    try std.testing.expect(isHighSurrogate(buf[0]));
    try std.testing.expect(isLowSurrogate(buf[1]));
}

test "encode rejects surrogate codepoint" {
    var buf: [2]u16 = undefined;
    try std.testing.expect(encode(0xD800, &buf) == null);
}

test "decode BMP" {
    const s = [_]u16{'A'};
    const r = decode(&s).?;
    try std.testing.expectEqual(@as(u21, 'A'), r.codepoint);
}

test "decode surrogate pair" {
    const s = [_]u16{ 0xD83D, 0xDE00 };
    const r = decode(&s).?;
    try std.testing.expectEqual(@as(u21, 0x1F600), r.codepoint);
    try std.testing.expectEqual(@as(u2, 2), r.length);
}

test "decode orphan high surrogate" {
    const s = [_]u16{0xD83D};
    try std.testing.expect(decode(&s) == null);
}

test "decode orphan low surrogate" {
    const s = [_]u16{0xDE00};
    try std.testing.expect(decode(&s) == null);
}

test "validate" {
    const valid = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(validate(&valid));

    const invalid = [_]u16{0xD83D};
    try std.testing.expect(!validate(&invalid));
}

test "codepointCount" {
    const s = [_]u16{ 'a', 'b', 0xD83D, 0xDE00, 'c' };
    try std.testing.expectEqual(@as(?usize, 4), codepointCount(&s));
}

test "utf8ToUtf16" {
    const allocator = std.testing.allocator;
    const utf8_str = "A";
    const utf16_str = try utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(utf16_str);
    try std.testing.expectEqual(@as(usize, 1), utf16_str.len);
    try std.testing.expectEqual(@as(u16, 'A'), utf16_str[0]);
}

test "utf16ToUtf8" {
    const allocator = std.testing.allocator;
    const utf16_str = [_]u16{'A'};
    const utf8_str = try utf16ToUtf8(allocator, &utf16_str);
    defer allocator.free(utf8_str);
    try std.testing.expectEqualStrings("A", utf8_str);
}

test "Iterator" {
    const s = [_]u16{ 'a', 'b', 'c' };
    var it = Iterator.init(&s);
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "Iterator peek" {
    const s = [_]u16{ 'a', 'b' };
    var it = Iterator.init(&s);
    try std.testing.expectEqual(@as(u21, 'a'), it.peek().?.codepoint);
    _ = it.next();
    try std.testing.expectEqual(@as(u21, 'b'), it.peek().?.codepoint);
}
