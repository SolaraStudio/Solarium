const std = @import("std");

pub const MIN: i32 = -2147483648;
pub const MAX: i32 = 2147483647;
pub const BITS: u6 = 32;
pub const BYTES: usize = 4;
pub const BASE10_DIGITS: u6 = 10;
pub const BASE16_DIGITS: u6 = 8;

pub fn add(a: i32, b: i32) ?i32 {
    return std.math.add(i32, a, b) catch null;
}

pub fn sub(a: i32, b: i32) ?i32 {
    return std.math.sub(i32, a, b) catch null;
}

pub fn mul(a: i32, b: i32) ?i32 {
    return std.math.mul(i32, a, b) catch null;
}

pub fn div(a: i32, b: i32) ?i32 {
    if (b == 0) return null;
    if (a == MIN and b == -1) return null;
    return @divTrunc(a, b);
}

pub fn mod(a: i32, b: i32) ?i32 {
    if (b == 0) return null;
    if (a == MIN and b == -1) return 0;
    return @rem(a, b);
}

pub fn negate(a: i32) ?i32 {
    if (a == MIN) return null;
    return -a;
}

pub fn abs(a: i32) u32 {
    if (a == MIN) return 2147483648;
    return @intCast(if (a < 0) -a else a);
}

pub fn wrappingAdd(a: i32, b: i32) i32 {
    return a +% b;
}

pub fn wrappingSub(a: i32, b: i32) i32 {
    return a -% b;
}

pub fn wrappingMul(a: i32, b: i32) i32 {
    return a *% b;
}

pub fn wrappingNegate(a: i32) i32 {
    return -%a;
}

pub fn saturatingAdd(a: i32, b: i32) i32 {
    return std.math.add(i32, a, b) catch if (a > 0) MAX else MIN;
}

pub fn saturatingSub(a: i32, b: i32) i32 {
    return std.math.sub(i32, a, b) catch if (a > 0) MAX else MIN;
}

pub fn saturatingMul(a: i32, b: i32) i32 {
    return std.math.mul(i32, a, b) catch if ((a > 0) == (b > 0)) MAX else MIN;
}

pub fn saturatingNegate(a: i32) i32 {
    if (a == MIN) return MAX;
    return -a;
}

pub fn clz(a: i32) u32 {
    const bits: u32 = @bitCast(a);
    return @clz(bits);
}

pub fn ctz(a: i32) u32 {
    const bits: u32 = @bitCast(a);
    return @ctz(bits);
}

pub fn popCount(a: i32) u32 {
    const bits: u32 = @bitCast(a);
    return @popCount(bits);
}

pub fn rotateLeft(a: i32, n: u5) i32 {
    const bits: u32 = @bitCast(a);
    return @bitCast(std.math.rotl(u32, bits, n));
}

pub fn rotateRight(a: i32, n: u5) i32 {
    const bits: u32 = @bitCast(a);
    return @bitCast(std.math.rotr(u32, bits, n));
}

pub fn byteSwap(a: i32) i32 {
    return @byteSwap(a);
}

pub fn isPositive(a: i32) bool {
    return a > 0;
}

pub fn isNegative(a: i32) bool {
    return a < 0;
}

pub fn isZero(a: i32) bool {
    return a == 0;
}

pub fn isEven(a: i32) bool {
    return @rem(a, 2) == 0;
}

pub fn isOdd(a: i32) bool {
    return @rem(a, 2) != 0;
}

pub fn isPowerOfTwo(a: i32) bool {
    if (a <= 0) return false;
    const bits: u32 = @bitCast(a);
    return (bits & (bits - 1)) == 0;
}

pub fn sign(a: i32) i8 {
    if (a > 0) return 1;
    if (a < 0) return -1;
    return 0;
}

pub fn min(a: i32, b: i32) i32 {
    return @min(a, b);
}

pub fn max(a: i32, b: i32) i32 {
    return @max(a, b);
}

