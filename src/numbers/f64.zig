const std = @import("std");
const builtin = @import("builtin");

pub const EPSILON: f64 = 2.220446049250313e-16;
pub const MAX: f64 = 1.7976931348623157e+308;
pub const MIN: f64 = -1.7976931348623157e+308;
pub const MIN_POSITIVE: f64 = 2.2250738585072014e-308;
pub const MAX_EXP: i32 = 1023;
pub const MIN_EXP: i32 = -1022;
pub const MANTISSA_BITS: u6 = 52;
pub const EXPONENT_BITS: u6 = 11;
pub const SIGN_BITS: u6 = 1;
pub const TOTAL_BITS: u6 = 64;
pub const SAFE_INTEGER_MAX: f64 = 9007199254740991.0;

pub const Sign = enum { positive, negative };

pub const Classification = enum {
    nan,
    negative_infinity,
    negative_normal,
    negative_subnormal,
    negative_zero,
    positive_zero,
    positive_subnormal,
    positive_normal,
    positive_infinity,
};

pub fn infinity() f64 {
    return std.math.inf(f64);
}

pub fn negInfinity() f64 {
    return -std.math.inf(f64);
}

pub fn nan() f64 {
    return std.math.nan(f64);
}

pub fn isNan(x: f64) bool {
    return std.math.isNan(x);
}

pub fn isFinite(x: f64) bool {
    return std.math.isFinite(x);
}

pub fn isInfinite(x: f64) bool {
    return std.math.isInf(x);
}

pub fn isNormal(x: f64) bool {
    return std.math.isNormal(x);
}

pub fn isPositive(x: f64) bool {
    return x > 0;
}

pub fn isNegative(x: f64) bool {
    return x < 0;
}

pub fn isZero(x: f64) bool {
    return x == 0.0;
}

pub fn isPositiveZero(x: f64) bool {
    return x == 0.0 and !signBit(x);
}

pub fn isNegativeZero(x: f64) bool {
    return x == 0.0 and signBit(x);
}

pub fn isInteger(x: f64) bool {
    if (!isFinite(x)) return false;
    return @floor(x) == x;
}

pub fn isSafeInteger(x: f64) bool {
    if (!isInteger(x)) return false;
    return @abs(x) <= SAFE_INTEGER_MAX;
}

pub fn signBit(x: f64) bool {
    const bits: u64 = @bitCast(x);
    return (bits >> 63) != 0;
}

pub fn signOf(x: f64) Sign {
    return if (signBit(x)) .negative else .positive;
}

pub fn classify(x: f64) Classification {
    if (isNan(x)) return .nan;
    if (isInfinite(x)) return if (signBit(x)) .negative_infinity else .positive_infinity;
    if (x == 0.0) return if (signBit(x)) .negative_zero else .positive_zero;
    const normal = isNormal(x);
    if (signBit(x)) {
        return if (normal) .negative_normal else .negative_subnormal;
    }
    return if (normal) .positive_normal else .positive_subnormal;
}

pub fn copySign(magnitude: f64, sign: f64) f64 {
    return std.math.copysign(magnitude, sign);
}

pub fn flipSign(x: f64) f64 {
    return -x;
}

pub fn clearSign(x: f64) f64 {
    const bits: u64 = @bitCast(x);
    return @bitCast(bits & 0x7FFFFFFFFFFFFFFF);
}

pub fn setSign(x: f64, negative: bool) f64 {
    const bits: u64 = @bitCast(x);
    if (negative) {
        return @bitCast(bits | 0x8000000000000000);
    }
    return @bitCast(bits & 0x7FFFFFFFFFFFFFFF);
}

pub fn nextUp(x: f64) f64 {
    if (isNan(x)) return x;
    if (x == infinity()) return x;
    if (isNegativeZero(x)) return std.math.floatMin(f64);
    if (x == 0.0) return std.math.floatMin(f64);
    const bits: u64 = @bitCast(x);
    if (x > 0) {
        return @bitCast(bits + 1);
    }
    return @bitCast(bits - 1);
}

pub fn nextDown(x: f64) f64 {
    if (isNan(x)) return x;
    if (x == negInfinity()) return x;
    if (isPositiveZero(x)) return -std.math.floatMin(f64);
    if (x == 0.0) return -std.math.floatMin(f64);
    const bits: u64 = @bitCast(x);
    if (x > 0) {
        return @bitCast(bits - 1);
    }
    return @bitCast(bits + 1);
}

