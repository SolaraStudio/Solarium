const std = @import("std");
const bit = @import("bit.zig");

pub fn clamp(value: anytype, min_value: @TypeOf(value), max_value: @TypeOf(value)) @TypeOf(value) {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

pub fn clamp01(value: f64) f64 {
    return clamp(value, 0.0, 1.0);
}

pub fn min3(a: anytype, b: @TypeOf(a), c: @TypeOf(a)) @TypeOf(a) {
    return @min(@min(a, b), c);
}

pub fn max3(a: anytype, b: @TypeOf(a), c: @TypeOf(a)) @TypeOf(a) {
    return @max(@max(a, b), c);
}

pub fn min4(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) @TypeOf(a) {
    return @min(@min(a, b), @min(c, d));
}

pub fn max4(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) @TypeOf(a) {
    return @max(@max(a, b), @max(c, d));
}

pub fn sign(value: anytype) i2 {
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 0;
}

pub fn signum(value: f64) f64 {
    if (value > 0) return 1.0;
    if (value < 0) return -1.0;
    return 0.0;
}

pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * t;
}

pub fn lerpClamped(a: f64, b: f64, t: f64) f64 {
    return lerp(a, b, clamp01(t));
}

pub fn inverseLerp(a: f64, b: f64, value: f64) f64 {
    if (a == b) return 0.0;
    return (value - a) / (b - a);
}

pub fn remap(value: f64, in_min: f64, in_max: f64, out_min: f64, out_max: f64) f64 {
    return out_min + (out_max - out_min) * inverseLerp(in_min, in_max, value);
}

pub fn wrap(value: anytype, max_value: @TypeOf(value)) @TypeOf(value) {
    const T = @TypeOf(value);
    if (max_value <= 0) return value;
    if (value >= 0 and value < max_value) return value;
    const m = @mod(value, max_value);
    return if (m < 0) m + max_value else m;
}

pub fn wrapF64(value: f64, max_value: f64) f64 {
    if (max_value <= 0) return value;
    const m = @mod(value, max_value);
    return if (m < 0) m + max_value else m;
}

pub fn isEven(value: anytype) bool {
    return @mod(value, 2) == 0;
}

pub fn isOdd(value: anytype) bool {
    return @mod(value, 2) != 0;
}

pub fn gcd(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    var x = a;
    var y = b;
    const T = @TypeOf(a);
    if (T == f32 or T == f64) {
        while (y != 0) {
            const t = @mod(x, y);
            x = y;
            y = t;
        }
        return x;
    }
    if (x < 0) x = -x;
    if (y < 0) y = -y;
    while (y != 0) {
        const t = @mod(x, y);
        x = y;
        y = t;
    }
    return x;
}

pub fn lcm(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    if (a == 0 or b == 0) return 0;
    const g = gcd(a, b);
    return @divTrunc(a, g) * b;
}

pub fn abs(value: anytype) @TypeOf(value) {
    return if (value < 0) -value else value;
}

pub fn absF64(value: f64) f64 {
    return @abs(value);
}

pub fn avg(a: f64, b: f64) f64 {
    return (a + b) * 0.5;
}

pub fn avg3(a: f64, b: f64, c: f64) f64 {
    return (a + b + c) / 3.0;
}

pub fn percent(value: f64, total: f64) f64 {
    if (total == 0) return 0.0;
    return (value / total) * 100.0;
}

pub fn round(value: f64, decimals: u8) f64 {
    const factor = std.math.pow(f64, 10.0, @floatFromInt(decimals));
    return @round(value * factor) / factor;
}

pub fn floor(value: f64) f64 {
    return @floor(value);
}

pub fn ceil(value: f64) f64 {
    return @ceil(value);
}

pub fn trunc(value: f64) f64 {
    return @trunc(value);
}

pub fn roundHalfAwayFromZero(value: f64) f64 {
    if (value >= 0) return @floor(value + 0.5);
    return @ceil(value - 0.5);
}

pub fn approxEqual(a: f64, b: f64, epsilon: f64) bool {
    return @abs(a - b) <= epsilon;
}

pub fn almostEqual(a: f64, b: f64) bool {
    return approxEqual(a, b, 1e-9);
}

pub fn deg2rad(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}

pub fn rad2deg(radians: f64) f64 {
    return radians * 180.0 / std.math.pi;
}

pub fn checkedAdd(comptime T: type, a: T, b: T) ?T {
    return std.math.add(T, a, b) catch null;
}

