const std = @import("std");
const f64_mod = @import("f64.zig");

pub const ParseError = error{
    Empty,
    InvalidCharacter,
    InvalidFormat,
    Overflow,
    Underflow,
    NoDigits,
    InvalidSign,
    InvalidRadix,
    InvalidExponent,
    InvalidSeparator,
};

pub const Radix = enum(u8) {
    binary = 2,
    octal = 8,
    decimal = 10,
    hex = 16,

    pub fn value(self: Radix) u8 {
        return @intFromEnum(self);
    }
};

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn isHexDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or
        (c >= 'a' and c <= 'f') or
        (c >= 'A' and c <= 'F');
}

pub fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or
        c == 0x0B or c == 0x0C or c == 0xA0;
}

pub fn digitValue(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    return null;
}

pub fn trimWhitespace(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;
    while (start < end and isWhitespace(s[start])) : (start += 1) {}
    while (end > start and isWhitespace(s[end - 1])) : (end -= 1) {}
    return s[start..end];
}

pub fn parseF64(s: []const u8) ParseError!f64 {
    const trimmed = trimWhitespace(s);
    if (trimmed.len == 0) return ParseError.Empty;

    if (std.mem.eql(u8, trimmed, "Infinity") or
        std.mem.eql(u8, trimmed, "+Infinity"))
    {
        return f64_mod.infinity();
    }
    if (std.mem.eql(u8, trimmed, "-Infinity")) {
        return f64_mod.negInfinity();
    }

    var slice = trimmed;
    if (slice.len >= 2 and slice[0] == '0') {
        const c = slice[1];
        if (c == 'x' or c == 'X') {
            return parseHexF64(slice[2..]);
        }
        if (c == 'o' or c == 'O') {
            return parseRadixF64(slice[2..], 8);
        }
        if (c == 'b' or c == 'B') {
            return parseRadixF64(slice[2..], 2);
        }
    }

    return std.fmt.parseFloat(f64, slice) catch |err| switch (err) {
        error.InvalidCharacter => ParseError.InvalidCharacter,
        else => ParseError.InvalidFormat,
    };
}

pub fn parseHexF64(s: []const u8) ParseError!f64 {
    if (s.len == 0) return ParseError.NoDigits;
    var value: f64 = 0;
    for (s) |c| {
        const d = digitValue(c) orelse return ParseError.InvalidCharacter;
        if (d >= 16) return ParseError.InvalidCharacter;
        value = value * 16.0 + @as(f64, @floatFromInt(d));
    }
    return value;
}

pub fn parseRadixF64(s: []const u8, radix: u8) ParseError!f64 {
    if (s.len == 0) return ParseError.NoDigits;
    if (radix < 2 or radix > 36) return ParseError.InvalidRadix;
    var value: f64 = 0;
    for (s) |c| {
        const d = digitValue(c) orelse return ParseError.InvalidCharacter;
        if (d >= radix) return ParseError.InvalidCharacter;
        value = value * @as(f64, @floatFromInt(radix)) + @as(f64, @floatFromInt(d));
    }
    return value;
}

pub fn parseI64(s: []const u8, radix: u8) ParseError!i64 {
    const trimmed = trimWhitespace(s);
    if (trimmed.len == 0) return ParseError.Empty;
    return std.fmt.parseInt(i64, trimmed, radix) catch |err| switch (err) {
        error.InvalidCharacter => ParseError.InvalidCharacter,
        error.Overflow => ParseError.Overflow,
        error.Empty => ParseError.Empty,
        else => ParseError.InvalidFormat,
    };
}

pub fn parseU64(s: []const u8, radix: u8) ParseError!u64 {
    const trimmed = trimWhitespace(s);
    if (trimmed.len == 0) return ParseError.Empty;
    if (trimmed[0] == '-') return ParseError.InvalidSign;
    return std.fmt.parseInt(u64, trimmed, radix) catch |err| switch (err) {
        error.InvalidCharacter => ParseError.InvalidCharacter,
        error.Overflow => ParseError.Overflow,
        error.Empty => ParseError.Empty,
        else => ParseError.InvalidFormat,
    };
}

pub fn parseInt32(s: []const u8, radix: u8) ParseError!i32 {
    const v = try parseI64(s, radix);
    if (v > 2147483647) return ParseError.Overflow;
    if (v < -2147483648) return ParseError.Underflow;
    return @intCast(v);
}

pub fn parseUint32(s: []const u8, radix: u8) ParseError!u32 {
    const v = try parseU64(s, radix);
    if (v > 4294967295) return ParseError.Overflow;
    return @intCast(v);
}

pub fn parseDecimalI64(s: []const u8) ParseError!i64 {
    return parseI64(s, 10);
}

pub fn parseDecimalU64(s: []const u8) ParseError!u64 {
    return parseU64(s, 10);
}