pub fn abs(x: f64) f64 {
    return @abs(x);
}

pub fn min(a: f64, b: f64) f64 {
    if (isNan(a) or isNan(b)) return nan();
    if (a == 0.0 and b == 0.0) {
        if (isNegativeZero(a) or isNegativeZero(b)) return -0.0;
        return 0.0;
    }
    return if (a < b) a else b;
}

pub fn max(a: f64, b: f64) f64 {
    if (isNan(a) or isNan(b)) return nan();
    if (a == 0.0 and b == 0.0) {
        if (isPositiveZero(a) or isPositiveZero(b)) return 0.0;
        return -0.0;
    }
    return if (a > b) a else b;
}

pub fn clamp(x: f64, low: f64, high: f64) f64 {
    if (isNan(x)) return nan();
    if (x < low) return low;
    if (x > high) return high;
    return x;
}

pub fn clamp01(x: f64) f64 {
    return clamp(x, 0.0, 1.0);
}

pub fn approximatelyEqual(a: f64, b: f64, epsilon: f64) bool {
    if (isNan(a) or isNan(b)) return false;
    if (a == b) return true;
    if (isInfinite(a) or isInfinite(b)) return false;
    const diff = @abs(a - b);
    if (diff <= epsilon) return true;
    const largest = @max(@abs(a), @abs(b));
    return diff <= largest * epsilon;
}

pub fn almostEqual(a: f64, b: f64) bool {
    return approximatelyEqual(a, b, 1e-9);
}

pub fn fuzzyEqual(a: f64, b: f64) bool {
    return approximatelyEqual(a, b, 1e-6);
}

pub const RoundingMode = enum {
    toward_zero,
    toward_positive_infinity,
    toward_negative_infinity,
    toward_nearest,
    toward_nearest_even,
};

pub fn toI64(x: f64, mode: RoundingMode) ?i64 {
    if (isNan(x)) return null;
    if (isInfinite(x)) return null;
    if (x > 9223372036854775807.0) return null;
    if (x < -9223372036854775808.0) return null;
    const rounded = switch (mode) {
        .toward_zero => @trunc(x),
        .toward_positive_infinity => @ceil(x),
        .toward_negative_infinity => @floor(x),
        .toward_nearest => @round(x),
        .toward_nearest_even => @round(x),
    };
    return @intFromFloat(rounded);
}

pub fn toU64(x: f64, mode: RoundingMode) ?u64 {
    if (isNan(x)) return null;
    if (isInfinite(x)) return null;
    if (x < 0.0) return null;
    if (x > 18446744073709551615.0) return null;
    const rounded = switch (mode) {
        .toward_zero => @trunc(x),
        .toward_positive_infinity => @ceil(x),
        .toward_negative_infinity => @floor(x),
        .toward_nearest => @round(x),
        .toward_nearest_even => @round(x),
    };
    return @intFromFloat(rounded);
}

pub fn toI32(x: f64, mode: RoundingMode) ?i32 {
    const v = toI64(x, mode) orelse return null;
    if (v > 2147483647 or v < -2147483648) return null;
    return @intCast(v);
}

pub fn toU32(x: f64, mode: RoundingMode) ?u32 {
    const v = toU64(x, mode) orelse return null;
    if (v > 4294967295) return null;
    return @intCast(v);
}

pub fn truncate(x: f64) f64 {
    return @trunc(x);
}

pub fn floor(x: f64) f64 {
    return @floor(x);
}

pub fn ceil(x: f64) f64 {
    return @ceil(x);
}

pub fn round(x: f64) f64 {
    return @round(x);
}

pub fn roundToDecimals(x: f64, decimals: u8) f64 {
    const factor = std.math.pow(f64, 10.0, @floatFromInt(decimals));
    return @round(x * factor) / factor;
}

pub fn decompose(x: f64) struct { mantissa: f64, exponent: i32 } {
    if (!isFinite(x) or x == 0.0) {
        return .{ .mantissa = x, .exponent = 0 };
    }
    const abs_x = @abs(x);
    const exp: i32 = @intFromFloat(@floor(@log2(abs_x))) + 1;
    const mantissa = x / std.math.pow(f64, 2.0, @floatFromInt(exp));
    return .{ .mantissa = mantissa, .exponent = exp };
}

pub fn compose(mantissa: f64, exponent: i32) f64 {
    return mantissa * std.math.pow(f64, 2.0, @floatFromInt(exponent));
}

