const std = @import("std");

pub const MIN: u32 = 0;
pub const MAX: u32 = 4294967295;
pub const BITS: u6 = 32;
pub const BYTES: usize = 4;

pub fn add(a: u32, b: u32) ?u32 {
    return std.math.add(u32, a, b) catch null;
}

pub fn sub(a: u32, b: u32) ?u32 {
    return std.math.sub(u32, a, b) catch null;
}

pub fn mul(a: u32, b: u32) ?u32 {
    return std.math.mul(u32, a, b) catch null;
}

pub fn div(a: u32, b: u32) ?u32 {
    if (b == 0) return null;
    return a / b;
}

pub fn mod(a: u32, b: u32) ?u32 {
    if (b == 0) return null;
    return a % b;
}

pub fn wrappingAdd(a: u32, b: u32) u32 {
    return a +% b;
}

pub fn wrappingSub(a: u32, b: u32) u32 {
    return a -% b;
}

pub fn wrappingMul(a: u32, b: u32) u32 {
    return a *% b;
}

pub fn saturatingAdd(a: u32, b: u32) u32 {
    return std.math.add(u32, a, b) catch MAX;
}

pub fn saturatingSub(a: u32, b: u32) u32 {
    return std.math.sub(u32, a, b) catch MIN;
}

pub fn saturatingMul(a: u32, b: u32) u32 {
    return std.math.mul(u32, a, b) catch MAX;
}

pub fn clz(a: u32) u32 {
    return @clz(a);
}

pub fn ctz(a: u32) u32 {
    return @ctz(a);
}

pub fn popCount(a: u32) u32 {
    return @popCount(a);
}

pub fn rotateLeft(a: u32, n: u5) u32 {
    return std.math.rotl(u32, a, n);
}

pub fn rotateRight(a: u32, n: u5) u32 {
    return std.math.rotr(u32, a, n);
}

pub fn byteSwap(a: u32) u32 {
    return @byteSwap(a);
}

pub fn reverseBits(a: u32) u32 {
    return @bitReverse(a);
}

pub fn isZero(a: u32) bool {
    return a == 0;
}

pub fn isEven(a: u32) bool {
    return a % 2 == 0;
}

pub fn isOdd(a: u32) bool {
    return a % 2 != 0;
}

pub fn isPowerOfTwo(a: u32) bool {
    if (a == 0) return false;
    return (a & (a - 1)) == 0;
}

pub fn nextPowerOfTwo(a: u32) u32 {
    if (a <= 1) return 1;
    if (isPowerOfTwo(a)) return a;
    return @as(u32, 1) << @intCast(32 - clz(a - 1) + 1 - 1);
}

pub fn min(a: u32, b: u32) u32 {
    return @min(a, b);
}

pub fn max(a: u32, b: u32) u32 {
    return @max(a, b);
}