pub fn parseHexU64(s: []const u8) ParseError!u64 {
    var slice = s;
    if (slice.len >= 2 and slice[0] == '0') {
        const c = slice[1];
        if (c == 'x' or c == 'X') slice = slice[2..];
    }
    return parseU64(slice, 16);
}

pub fn parseBinaryU64(s: []const u8) ParseError!u64 {
    var slice = s;
    if (slice.len >= 2 and slice[0] == '0') {
        const c = slice[1];
        if (c == 'b' or c == 'B') slice = slice[2..];
    }
    return parseU64(slice, 2);
}

pub fn parseOctalU64(s: []const u8) ParseError!u64 {
    var slice = s;
    if (slice.len >= 2 and slice[0] == '0') {
        const c = slice[1];
        if (c == 'o' or c == 'O') slice = slice[2..];
    }
    return parseU64(slice, 8);
}

pub fn hasDecimalPoint(s: []const u8) bool {
    for (s) |c| {
        if (c == '.') return true;
    }
    return false;
}

pub fn hasExponent(s: []const u8) bool {
    for (s) |c| {
        if (c == 'e' or c == 'E') return true;
    }
    return false;
}

pub fn isIntegerLiteral(s: []const u8) bool {
    const trimmed = trimWhitespace(s);
    if (trimmed.len == 0) return false;
    return !hasDecimalPoint(trimmed) and !hasExponent(trimmed);
}

pub fn countDigits(s: []const u8) usize {
    var count: usize = 0;
    for (s) |c| {
        if (isDigit(c)) count += 1;
    }
    return count;
}

pub const ParsedInteger = struct {
    value: i64,
    negative: bool,
    digit_count: usize,
};

pub fn parseIntDetailed(s: []const u8) ParseError!ParsedInteger {
    const trimmed = trimWhitespace(s);
    if (trimmed.len == 0) return ParseError.Empty;

    var slice = trimmed;
    var negative = false;
    if (slice[0] == '+' or slice[0] == '-') {
        negative = slice[0] == '-';
        slice = slice[1..];
    }
    if (slice.len == 0) return ParseError.NoDigits;

    const digits = countDigits(slice);
    if (digits == 0) return ParseError.NoDigits;

    const value = try parseI64(trimmed, 10);
    return .{
        .value = value,
        .negative = negative,
        .digit_count = digits,
    };
}

test "isDigit" {
    try std.testing.expect(isDigit('0'));
    try std.testing.expect(isDigit('9'));
    try std.testing.expect(!isDigit('a'));
    try std.testing.expect(!isDigit(' '));
}

test "isHexDigit" {
    try std.testing.expect(isHexDigit('0'));
    try std.testing.expect(isHexDigit('9'));
    try std.testing.expect(isHexDigit('a'));
    try std.testing.expect(isHexDigit('f'));
    try std.testing.expect(isHexDigit('A'));
    try std.testing.expect(isHexDigit('F'));
    try std.testing.expect(!isHexDigit('g'));
}

test "isWhitespace" {
    try std.testing.expect(isWhitespace(' '));
    try std.testing.expect(isWhitespace('\t'));
    try std.testing.expect(isWhitespace('\n'));
    try std.testing.expect(isWhitespace('\r'));
    try std.testing.expect(!isWhitespace('a'));
}

test "digitValue" {
    try std.testing.expectEqual(@as(?u8, 0), digitValue('0'));
    try std.testing.expectEqual(@as(?u8, 9), digitValue('9'));
    try std.testing.expectEqual(@as(?u8, 10), digitValue('a'));
    try std.testing.expectEqual(@as(?u8, 15), digitValue('f'));
    try std.testing.expectEqual(@as(?u8, 10), digitValue('A'));
    try std.testing.expectEqual(@as(?u8, 15), digitValue('F'));
    try std.testing.expect(digitValue('!') == null);
}

test "trimWhitespace" {
    try std.testing.expectEqualStrings("abc", trimWhitespace("  abc  "));
    try std.testing.expectEqualStrings("abc", trimWhitespace("abc"));
    try std.testing.expectEqualStrings("", trimWhitespace("   "));
    try std.testing.expectEqualStrings("a b", trimWhitespace("\ta b\n"));
}

test "parseF64 basic" {
    try std.testing.expectEqual(@as(f64, 42.0), try parseF64("42"));
    try std.testing.expectEqual(@as(f64, -42.0), try parseF64("-42"));
    try std.testing.expectEqual(@as(f64, 3.14), try parseF64("3.14"));
    try std.testing.expectEqual(@as(f64, 0.5), try parseF64("0.5"));
    try std.testing.expectEqual(@as(f64, 1e10), try parseF64("1e10"));
}

test "parseF64 with whitespace" {
    try std.testing.expectEqual(@as(f64, 42.0), try parseF64("  42  "));
}

test "parseF64 infinity" {
    try std.testing.expect(f64_mod.isInfinite(try parseF64("Infinity")));
    try std.testing.expect(f64_mod.isInfinite(try parseF64("+Infinity")));
    try std.testing.expect(f64_mod.isInfinite(try parseF64("-Infinity")));
}