pub fn frexp(x: f64, exp_out: *i32) f64 {
    if (!isFinite(x) or x == 0.0) {
        exp_out.* = 0;
        return x;
    }
    const abs_x = @abs(x);
    var e: i32 = @intFromFloat(@floor(@log2(abs_x))) + 1;
    var m = x / std.math.pow(f64, 2.0, @floatFromInt(e));
    if (@abs(m) >= 1.0) {
        e += 1;
        m = x / std.math.pow(f64, 2.0, @floatFromInt(e));
    }
    exp_out.* = e;
    return m;
}

pub fn ldexp(mantissa: f64, exponent: i32) f64 {
    return mantissa * std.math.pow(f64, 2.0, @floatFromInt(exponent));
}

pub fn hashCode(x: f64) u64 {
    if (isNan(x)) return 0x7FF8000000000000;
    if (isPositiveZero(x)) return 0;
    if (isNegativeZero(x)) return 0x8000000000000000;
    return @bitCast(x);
}

pub fn totalOrder(a: f64, b: f64) std.math.Order {
    if (isNan(a) and isNan(b)) return .eq;
    if (isNan(a)) return .lt;
    if (isNan(b)) return .gt;
    if (isNegativeZero(a) and isPositiveZero(b)) return .lt;
    if (isPositiveZero(a) and isNegativeZero(b)) return .gt;
    if (a < b) return .lt;
    if (a > b) return .gt;
    return .eq;
}

pub fn toBits(x: f64) u64 {
    return @bitCast(x);
}

pub fn fromBits(bits: u64) f64 {
    return @bitCast(bits);
}

test "epsilon constant" {
    try std.testing.expectEqual(@as(f64, 2.220446049250313e-16), EPSILON);
    try std.testing.expect(1.0 + EPSILON != 1.0);
    try std.testing.expect(1.0 + EPSILON / 2.0 == 1.0);
}

test "max min constants" {
    try std.testing.expect(MAX > 0);
    try std.testing.expect(MIN < 0);
    try std.testing.expectEqual(MAX, -MIN);
    try std.testing.expect(MIN_POSITIVE > 0);
}

test "infinity and nan" {
    try std.testing.expect(isInfinite(infinity()));
    try std.testing.expect(isInfinite(negInfinity()));
    try std.testing.expect(isNan(nan()));
    try std.testing.expect(!isFinite(infinity()));
    try std.testing.expect(!isFinite(nan()));
}

test "isNan predicates" {
    try std.testing.expect(isNan(nan()));
    try std.testing.expect(!isNan(0.0));
    try std.testing.expect(!isNan(infinity()));
}

test "isFinite predicates" {
    try std.testing.expect(isFinite(0.0));
    try std.testing.expect(isFinite(1.0));
    try std.testing.expect(isFinite(-1e308));
    try std.testing.expect(!isFinite(infinity()));
    try std.testing.expect(!isFinite(nan()));
}

test "isInfinite predicates" {
    try std.testing.expect(isInfinite(infinity()));
    try std.testing.expect(isInfinite(negInfinity()));
    try std.testing.expect(!isInfinite(1.0));
    try std.testing.expect(!isInfinite(nan()));
}

test "isNormal" {
    try std.testing.expect(isNormal(1.0));
    try std.testing.expect(isNormal(-1.0));
    try std.testing.expect(!isNormal(0.0));
    try std.testing.expect(!isNormal(infinity()));
    try std.testing.expect(!isNormal(nan()));
}

test "isPositive and isNegative" {
    try std.testing.expect(isPositive(1.0));
    try std.testing.expect(isNegative(-1.0));
    try std.testing.expect(!isPositive(0.0));
    try std.testing.expect(!isNegative(0.0));
}

test "isZero" {
    try std.testing.expect(isZero(0.0));
    try std.testing.expect(isZero(-0.0));
    try std.testing.expect(!isZero(1.0));
}

test "isPositiveZero and isNegativeZero" {
    try std.testing.expect(isPositiveZero(0.0));
    try std.testing.expect(!isPositiveZero(-0.0));
    try std.testing.expect(isNegativeZero(-0.0));
    try std.testing.expect(!isNegativeZero(0.0));
}

test "isInteger" {
    try std.testing.expect(isInteger(0.0));
    try std.testing.expect(isInteger(1.0));
    try std.testing.expect(isInteger(-1.0));
    try std.testing.expect(isInteger(1e10));
    try std.testing.expect(!isInteger(1.5));
    try std.testing.expect(!isInteger(infinity()));
    try std.testing.expect(!isInteger(nan()));
}