pub fn checkedSub(comptime T: type, a: T, b: T) ?T {
    return std.math.sub(T, a, b) catch null;
}

pub fn checkedMul(comptime T: type, a: T, b: T) ?T {
    return std.math.mul(T, a, b) catch null;
}

pub fn checkedDiv(comptime T: type, a: T, b: T) ?T {
    return std.math.divTrunc(T, a, b) catch null;
}

pub fn saturatingAdd(comptime T: type, a: T, b: T) T {
    return std.math.add(T, a, b) catch if (a > 0) std.math.maxInt(T) else std.math.minInt(T);
}

pub fn saturatingSub(comptime T: type, a: T, b: T) T {
    return std.math.sub(T, a, b) catch if (a > 0) std.math.maxInt(T) else std.math.minInt(T);
}

pub fn saturatingMul(comptime T: type, a: T, b: T) T {
    return std.math.mul(T, a, b) catch if ((a > 0) == (b > 0)) std.math.maxInt(T) else std.math.minInt(T);
}

pub fn wrappingAdd(comptime T: type, a: T, b: T) T {
    return a +% b;
}

pub fn wrappingSub(comptime T: type, a: T, b: T) T {
    return a -% b;
}

pub fn wrappingMul(comptime T: type, a: T, b: T) T {
    return a *% b;
}

pub fn isFinite(value: f64) bool {
    return std.math.isFinite(value);
}

pub fn isNan(value: f64) bool {
    return std.math.isNan(value);
}

pub fn isInfinite(value: f64) bool {
    return std.math.isInf(value);
}

pub fn pow(base: f64, exponent: f64) f64 {
    return std.math.pow(f64, base, exponent);
}

pub fn sqrt(value: f64) f64 {
    return @sqrt(value);
}

pub fn cbrt(value: f64) f64 {
    return std.math.cbrt(value);
}

pub fn log(value: f64) f64 {
    return @log(value);
}

pub fn log2(value: f64) f64 {
    return @log2(value);
}

pub fn log10(value: f64) f64 {
    return @log10(value);
}

pub fn exp(value: f64) f64 {
    return @exp(value);
}

pub fn sin(value: f64) f64 {
    return @sin(value);
}

pub fn cos(value: f64) f64 {
    return @cos(value);
}

pub fn tan(value: f64) f64 {
    return @tan(value);
}

pub fn atan2(y: f64, x: f64) f64 {
    return std.math.atan2(y, x);
}

pub fn hypot(a: f64, b: f64) f64 {
    return std.math.hypot(a, b);
}

pub fn distance(x1: f64, y1: f64, x2: f64, y2: f64) f64 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    return hypot(dx, dy);
}

pub fn isPrime(n: u32) bool {
    if (n < 2) return false;
    if (n < 4) return true;
    if (n % 2 == 0) return false;
    var i: u32 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

pub fn factorial(n: u32) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        result *%= i;
    }
    return result;
}

pub fn fibonacci(n: u32) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const c = a +% b;
        a = b;
        b = c;
    }
    return b;
}

test "clamp" {
    try std.testing.expectEqual(@as(i32, 5), clamp(@as(i32, 5), 0, 10));
    try std.testing.expectEqual(@as(i32, 0), clamp(@as(i32, -5), 0, 10));
    try std.testing.expectEqual(@as(i32, 10), clamp(@as(i32, 15), 0, 10));
}

test "clamp01" {
    try std.testing.expectEqual(@as(f64, 0.0), clamp01(-1.0));
    try std.testing.expectEqual(@as(f64, 0.5), clamp01(0.5));
    try std.testing.expectEqual(@as(f64, 1.0), clamp01(2.0));
}

test "min3 and max3" {
    try std.testing.expectEqual(@as(i32, 1), min3(1, 2, 3));
    try std.testing.expectEqual(@as(i32, 1), min3(3, 1, 2));
    try std.testing.expectEqual(@as(i32, 3), max3(1, 2, 3));
    try std.testing.expectEqual(@as(i32, 3), max3(3, 2, 1));
}

test "min4 and max4" {
    try std.testing.expectEqual(@as(i32, 1), min4(4, 3, 2, 1));
    try std.testing.expectEqual(@as(i32, 4), max4(1, 2, 3, 4));
}

test "sign" {
    try std.testing.expectEqual(@as(i2, 1), sign(@as(i32, 5)));
    try std.testing.expectEqual(@as(i2, -1), sign(@as(i32, -5)));
    try std.testing.expectEqual(@as(i2, 0), sign(@as(i32, 0)));
}

