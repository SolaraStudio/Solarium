const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;

pub const String = struct {
    bytes: []const u8,
    hash: u64,

    pub fn init(bytes: []const u8) String {
        return .{
            .bytes = bytes,
            .hash = computeHash(bytes),
        };
    }

    pub fn len(self: String) usize {
        return self.bytes.len;
    }

    pub fn isEmpty(self: String) bool {
        return self.bytes.len == 0;
    }

    pub fn codepointCount(self: String) ?usize {
        return self.bytes.len;
    }

    pub fn slice(self: String) []const u8 {
        return self.bytes;
    }

    pub fn eql(self: String, other: String) bool {
        if (self.hash != other.hash) return false;
        if (self.bytes.len != other.bytes.len) return false;
        return std.mem.eql(u8, self.bytes, other.bytes);
    }

    pub fn eqlBytes(self: String, other: []const u8) bool {
        return std.mem.eql(u8, self.bytes, other);
    }

    pub fn charAt(self: String, index: usize) ?u8 {
        if (index >= self.bytes.len) return null;
        return self.bytes[index];
    }

    pub fn startsWith(self: String, prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.bytes, prefix);
    }

    pub fn endsWith(self: String, suffix: []const u8) bool {
        return std.mem.endsWith(u8, self.bytes, suffix);
    }

    pub fn indexOf(self: String, needle: []const u8) ?usize {
        return std.mem.indexOf(u8, self.bytes, needle);
    }
};

pub fn computeHash(bytes: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (bytes) |b| {
        h ^= b;
        h *%= 1099511628211;
    }
    return h;
}

pub fn asOpaque(s: *String) *value_mod.String {
    return @alignCast(@ptrCast(s));
}

pub fn asConcrete(s: *value_mod.String) *String {
    return @alignCast(@ptrCast(s));
}

pub fn create(allocator: std.mem.Allocator, text: []const u8) !*String {
    const s = try allocator.create(String);
    s.* = String.init(text);
    return s;
}

pub fn fromValue(v: Value) ?*String {
    return switch (v) {
        .string => |s| asConcrete(s),
        else => null,
    };
}

pub fn toValue(s: *String) Value {
    return Value.fromString(asOpaque(s));
}

pub fn isString(v: Value) bool {
    return v.isString();
}

pub fn len(v: Value) ?usize {
    const s = fromValue(v) orelse return null;
    return s.len();
}

pub fn isEmpty(v: Value) ?bool {
    const s = fromValue(v) orelse return null;
    return s.isEmpty();
}

pub fn sliceOf(v: Value) ?[]const u8 {
    const s = fromValue(v) orelse return null;
    return s.slice();
}

pub fn eql(a: Value, b: Value) ?bool {
    const x = fromValue(a) orelse return null;
    const y = fromValue(b) orelse return null;
    return x.eql(y.*);
}

pub fn eqlBytes(v: Value, bytes: []const u8) ?bool {
    const s = fromValue(v) orelse return null;
    return s.eqlBytes(bytes);
}

pub fn toNumber(v: Value) ?f64 {
    const s = fromValue(v) orelse return null;
    return parseNumber(s.bytes);
}

pub fn parseNumber(bytes: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, bytes, " \t\n\r");
    if (trimmed.len == 0) return 0.0;
    if (std.mem.eql(u8, trimmed, "Infinity")) return std.math.inf(f64);
    if (std.mem.eql(u8, trimmed, "-Infinity")) return -std.math.inf(f64);
    if (std.mem.eql(u8, trimmed, "+Infinity")) return std.math.inf(f64);
    return std.fmt.parseFloat(f64, trimmed) catch null;
}

pub fn concat(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len..], b);
    return out;
}

pub fn isAscii(bytes: []const u8) bool {
    for (bytes) |b| {
        if (b >= 0x80) return false;
    }
    return true;
}

pub fn isAsciiWhitespace(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\n' or b == '\r' or b == 0x0B or b == 0x0C;
}

pub fn trimAscii(bytes: []const u8) []const u8 {
    return std.mem.trim(u8, bytes, " \t\n\r\x0B\x0C");
}

test "String init" {
    const s = String.init("hello");
    try std.testing.expectEqual(@as(usize, 5), s.len());
    try std.testing.expect(!s.isEmpty());
}

test "String empty" {
    const s = String.init("");
    try std.testing.expect(s.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), s.len());
}

test "String eql same" {
    const a = String.init("hello");
    const b = String.init("hello");
    try std.testing.expect(a.eql(b));
}

test "String eql different" {
    const a = String.init("hello");
    const b = String.init("world");
    try std.testing.expect(!a.eql(b));
}