test "isSafeInteger" {
    try std.testing.expect(isSafeInteger(0.0));
    try std.testing.expect(isSafeInteger(1.0));
    try std.testing.expect(isSafeInteger(SAFE_INTEGER_MAX));
    try std.testing.expect(!isSafeInteger(SAFE_INTEGER_MAX + 2));
    try std.testing.expect(!isSafeInteger(1.5));
}

test "signBit" {
    try std.testing.expect(!signBit(1.0));
    try std.testing.expect(signBit(-1.0));
    try std.testing.expect(!signBit(0.0));
    try std.testing.expect(signBit(-0.0));
}

test "signOf" {
    try std.testing.expectEqual(Sign.positive, signOf(1.0));
    try std.testing.expectEqual(Sign.negative, signOf(-1.0));
    try std.testing.expectEqual(Sign.positive, signOf(0.0));
    try std.testing.expectEqual(Sign.negative, signOf(-0.0));
}

test "classify" {
    try std.testing.expectEqual(Classification.nan, classify(nan()));
    try std.testing.expectEqual(Classification.positive_infinity, classify(infinity()));
    try std.testing.expectEqual(Classification.negative_infinity, classify(negInfinity()));
    try std.testing.expectEqual(Classification.positive_zero, classify(0.0));
    try std.testing.expectEqual(Classification.negative_zero, classify(-0.0));
    try std.testing.expectEqual(Classification.positive_normal, classify(1.0));
    try std.testing.expectEqual(Classification.negative_normal, classify(-1.0));
}

test "copySign" {
    try std.testing.expectEqual(@as(f64, 5.0), copySign(5.0, 1.0));
    try std.testing.expectEqual(@as(f64, -5.0), copySign(5.0, -1.0));
    try std.testing.expectEqual(@as(f64, -5.0), copySign(-5.0, -1.0));
    try std.testing.expectEqual(@as(f64, 5.0), copySign(-5.0, 1.0));
}

test "flipSign" {
    try std.testing.expectEqual(@as(f64, -5.0), flipSign(5.0));
    try std.testing.expectEqual(@as(f64, 5.0), flipSign(-5.0));
}

test "clearSign" {
    try std.testing.expectEqual(@as(f64, 5.0), clearSign(-5.0));
    try std.testing.expectEqual(@as(f64, 5.0), clearSign(5.0));
}

test "setSign" {
    try std.testing.expectEqual(@as(f64, -5.0), setSign(5.0, true));
    try std.testing.expectEqual(@as(f64, 5.0), setSign(5.0, false));
    try std.testing.expectEqual(@as(f64, -5.0), setSign(-5.0, true));
    try std.testing.expectEqual(@as(f64, 5.0), setSign(-5.0, false));
}

test "nextUp" {
    const x = 1.0;
    const y = nextUp(x);
    try std.testing.expect(y > x);
    try std.testing.expectEqual(@as(f64, infinity()), nextUp(infinity()));
    try std.testing.expect(isNan(nextUp(nan())));
}

test "nextDown" {
    const x = 1.0;
    const y = nextDown(x);
    try std.testing.expect(y < x);
    try std.testing.expectEqual(@as(f64, negInfinity()), nextDown(negInfinity()));
    try std.testing.expect(isNan(nextDown(nan())));
}

test "abs" {
    try std.testing.expectEqual(@as(f64, 5.0), abs(5.0));
    try std.testing.expectEqual(@as(f64, 5.0), abs(-5.0));
    try std.testing.expectEqual(@as(f64, 0.0), abs(0.0));
}

test "min and max" {
    try std.testing.expectEqual(@as(f64, 1.0), min(1.0, 2.0));
    try std.testing.expectEqual(@as(f64, 2.0), max(1.0, 2.0));
    try std.testing.expect(isNan(min(nan(), 1.0)));
    try std.testing.expect(isNan(max(nan(), 1.0)));
}

test "min and max zero handling" {
    try std.testing.expect(isNegativeZero(min(0.0, -0.0)));
    try std.testing.expect(isPositiveZero(max(0.0, -0.0)));
}

test "clamp" {
    try std.testing.expectEqual(@as(f64, 5.0), clamp(5.0, 0.0, 10.0));
    try std.testing.expectEqual(@as(f64, 0.0), clamp(-5.0, 0.0, 10.0));
    try std.testing.expectEqual(@as(f64, 10.0), clamp(15.0, 0.0, 10.0));
}