test "signum" {
    try std.testing.expectEqual(@as(f64, 1.0), signum(5.0));
    try std.testing.expectEqual(@as(f64, -1.0), signum(-5.0));
    try std.testing.expectEqual(@as(f64, 0.0), signum(0.0));
}

test "lerp" {
    try std.testing.expectEqual(@as(f64, 0.0), lerp(0, 10, 0));
    try std.testing.expectEqual(@as(f64, 5.0), lerp(0, 10, 0.5));
    try std.testing.expectEqual(@as(f64, 10.0), lerp(0, 10, 1));
}

test "lerpClamped" {
    try std.testing.expectEqual(@as(f64, 0.0), lerpClamped(0, 10, -1));
    try std.testing.expectEqual(@as(f64, 10.0), lerpClamped(0, 10, 2));
}

test "inverseLerp" {
    try std.testing.expectEqual(@as(f64, 0.0), inverseLerp(0, 10, 0));
    try std.testing.expectEqual(@as(f64, 0.5), inverseLerp(0, 10, 5));
    try std.testing.expectEqual(@as(f64, 1.0), inverseLerp(0, 10, 10));
    try std.testing.expectEqual(@as(f64, 0.0), inverseLerp(5, 5, 5));
}

test "remap" {
    try std.testing.expectEqual(@as(f64, 0.0), remap(0, 0, 10, 0, 100));
    try std.testing.expectEqual(@as(f64, 50.0), remap(5, 0, 10, 0, 100));
    try std.testing.expectEqual(@as(f64, 100.0), remap(10, 0, 10, 0, 100));
}

test "wrap" {
    try std.testing.expectEqual(@as(i32, 0), wrap(@as(i32, 10), 10));
    try std.testing.expectEqual(@as(i32, 1), wrap(@as(i32, 11), 10));
    try std.testing.expectEqual(@as(i32, 5), wrap(@as(i32, 5), 10));
    try std.testing.expectEqual(@as(i32, 9), wrap(@as(i32, -1), 10));
}

test "isEven and isOdd" {
    try std.testing.expect(isEven(@as(i32, 0)));
    try std.testing.expect(isEven(@as(i32, 2)));
    try std.testing.expect(!isEven(@as(i32, 3)));
    try std.testing.expect(isOdd(@as(i32, 1)));
    try std.testing.expect(isOdd(@as(i32, 3)));
    try std.testing.expect(!isOdd(@as(i32, 4)));
}

test "gcd" {
    try std.testing.expectEqual(@as(u32, 6), gcd(@as(u32, 12), @as(u32, 18)));
    try std.testing.expectEqual(@as(u32, 1), gcd(@as(u32, 7), @as(u32, 11)));
    try std.testing.expectEqual(@as(u32, 5), gcd(@as(u32, 0), @as(u32, 5)));
    try std.testing.expectEqual(@as(u32, 4), gcd(@as(u32, 8), @as(u32, 4)));
}

test "lcm" {
    try std.testing.expectEqual(@as(u32, 36), lcm(@as(u32, 12), @as(u32, 18)));
    try std.testing.expectEqual(@as(u32, 0), lcm(@as(u32, 0), @as(u32, 5)));
    try std.testing.expectEqual(@as(u32, 15), lcm(@as(u32, 3), @as(u32, 5)));
}

test "abs" {
    try std.testing.expectEqual(@as(i32, 5), abs(@as(i32, 5)));
    try std.testing.expectEqual(@as(i32, 5), abs(@as(i32, -5)));
    try std.testing.expectEqual(@as(f64, 3.14), absF64(-3.14));
}

test "avg and avg3" {
    try std.testing.expectEqual(@as(f64, 5.0), avg(0, 10));
    try std.testing.expectEqual(@as(f64, 3.0), avg3(1, 2, 6));
}

test "percent" {
    try std.testing.expectEqual(@as(f64, 50.0), percent(5, 10));
    try std.testing.expectEqual(@as(f64, 0.0), percent(5, 0));
}

test "round" {
    try std.testing.expectEqual(@as(f64, 3.14), round(3.14159, 2));
    try std.testing.expectEqual(@as(f64, 3.1), round(3.14159, 1));
    try std.testing.expectEqual(@as(f64, 3.0), round(3.14159, 0));
}

test "approxEqual" {
    try std.testing.expect(approxEqual(1.0, 1.0, 0.001));
    try std.testing.expect(approxEqual(1.0, 1.0005, 0.001));
    try std.testing.expect(!approxEqual(1.0, 1.1, 0.001));
}