test "parseF64 hex" {
    try std.testing.expectEqual(@as(f64, 255.0), try parseF64("0xff"));
    try std.testing.expectEqual(@as(f64, 16.0), try parseF64("0x10"));
}

test "parseF64 empty" {
    try std.testing.expectError(ParseError.Empty, parseF64(""));
    try std.testing.expectError(ParseError.Empty, parseF64("   "));
}

test "parseHexF64" {
    try std.testing.expectEqual(@as(f64, 255.0), try parseHexF64("ff"));
    try std.testing.expectEqual(@as(f64, 16.0), try parseHexF64("10"));
    try std.testing.expectError(ParseError.NoDigits, parseHexF64(""));
    try std.testing.expectError(ParseError.InvalidCharacter, parseHexF64("g"));
}

test "parseRadixF64" {
    try std.testing.expectEqual(@as(f64, 5.0), try parseRadixF64("101", 2));
    try std.testing.expectEqual(@as(f64, 8.0), try parseRadixF64("10", 8));
    try std.testing.expectError(ParseError.InvalidRadix, parseRadixF64("10", 1));
}

test "parseI64" {
    try std.testing.expectEqual(@as(i64, 42), try parseI64("42", 10));
    try std.testing.expectEqual(@as(i64, -42), try parseI64("-42", 10));
    try std.testing.expectEqual(@as(i64, 255), try parseI64("ff", 16));
    try std.testing.expectEqual(@as(i64, 5), try parseI64("101", 2));
    try std.testing.expectError(ParseError.Empty, parseI64("", 10));
}

test "parseU64" {
    try std.testing.expectEqual(@as(u64, 42), try parseU64("42", 10));
    try std.testing.expectEqual(@as(u64, 255), try parseU64("ff", 16));
    try std.testing.expectError(ParseError.InvalidSign, parseU64("-1", 10));
}

test "parseInt32" {
    try std.testing.expectEqual(@as(i32, 42), try parseInt32("42", 10));
    try std.testing.expectEqual(@as(i32, -42), try parseInt32("-42", 10));
    try std.testing.expectError(ParseError.Overflow, parseInt32("2147483648", 10));
    try std.testing.expectError(ParseError.Underflow, parseInt32("-2147483649", 10));
}

test "parseUint32" {
    try std.testing.expectEqual(@as(u32, 42), try parseUint32("42", 10));
    try std.testing.expectError(ParseError.Overflow, parseUint32("4294967296", 10));
}

test "parseHexU64" {
    try std.testing.expectEqual(@as(u64, 255), try parseHexU64("ff"));
    try std.testing.expectEqual(@as(u64, 255), try parseHexU64("0xff"));
    try std.testing.expectEqual(@as(u64, 255), try parseHexU64("0XFF"));
}

test "parseBinaryU64" {
    try std.testing.expectEqual(@as(u64, 5), try parseBinaryU64("101"));
    try std.testing.expectEqual(@as(u64, 5), try parseBinaryU64("0b101"));
}

test "parseOctalU64" {
    try std.testing.expectEqual(@as(u64, 8), try parseOctalU64("10"));
    try std.testing.expectEqual(@as(u64, 8), try parseOctalU64("0o10"));
}

test "hasDecimalPoint and hasExponent" {
    try std.testing.expect(hasDecimalPoint("3.14"));
    try std.testing.expect(!hasDecimalPoint("42"));
    try std.testing.expect(hasExponent("1e10"));
    try std.testing.expect(hasExponent("1E10"));
    try std.testing.expect(!hasExponent("42"));
}

test "isIntegerLiteral" {
    try std.testing.expect(isIntegerLiteral("42"));
    try std.testing.expect(isIntegerLiteral("-42"));
    try std.testing.expect(!isIntegerLiteral("3.14"));
    try std.testing.expect(!isIntegerLiteral("1e10"));
    try std.testing.expect(!isIntegerLiteral(""));
}

test "countDigits" {
    try std.testing.expectEqual(@as(usize, 0), countDigits("abc"));
    try std.testing.expectEqual(@as(usize, 3), countDigits("123"));
    try std.testing.expectEqual(@as(usize, 3), countDigits("1a2b3"));
    try std.testing.expectEqual(@as(usize, 5), countDigits("12345"));
}

test "parseIntDetailed" {
    const p = try parseIntDetailed("-42");
    try std.testing.expectEqual(@as(i64, -42), p.value);
    try std.testing.expect(p.negative);
    try std.testing.expectEqual(@as(usize, 2), p.digit_count);
}

test "Radix enum" {
    try std.testing.expectEqual(@as(u8, 2), Radix.binary.value());
    try std.testing.expectEqual(@as(u8, 8), Radix.octal.value());
    try std.testing.expectEqual(@as(u8, 10), Radix.decimal.value());
    try std.testing.expectEqual(@as(u8, 16), Radix.hex.value());
}
