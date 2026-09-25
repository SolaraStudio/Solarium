const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;

pub const MAX_SAFE_INTEGER: f64 = 9007199254740991.0;
pub const MIN_SAFE_INTEGER: f64 = -9007199254740991.0;
pub const POSITIVE_INFINITY: f64 = std.math.inf(f64);
pub const NEGATIVE_INFINITY: f64 = -std.math.inf(f64);
pub const NAN: f64 = std.math.nan(f64);
pub const EPSILON: f64 = 2.220446049250313e-16;
pub const MAX_VALUE: f64 = 1.7976931348623157e+308;
pub const MIN_VALUE: f64 = 2.2250738585072014e-308;

inline fn f64IsNan(x: f64) bool {
    return std.math.isNan(x);
}

inline fn f64IsFinite(x: f64) bool {
    return std.math.isFinite(x);
}

inline fn f64IsInteger(x: f64) bool {
    if (!std.math.isFinite(x)) return false;
    return @floor(x) == x;
}

inline fn f64SignBit(x: f64) bool {
    const bits: u64 = @bitCast(x);
    return (bits >> 63) != 0;
}

inline fn f64Min(a: f64, b: f64) f64 {
    if (f64IsNan(a) or f64IsNan(b)) return NAN;
    if (a == 0.0 and b == 0.0) {
        if (f64SignBit(a) or f64SignBit(b)) return -0.0;
        return 0.0;
    }
    return if (a < b) a else b;
}

inline fn f64Max(a: f64, b: f64) f64 {
    if (f64IsNan(a) or f64IsNan(b)) return NAN;
    if (a == 0.0 and b == 0.0) {
        if (!f64SignBit(a) or !f64SignBit(b)) return 0.0;
        return -0.0;
    }
    return if (a > b) a else b;
}

pub fn fromF64(n: f64) Value {
    return Value.fromNumber(n);
}

pub fn fromI64(n: i64) Value {
    return Value.fromNumber(@floatFromInt(n));
}

pub fn fromU64(n: u64) Value {
    return Value.fromNumber(@floatFromInt(n));
}

pub fn isNumber(v: Value) bool {
    return v.isNumber();
}

pub fn valueOf(v: Value) ?f64 {
    return v.asNumber();
}

pub fn isInteger(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return f64IsInteger(n);
}

pub fn isFinite(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return f64IsFinite(n);
}

pub fn isNaN(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return f64IsNan(n);
}

pub fn isSafeInteger(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    if (!f64IsInteger(n)) return false;
    return @abs(n) <= MAX_SAFE_INTEGER;
}

pub fn isPositive(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return n > 0;
}

pub fn isNegative(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return n < 0;
}

pub fn isZero(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return n == 0.0;
}

pub fn isPositiveZero(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return n == 0.0 and !f64SignBit(n);
}

pub fn isNegativeZero(v: Value) ?bool {
    const n = valueOf(v) orelse return null;
    return n == 0.0 and f64SignBit(n);
}

pub fn add(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(x + y);
}

pub fn sub(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(x - y);
}

pub fn mul(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(x * y);
}

pub fn div(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(x / y);
}

pub fn mod(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    if (y == 0.0) return Value.NAN;
    return Value.fromNumber(@rem(x, y));
}

pub fn pow(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(std.math.pow(f64, x, y));
}

pub fn negate(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(-n);
}

pub fn abs(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@abs(n));
}

pub fn floor(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@floor(n));
}

pub fn ceil(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@ceil(n));
}

pub fn round(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@round(n));
}

pub fn trunc(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@trunc(n));
}

pub fn sqrt(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    return Value.fromNumber(@sqrt(n));
}

pub fn sign(v: Value) ?Value {
    const n = valueOf(v) orelse return null;
    if (f64IsNan(n)) return Value.NAN;
    if (n > 0) return Value.fromNumber(1.0);
    if (n < 0) return Value.fromNumber(-1.0);
    return Value.fromNumber(n);
}

pub fn min(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(f64Min(x, y));
}

pub fn max(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromNumber(f64Max(x, y));
}

pub fn clamp(v: Value, low: f64, high: f64) ?Value {
    const n = valueOf(v) orelse return null;
    if (f64IsNan(n)) return Value.NAN;
    if (n < low) return Value.fromNumber(low);
    if (n > high) return Value.fromNumber(high);
    return Value.fromNumber(n);
}

pub fn sameValue(a: Value, b: Value) bool {
    return a.isSameValue(b);
}

test "fromF64" {
    try std.testing.expectEqual(@as(?f64, 3.14), valueOf(fromF64(3.14)));
}

test "fromI64" {
    try std.testing.expectEqual(@as(?f64, 42.0), valueOf(fromI64(42)));
}

test "fromU64" {
    try std.testing.expectEqual(@as(?f64, 42.0), valueOf(fromU64(42)));
}

test "isNumber" {
    try std.testing.expect(isNumber(fromF64(1.0)));
    try std.testing.expect(!isNumber(Value.TRUE));
}