test "almostEqual" {
    try std.testing.expect(almostEqual(1.0, 1.0));
    try std.testing.expect(almostEqual(1.0, 1.0 + 1e-12));
    try std.testing.expect(!almostEqual(1.0, 1.1));
}

test "deg2rad and rad2deg" {
    try std.testing.expect(almostEqual(deg2rad(180), std.math.pi));
    try std.testing.expect(almostEqual(rad2deg(std.math.pi), 180.0));
}

test "checkedAdd" {
    try std.testing.expectEqual(@as(?i32, 30), checkedAdd(i32, 10, 20));
    try std.testing.expect(checkedAdd(i32, std.math.maxInt(i32), 1) == null);
}

test "checkedSub" {
    try std.testing.expectEqual(@as(?i32, 10), checkedSub(i32, 30, 20));
    try std.testing.expect(checkedSub(i32, std.math.minInt(i32), 1) == null);
}

test "checkedMul" {
    try std.testing.expectEqual(@as(?i32, 200), checkedMul(i32, 10, 20));
    try std.testing.expect(checkedMul(i32, std.math.maxInt(i32), 2) == null);
}

test "checkedDiv" {
    try std.testing.expectEqual(@as(?i32, 5), checkedDiv(i32, 10, 2));
    try std.testing.expect(checkedDiv(i32, 10, 0) == null);
}

test "saturatingAdd" {
    try std.testing.expectEqual(@as(i32, 30), saturatingAdd(i32, 10, 20));
    try std.testing.expectEqual(std.math.maxInt(i32), saturatingAdd(i32, std.math.maxInt(i32), 1));
    try std.testing.expectEqual(std.math.minInt(i32), saturatingAdd(i32, std.math.minInt(i32), -1));
}

test "saturatingSub" {
    try std.testing.expectEqual(@as(i32, 10), saturatingSub(i32, 30, 20));
    try std.testing.expectEqual(std.math.minInt(i32), saturatingSub(i32, std.math.minInt(i32), 1));
}

test "saturatingMul" {
    try std.testing.expectEqual(@as(i32, 200), saturatingMul(i32, 10, 20));
    try std.testing.expectEqual(std.math.maxInt(i32), saturatingMul(i32, std.math.maxInt(i32), 2));
}

test "wrapping arithmetic" {
    try std.testing.expectEqual(@as(u8, 0), wrappingAdd(u8, 255, 1));
    try std.testing.expectEqual(@as(u8, 255), wrappingSub(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 254), wrappingMul(u8, 127, 2));
}

test "isFinite isNan isInfinite" {
    try std.testing.expect(isFinite(1.0));
    try std.testing.expect(!isFinite(std.math.inf(f64)));
    try std.testing.expect(isNan(std.math.nan(f64)));
    try std.testing.expect(isInfinite(std.math.inf(f64)));
}

test "sqrt and pow" {
    try std.testing.expectEqual(@as(f64, 3.0), sqrt(9.0));
    try std.testing.expectEqual(@as(f64, 8.0), pow(2.0, 3.0));
}

test "hypot and distance" {
    try std.testing.expectEqual(@as(f64, 5.0), hypot(3, 4));
    try std.testing.expectEqual(@as(f64, 5.0), distance(0, 0, 3, 4));
    try std.testing.expectEqual(@as(f64, 5.0), distance(1, 1, 4, 5));
}

test "isPrime" {
    try std.testing.expect(!isPrime(0));
    try std.testing.expect(!isPrime(1));
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(3));
    try std.testing.expect(!isPrime(4));
    try std.testing.expect(isPrime(5));
    try std.testing.expect(isPrime(7));
    try std.testing.expect(!isPrime(9));
    try std.testing.expect(isPrime(97));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
    try std.testing.expectEqual(@as(u64, 1), factorial(1));
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
    try std.testing.expectEqual(@as(u64, 3628800), factorial(10));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(2));
    try std.testing.expectEqual(@as(u64, 2), fibonacci(3));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "log and exp" {
    try std.testing.expect(almostEqual(log(std.math.e), 1.0));
    try std.testing.expect(almostEqual(exp(0), 1.0));
    try std.testing.expect(almostEqual(log2(8), 3.0));
    try std.testing.expect(almostEqual(log10(1000), 3.0));
}

test "trig" {
    try std.testing.expect(almostEqual(sin(0), 0.0));
    try std.testing.expect(almostEqual(cos(0), 1.0));
    try std.testing.expect(almostEqual(tan(0), 0.0));
}