pub fn clamp(value: u32, low: u32, high: u32) u32 {
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

pub fn compare(a: u32, b: u32) std.math.Order {
    return std.math.order(a, b);
}

pub fn toI32(a: u32) i32 {
    return @bitCast(a);
}

pub fn fromI32(a: i32) u32 {
    return @bitCast(a);
}

pub fn toI64(a: u32) i64 {
    return @intCast(a);
}

pub fn fromI64(a: i64) ?u32 {
    if (a < 0 or a > MAX) return null;
    return @intCast(a);
}

pub fn parse(s: []const u8, base: u8) ?u32 {
    if (s.len == 0) return null;
    return std.fmt.parseInt(u32, s, base) catch null;
}

pub fn parseDecimal(s: []const u8) ?u32 {
    return parse(s, 10);
}

pub fn parseHex(s: []const u8) ?u32 {
    return parse(s, 16);
}

pub fn parseBinary(s: []const u8) ?u32 {
    return parse(s, 2);
}

pub fn parseOctal(s: []const u8) ?u32 {
    return parse(s, 8);
}

pub fn toString(value: u32, buffer: []u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{d}", .{value});
}

pub fn toHexString(value: u32, buffer: []u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{x}", .{value});
}

pub fn hash(a: u32) u64 {
    var h: u64 = 14695981039346656037;
    const bytes = std.mem.asBytes(&a);
    for (bytes) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

pub fn leadingOnes(a: u32) u32 {
    return clz(~a);
}

pub fn trailingOnes(a: u32) u32 {
    return ctz(~a);
}

pub fn maskLowBits(count: u5) u32 {
    if (count == 0) return 0;
    if (count >= 32) return MAX;
    return (@as(u32, 1) << count) - 1;
}

pub fn maskHighBits(count: u5) u32 {
    if (count == 0) return 0;
    const shift: u5 = @intCast(32 - @as(u6, count));
    return ~((@as(u32, 1) << shift) - 1);
}

test "constants" {
    try std.testing.expectEqual(@as(u32, 0), MIN);
    try std.testing.expectEqual(@as(u32, 4294967295), MAX);
    try std.testing.expectEqual(@as(u6, 32), BITS);
    try std.testing.expectEqual(@as(usize, 4), BYTES);
}

test "add overflow" {
    try std.testing.expectEqual(@as(?u32, 30), add(10, 20));
    try std.testing.expect(add(MAX, 1) == null);
}

test "sub underflow" {
    try std.testing.expectEqual(@as(?u32, 10), sub(30, 20));
    try std.testing.expect(sub(0, 1) == null);
}

test "mul overflow" {
    try std.testing.expectEqual(@as(?u32, 200), mul(10, 20));
    try std.testing.expect(mul(MAX, 2) == null);
}

test "div and mod" {
    try std.testing.expectEqual(@as(?u32, 5), div(10, 2));
    try std.testing.expect(div(10, 0) == null);
    try std.testing.expectEqual(@as(?u32, 1), mod(10, 3));
    try std.testing.expect(mod(10, 0) == null);
}

test "wrapping ops" {
    try std.testing.expectEqual(MIN, wrappingAdd(MAX, 1));
    try std.testing.expectEqual(MAX, wrappingSub(0, 1));
    try std.testing.expectEqual(@as(u32, 4), wrappingMul(2, 2));
}

test "saturating ops" {
    try std.testing.expectEqual(MAX, saturatingAdd(MAX, 1));
    try std.testing.expectEqual(MIN, saturatingSub(0, 1));
    try std.testing.expectEqual(MAX, saturatingMul(MAX, 2));
}

test "bit ops" {
    try std.testing.expectEqual(@as(u32, 32), clz(0));
    try std.testing.expectEqual(@as(u32, 0), clz(MAX));
    try std.testing.expectEqual(@as(u32, 31), clz(1));
    try std.testing.expectEqual(@as(u32, 0), ctz(1));
    try std.testing.expectEqual(@as(u32, 32), ctz(0));
    try std.testing.expectEqual(@as(u32, 32), popCount(MAX));
    try std.testing.expectEqual(@as(u32, 1), popCount(1));
}

test "rotate ops" {
    try std.testing.expectEqual(@as(u32, 2), rotateLeft(1, 1));
    try std.testing.expectEqual(@as(u32, 1), rotateRight(2, 1));
}

test "byteSwap" {
    try std.testing.expectEqual(@as(u32, 0x78563412), byteSwap(0x12345678));
}

test "reverseBits" {
    try std.testing.expectEqual(@as(u32, 0x80000000), reverseBits(1));
    try std.testing.expectEqual(@as(u32, 1), reverseBits(0x80000000));
}

test "predicates" {
    try std.testing.expect(isZero(0));
    try std.testing.expect(isEven(2));
    try std.testing.expect(isOdd(3));
    try std.testing.expect(isPowerOfTwo(4));
    try std.testing.expect(!isPowerOfTwo(3));
    try std.testing.expect(!isPowerOfTwo(0));
}

test "nextPowerOfTwo" {
    try std.testing.expectEqual(@as(u32, 1), nextPowerOfTwo(0));
    try std.testing.expectEqual(@as(u32, 1), nextPowerOfTwo(1));
    try std.testing.expectEqual(@as(u32, 2), nextPowerOfTwo(2));
    try std.testing.expectEqual(@as(u32, 4), nextPowerOfTwo(3));
    try std.testing.expectEqual(@as(u32, 4), nextPowerOfTwo(4));
    try std.testing.expectEqual(@as(u32, 8), nextPowerOfTwo(5));
}

test "min max clamp compare" {
    try std.testing.expectEqual(@as(u32, 1), min(1, 2));
    try std.testing.expectEqual(@as(u32, 2), max(1, 2));
    try std.testing.expectEqual(@as(u32, 5), clamp(5, 0, 10));
    try std.testing.expectEqual(@as(u32, 10), clamp(15, 0, 10));
    try std.testing.expectEqual(std.math.Order.lt, compare(1, 2));
}

test "toI32 and fromI32 round trip" {
    const values = [_]u32{ 0, 1, MAX, 42 };
    for (values) |v| {
        try std.testing.expectEqual(v, fromI32(toI32(v)));
    }
}

test "fromI64 rejects negatives" {
    try std.testing.expectEqual(@as(?u32, 42), fromI64(42));
    try std.testing.expect(fromI64(-1) == null);
    try std.testing.expect(fromI64(@as(i64, MAX) + 1) == null);
}

test "parse" {
    try std.testing.expectEqual(@as(?u32, 42), parseDecimal("42"));
    try std.testing.expectEqual(@as(?u32, 255), parseHex("ff"));
    try std.testing.expectEqual(@as(?u32, 5), parseBinary("101"));
    try std.testing.expectEqual(@as(?u32, 8), parseOctal("10"));
    try std.testing.expect(parseDecimal("-1") == null);
}

test "toString and toHexString" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("42", try toString(42, &buf));
    try std.testing.expectEqualStrings("ff", try toHexString(255, &buf));
}

test "hash deterministic" {
    try std.testing.expectEqual(hash(42), hash(42));
    try std.testing.expect(hash(42) != hash(43));
}

test "leadingOnes and trailingOnes" {
    try std.testing.expectEqual(@as(u32, 0), leadingOnes(0));
    try std.testing.expectEqual(@as(u32, 32), leadingOnes(MAX));
    try std.testing.expectEqual(@as(u32, 32), trailingOnes(MAX));
}

test "maskLowBits and maskHighBits" {
    try std.testing.expectEqual(@as(u32, 0), maskLowBits(0));
    try std.testing.expectEqual(@as(u32, 1), maskLowBits(1));
    try std.testing.expectEqual(@as(u32, 3), maskLowBits(2));
    try std.testing.expectEqual(@as(u32, 0xFF), maskLowBits(8));
    try std.testing.expectEqual(@as(u32, 0x80000000), maskHighBits(1));
    try std.testing.expectEqual(@as(u32, 0xFF000000), maskHighBits(8));
}