pub fn clamp(value: i32, low: i32, high: i32) i32 {
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

pub fn compare(a: i32, b: i32) std.math.Order {
    return std.math.order(a, b);
}

pub fn toU32(a: i32) u32 {
    return @bitCast(a);
}

pub fn fromU32(a: u32) i32 {
    return @bitCast(a);
}

pub fn toI64(a: i32) i64 {
    return @intCast(a);
}

pub fn fromI64(a: i64) ?i32 {
    if (a > MAX or a < MIN) return null;
    return @intCast(a);
}

pub fn parse(s: []const u8, base: u8) ?i32 {
    if (s.len == 0) return null;
    return std.fmt.parseInt(i32, s, base) catch null;
}

pub fn parseDecimal(s: []const u8) ?i32 {
    return parse(s, 10);
}

pub fn parseHex(s: []const u8) ?i32 {
    return parse(s, 16);
}

pub fn parseBinary(s: []const u8) ?i32 {
    return parse(s, 2);
}

pub fn parseOctal(s: []const u8) ?i32 {
    return parse(s, 8);
}

pub fn toString(value: i32, buffer: []u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{d}", .{value});
}

pub fn toHexString(value: i32, buffer: []u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{x}", .{value});
}

pub fn hash(a: i32) u64 {
    var h: u64 = 14695981039346656037;
    const bytes = std.mem.asBytes(&a);
    for (bytes) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

test "constants" {
    try std.testing.expectEqual(@as(i32, -2147483648), MIN);
    try std.testing.expectEqual(@as(i32, 2147483647), MAX);
    try std.testing.expectEqual(@as(u6, 32), BITS);
    try std.testing.expectEqual(@as(usize, 4), BYTES);
}

test "add overflow" {
    try std.testing.expectEqual(@as(?i32, 30), add(10, 20));
    try std.testing.expect(add(MAX, 1) == null);
    try std.testing.expect(add(MIN, -1) == null);
}

test "sub overflow" {
    try std.testing.expectEqual(@as(?i32, 10), sub(30, 20));
    try std.testing.expect(sub(MIN, 1) == null);
    try std.testing.expect(sub(MAX, -1) == null);
}

test "mul overflow" {
    try std.testing.expectEqual(@as(?i32, 200), mul(10, 20));
    try std.testing.expect(mul(MAX, 2) == null);
    try std.testing.expect(mul(MIN, 2) == null);
}

test "div" {
    try std.testing.expectEqual(@as(?i32, 5), div(10, 2));
    try std.testing.expect(div(10, 0) == null);
    try std.testing.expect(div(MIN, -1) == null);
}

test "mod" {
    try std.testing.expectEqual(@as(?i32, 1), mod(10, 3));
    try std.testing.expect(mod(10, 0) == null);
}

test "negate" {
    try std.testing.expectEqual(@as(?i32, -5), negate(5));
    try std.testing.expect(negate(MIN) == null);
}

test "abs" {
    try std.testing.expectEqual(@as(u32, 5), abs(5));
    try std.testing.expectEqual(@as(u32, 5), abs(-5));
    try std.testing.expectEqual(@as(u32, 0), abs(0));
    try std.testing.expectEqual(@as(u32, 2147483648), abs(MIN));
}

test "wrapping ops" {
    try std.testing.expectEqual(MIN, wrappingAdd(MAX, 1));
    try std.testing.expectEqual(MAX, wrappingSub(MIN, 1));
    try std.testing.expectEqual(@as(i32, 2), wrappingMul(1, 2));
    try std.testing.expectEqual(MIN, wrappingNegate(MIN));
}

test "saturating ops" {
    try std.testing.expectEqual(MAX, saturatingAdd(MAX, 1));
    try std.testing.expectEqual(MIN, saturatingAdd(MIN, -1));
    try std.testing.expectEqual(MIN, saturatingSub(MIN, 1));
    try std.testing.expectEqual(MAX, saturatingMul(MAX, 2));
    try std.testing.expectEqual(MAX, saturatingNegate(MIN));
}

test "bit operations" {
    try std.testing.expectEqual(@as(u32, 32), clz(0));
    try std.testing.expectEqual(@as(u32, 0), clz(-1));
    try std.testing.expectEqual(@as(u32, 31), clz(1));
    try std.testing.expectEqual(@as(u32, 0), ctz(1));
    try std.testing.expectEqual(@as(u32, 32), ctz(0));
    try std.testing.expectEqual(@as(u32, 32), popCount(-1));
    try std.testing.expectEqual(@as(u32, 1), popCount(1));
}

test "rotate ops" {
    try std.testing.expectEqual(@as(i32, 2), rotateLeft(1, 1));
    try std.testing.expectEqual(@as(i32, 1), rotateRight(2, 1));
}

test "byteSwap" {
    try std.testing.expectEqual(@as(i32, 0x78563412), byteSwap(0x12345678));
}

test "predicates" {
    try std.testing.expect(isPositive(1));
    try std.testing.expect(isNegative(-1));
    try std.testing.expect(isZero(0));
    try std.testing.expect(isEven(2));
    try std.testing.expect(isOdd(3));
    try std.testing.expect(isPowerOfTwo(4));
    try std.testing.expect(!isPowerOfTwo(3));
    try std.testing.expect(!isPowerOfTwo(0));
    try std.testing.expect(!isPowerOfTwo(-1));
}

test "sign" {
    try std.testing.expectEqual(@as(i8, 1), sign(5));
    try std.testing.expectEqual(@as(i8, -1), sign(-5));
    try std.testing.expectEqual(@as(i8, 0), sign(0));
}

test "min max clamp" {
    try std.testing.expectEqual(@as(i32, 1), min(1, 2));
    try std.testing.expectEqual(@as(i32, 2), max(1, 2));
    try std.testing.expectEqual(@as(i32, 5), clamp(5, 0, 10));
    try std.testing.expectEqual(@as(i32, 0), clamp(-5, 0, 10));
    try std.testing.expectEqual(@as(i32, 10), clamp(15, 0, 10));
}

test "compare" {
    try std.testing.expectEqual(std.math.Order.lt, compare(1, 2));
    try std.testing.expectEqual(std.math.Order.gt, compare(2, 1));
    try std.testing.expectEqual(std.math.Order.eq, compare(1, 1));
}

test "toU32 and fromU32 round trip" {
    const values = [_]i32{ 0, 1, -1, MAX, MIN, 42, -42 };
    for (values) |v| {
        try std.testing.expectEqual(v, fromU32(toU32(v)));
    }
}

test "toI64 and fromI64" {
    try std.testing.expectEqual(@as(i64, 42), toI64(42));
    try std.testing.expectEqual(@as(?i32, 42), fromI64(42));
    try std.testing.expect(fromI64(2147483648) == null);
    try std.testing.expect(fromI64(-2147483649) == null);
}

test "parse" {
    try std.testing.expectEqual(@as(?i32, 42), parseDecimal("42"));
    try std.testing.expectEqual(@as(?i32, -42), parseDecimal("-42"));
    try std.testing.expectEqual(@as(?i32, 255), parseHex("ff"));
    try std.testing.expectEqual(@as(?i32, 5), parseBinary("101"));
    try std.testing.expectEqual(@as(?i32, 8), parseOctal("10"));
    try std.testing.expect(parseDecimal("nope") == null);
}

test "toString" {
    var buf: [32]u8 = undefined;
    const s = try toString(42, &buf);
    try std.testing.expectEqualStrings("42", s);
}

test "toHexString" {
    var buf: [32]u8 = undefined;
    const s = try toHexString(255, &buf);
    try std.testing.expectEqualStrings("ff", s);
}

test "hash is deterministic" {
    try std.testing.expectEqual(hash(42), hash(42));
    try std.testing.expect(hash(42) != hash(43));
}