test "String eqlBytes" {
    const s = String.init("hello");
    try std.testing.expect(s.eqlBytes("hello"));
    try std.testing.expect(!s.eqlBytes("world"));
}

test "String charAt" {
    const s = String.init("abc");
    try std.testing.expectEqual(@as(?u8, 'a'), s.charAt(0));
    try std.testing.expectEqual(@as(?u8, 'c'), s.charAt(2));
    try std.testing.expectEqual(@as(?u8, null), s.charAt(3));
}

test "String startsWith endsWith" {
    const s = String.init("hello world");
    try std.testing.expect(s.startsWith("hello"));
    try std.testing.expect(s.endsWith("world"));
    try std.testing.expect(!s.startsWith("world"));
}

test "String indexOf" {
    const s = String.init("hello world");
    try std.testing.expectEqual(@as(?usize, 6), s.indexOf("world"));
    try std.testing.expectEqual(@as(?usize, null), s.indexOf("xyz"));
}

test "String codepointCount" {
    const s = String.init("hello");
    try std.testing.expectEqual(@as(?usize, 5), s.codepointCount());
}

test "create allocates" {
    const s = try create(std.testing.allocator, "test");
    defer std.testing.allocator.destroy(s);
    try std.testing.expect(s.eqlBytes("test"));
}

test "toValue and fromValue round trip" {
    const s = try create(std.testing.allocator, "hello");
    defer std.testing.allocator.destroy(s);
    const v = toValue(s);
    try std.testing.expectEqual(s, fromValue(v).?);
}

test "fromValue returns null for non-string" {
    try std.testing.expectEqual(@as(?*String, null), fromValue(Value.TRUE));
}

test "isString" {
    const s = try create(std.testing.allocator, "hello");
    defer std.testing.allocator.destroy(s);
    try std.testing.expect(isString(toValue(s)));
    try std.testing.expect(!isString(Value.TRUE));
}

test "len on value" {
    const s = try create(std.testing.allocator, "hello");
    defer std.testing.allocator.destroy(s);
    try std.testing.expectEqual(@as(?usize, 5), len(toValue(s)));
    try std.testing.expectEqual(@as(?usize, null), len(Value.TRUE));
}

test "isEmpty on value" {
    const s = try create(std.testing.allocator, "");
    defer std.testing.allocator.destroy(s);
    try std.testing.expect(isEmpty(toValue(s)).?);
}

test "sliceOf" {
    const s = try create(std.testing.allocator, "hello");
    defer std.testing.allocator.destroy(s);
    try std.testing.expectEqualStrings("hello", sliceOf(toValue(s)).?);
}

test "eql on values" {
    const a = try create(std.testing.allocator, "same");
    defer std.testing.allocator.destroy(a);
    const b = try create(std.testing.allocator, "same");
    defer std.testing.allocator.destroy(b);
    try std.testing.expect(eql(toValue(a), toValue(b)).?);
}

test "parseNumber integer" {
    try std.testing.expectEqual(@as(?f64, 42.0), parseNumber("42"));
}

test "parseNumber float" {
    try std.testing.expectEqual(@as(?f64, 3.14), parseNumber("3.14"));
}

test "parseNumber negative" {
    try std.testing.expectEqual(@as(?f64, -42.0), parseNumber("-42"));
}

test "parseNumber with whitespace" {
    try std.testing.expectEqual(@as(?f64, 42.0), parseNumber("  42  "));
}

test "parseNumber empty is zero" {
    try std.testing.expectEqual(@as(?f64, 0.0), parseNumber(""));
    try std.testing.expectEqual(@as(?f64, 0.0), parseNumber("   "));
}

test "parseNumber infinity" {
    try std.testing.expect(std.math.isInf(parseNumber("Infinity").?));
    try std.testing.expect(std.math.isInf(parseNumber("-Infinity").?));
}

test "parseNumber invalid" {
    try std.testing.expectEqual(@as(?f64, null), parseNumber("abc"));
}

test "concat" {
    const out = try concat(std.testing.allocator, "hello", " world");
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("hello world", out);
}

test "isAscii" {
    try std.testing.expect(isAscii("hello"));
    try std.testing.expect(!isAscii("héllo"));
}

test "isAsciiWhitespace" {
    try std.testing.expect(isAsciiWhitespace(' '));
    try std.testing.expect(isAsciiWhitespace('\t'));
    try std.testing.expect(!isAsciiWhitespace('a'));
}

test "trimAscii" {
    try std.testing.expectEqualStrings("hello", trimAscii("  hello  "));
    try std.testing.expectEqualStrings("", trimAscii("   "));
}

test "computeHash deterministic" {
    try std.testing.expectEqual(computeHash("hello"), computeHash("hello"));
    try std.testing.expect(computeHash("hello") != computeHash("world"));
}