test "clamp01" {
    try std.testing.expectEqual(@as(f64, 0.5), clamp01(0.5));
    try std.testing.expectEqual(@as(f64, 0.0), clamp01(-1.0));
    try std.testing.expectEqual(@as(f64, 1.0), clamp01(2.0));
}

test "approximatelyEqual" {
    try std.testing.expect(approximatelyEqual(1.0, 1.0, 1e-9));
    try std.testing.expect(approximatelyEqual(1.0, 1.0 + 1e-12, 1e-9));
    try std.testing.expect(!approximatelyEqual(1.0, 1.1, 1e-9));
    try std.testing.expect(!approximatelyEqual(nan(), 1.0, 1e-9));
}

test "toI64 toward zero" {
    try std.testing.expectEqual(@as(i64, 3), toI64(3.7, .toward_zero).?);
    try std.testing.expectEqual(@as(i64, -3), toI64(-3.7, .toward_zero).?);
    try std.testing.expectEqual(@as(i64, 0), toI64(0.9, .toward_zero).?);
}

test "toI64 toward nearest" {
    try std.testing.expectEqual(@as(i64, 4), toI64(3.7, .toward_nearest).?);
    try std.testing.expectEqual(@as(i64, -4), toI64(-3.7, .toward_nearest).?);
}

test "toI64 out of range" {
    try std.testing.expect(toI64(1e30, .toward_zero) == null);
    try std.testing.expect(toI64(nan(), .toward_zero) == null);
    try std.testing.expect(toI64(infinity(), .toward_zero) == null);
}

test "toU64" {
    try std.testing.expectEqual(@as(u64, 5), toU64(5.5, .toward_zero).?);
    try std.testing.expect(toU64(-1.0, .toward_zero) == null);
    try std.testing.expect(toU64(nan(), .toward_zero) == null);
}

test "toI32" {
    try std.testing.expectEqual(@as(i32, 5), toI32(5.5, .toward_zero).?);
    try std.testing.expect(toI32(1e20, .toward_zero) == null);
}

test "toU32" {
    try std.testing.expectEqual(@as(u32, 5), toU32(5.5, .toward_zero).?);
    try std.testing.expect(toU32(-1.0, .toward_zero) == null);
}

test "truncate floor ceil round" {
    try std.testing.expectEqual(@as(f64, 3.0), truncate(3.7));
    try std.testing.expectEqual(@as(f64, 3.0), floor(3.7));
    try std.testing.expectEqual(@as(f64, 4.0), ceil(3.7));
    try std.testing.expectEqual(@as(f64, 4.0), round(3.7));
}

test "roundToDecimals" {
    try std.testing.expectEqual(@as(f64, 3.14), roundToDecimals(3.14159, 2));
    try std.testing.expectEqual(@as(f64, 3.1), roundToDecimals(3.14159, 1));
    try std.testing.expectEqual(@as(f64, 3.0), roundToDecimals(3.14159, 0));
}

test "decompose and compose" {
    const d = decompose(8.0);
    try std.testing.expect(almostEqual(compose(d.mantissa, d.exponent), 8.0));
}

test "frexp and ldexp" {
    var exp: i32 = 0;
    const m = frexp(8.0, &exp);
    try std.testing.expect(almostEqual(ldexp(m, exp), 8.0));
}

test "hashCode" {
    try std.testing.expectEqual(@as(u64, 0), hashCode(0.0));
    try std.testing.expectEqual(@as(u64, 0x8000000000000000), hashCode(-0.0));
    try std.testing.expectEqual(hashCode(1.0), hashCode(1.0));
    try std.testing.expect(hashCode(1.0) != hashCode(2.0));
}

test "totalOrder" {
    try std.testing.expectEqual(std.math.Order.eq, totalOrder(1.0, 1.0));
    try std.testing.expectEqual(std.math.Order.lt, totalOrder(1.0, 2.0));
    try std.testing.expectEqual(std.math.Order.gt, totalOrder(2.0, 1.0));
    try std.testing.expectEqual(std.math.Order.lt, totalOrder(nan(), 1.0));
    try std.testing.expectEqual(std.math.Order.gt, totalOrder(1.0, nan()));
}

test "toBits and fromBits round trip" {
    const values = [_]f64{ 0.0, 1.0, -1.0, 0.5, infinity(), negInfinity() };
    for (values) |v| {
        try std.testing.expectEqual(v, fromBits(toBits(v)));
    }
    const nan_val = nan();
    try std.testing.expect(isNan(fromBits(toBits(nan_val))));
}