test "isInteger" {
    try std.testing.expect(isInteger(fromF64(1.0)).?);
    try std.testing.expect(!isInteger(fromF64(1.5)).?);
    try std.testing.expectEqual(@as(?bool, null), isInteger(Value.TRUE));
}

test "isFinite" {
    try std.testing.expect(isFinite(fromF64(1.0)).?);
    try std.testing.expect(!isFinite(fromF64(POSITIVE_INFINITY)).?);
}

test "isNaN" {
    try std.testing.expect(isNaN(fromF64(NAN)).?);
    try std.testing.expect(!isNaN(fromF64(1.0)).?);
}

test "isSafeInteger" {
    try std.testing.expect(isSafeInteger(fromF64(1.0)).?);
    try std.testing.expect(!isSafeInteger(fromF64(MAX_SAFE_INTEGER + 2.0)).?);
}

test "isPositive isNegative" {
    try std.testing.expect(isPositive(fromF64(1.0)).?);
    try std.testing.expect(isNegative(fromF64(-1.0)).?);
    try std.testing.expect(!isPositive(fromF64(0.0)).?);
}

test "isZero" {
    try std.testing.expect(isZero(fromF64(0.0)).?);
    try std.testing.expect(isZero(fromF64(-0.0)).?);
    try std.testing.expect(!isZero(fromF64(1.0)).?);
}

test "isPositiveZero isNegativeZero" {
    try std.testing.expect(isPositiveZero(fromF64(0.0)).?);
    try std.testing.expect(isNegativeZero(fromF64(-0.0)).?);
}

test "add sub mul div" {
    const a = fromF64(10.0);
    const b = fromF64(5.0);
    try std.testing.expectEqual(@as(?f64, 15.0), valueOf(add(a, b).?));
    try std.testing.expectEqual(@as(?f64, 5.0), valueOf(sub(a, b).?));
    try std.testing.expectEqual(@as(?f64, 50.0), valueOf(mul(a, b).?));
    try std.testing.expectEqual(@as(?f64, 2.0), valueOf(div(a, b).?));
}

test "mod" {
    try std.testing.expectEqual(@as(?f64, 1.0), valueOf(mod(fromF64(10.0), fromF64(3.0)).?));
}

test "mod by zero returns NaN" {
    try std.testing.expect(isNaN(mod(fromF64(10.0), fromF64(0.0)).?).?);
}

test "pow" {
    try std.testing.expectEqual(@as(?f64, 8.0), valueOf(pow(fromF64(2.0), fromF64(3.0)).?));
}

test "negate" {
    try std.testing.expectEqual(@as(?f64, -5.0), valueOf(negate(fromF64(5.0)).?));
}

test "abs" {
    try std.testing.expectEqual(@as(?f64, 5.0), valueOf(abs(fromF64(-5.0)).?));
}

test "floor ceil round trunc" {
    const v = fromF64(3.7);
    try std.testing.expectEqual(@as(?f64, 3.0), valueOf(floor(v).?));
    try std.testing.expectEqual(@as(?f64, 4.0), valueOf(ceil(v).?));
    try std.testing.expectEqual(@as(?f64, 4.0), valueOf(round(v).?));
    try std.testing.expectEqual(@as(?f64, 3.0), valueOf(trunc(v).?));
}

test "sqrt" {
    try std.testing.expectEqual(@as(?f64, 3.0), valueOf(sqrt(fromF64(9.0)).?));
}

test "sign" {
    try std.testing.expectEqual(@as(?f64, 1.0), valueOf(sign(fromF64(5.0)).?));
    try std.testing.expectEqual(@as(?f64, -1.0), valueOf(sign(fromF64(-5.0)).?));
    try std.testing.expectEqual(@as(?f64, 0.0), valueOf(sign(fromF64(0.0)).?));
}

test "min max" {
    try std.testing.expectEqual(@as(?f64, 5.0), valueOf(min(fromF64(10.0), fromF64(5.0)).?));
    try std.testing.expectEqual(@as(?f64, 10.0), valueOf(max(fromF64(10.0), fromF64(5.0)).?));
}

test "clamp" {
    try std.testing.expectEqual(@as(?f64, 5.0), valueOf(clamp(fromF64(5.0), 0.0, 10.0).?));
    try std.testing.expectEqual(@as(?f64, 0.0), valueOf(clamp(fromF64(-5.0), 0.0, 10.0).?));
    try std.testing.expectEqual(@as(?f64, 10.0), valueOf(clamp(fromF64(15.0), 0.0, 10.0).?));
}

test "constants" {
    try std.testing.expectEqual(@as(f64, 9007199254740991.0), MAX_SAFE_INTEGER);
    try std.testing.expectEqual(@as(f64, -9007199254740991.0), MIN_SAFE_INTEGER);
    try std.testing.expect(f64IsFinite(POSITIVE_INFINITY) == false);
    try std.testing.expect(f64IsFinite(NEGATIVE_INFINITY) == false);
    try std.testing.expect(f64IsNan(NAN));
}
