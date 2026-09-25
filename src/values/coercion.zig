const std = @import("std");
const Value = @import("value.zig").Value;


pub const CoercionError = error{
    CannotConvertToString,
    CannotConvertToNumber,
    CannotConvertToObject,
    CannotConvertToPrimitive,
    SymbolToNumber,
    BigIntToNumber,
};

pub fn toBoolean(v: Value) bool {
    return switch (v) {
        .undefined => false,
        .null_val => false,
        .boolean => |b| b,
        .number => |n| {
            if (n == 0.0) return false;
            if (std.math.isNan(n)) return false;
            return true;
        },
        .string => |s| !stringIsEmpty(s),
        .symbol => true,
        .bigint => |b| bigintIsNonZero(b),
        .object => true,
    };
}

fn stringIsEmpty(s: *@import("value.zig").String) bool {
    _ = s;
    return false;
}

fn bigintIsNonZero(b: *@import("value.zig").BigInt) bool {
    _ = b;
    return true;
}

pub fn toNumber(v: Value) CoercionError!f64 {
    return switch (v) {
        .undefined => std.math.nan(f64),
        .null_val => 0.0,
        .boolean => |b| if (b) 1.0 else 0.0,
        .number => |n| n,
        .string => |s| stringToNumber(s),
        .symbol => error.SymbolToNumber,
        .bigint => error.BigIntToNumber,
        .object => error.CannotConvertToNumber,
    };
}

fn stringToNumber(s: *@import("value.zig").String) f64 {
    _ = s;
    return std.math.nan(f64);
}

pub fn toInteger(v: Value) CoercionError!f64 {
    const n = try toNumber(v);
    if (std.math.isNan(n)) return 0.0;
    if (n == 0.0) return 0.0;
    if (std.math.isInf(n)) return n;
    return @trunc(n);
}

pub fn toInt32(v: Value) CoercionError!i32 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    if (n == 0.0) return 0;

    const m = @mod(@trunc(n), 4294967296.0);
    const m_positive = if (m < 0) m + 4294967296.0 else m;

    if (m_positive >= 2147483648.0) {
        return @intFromFloat(m_positive - 4294967296.0);
    }
    return @intFromFloat(m_positive);
}

pub fn toUint32(v: Value) CoercionError!u32 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    if (n == 0.0) return 0;

    const m = @mod(@trunc(n), 4294967296.0);
    const m_positive = if (m < 0) m + 4294967296.0 else m;
    return @intFromFloat(m_positive);
}

pub fn toInt16(v: Value) CoercionError!i16 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    const m = @mod(@trunc(n), 65536.0);
    const m_positive = if (m < 0) m + 65536.0 else m;
    if (m_positive >= 32768.0) {
        return @intFromFloat(m_positive - 65536.0);
    }
    return @intFromFloat(m_positive);
}

pub fn toUint16(v: Value) CoercionError!u16 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    const m = @mod(@trunc(n), 65536.0);
    const m_positive = if (m < 0) m + 65536.0 else m;
    return @intFromFloat(m_positive);
}

pub fn toInt8(v: Value) CoercionError!i8 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    const m = @mod(@trunc(n), 256.0);
    const m_positive = if (m < 0) m + 256.0 else m;
    if (m_positive >= 128.0) {
        return @intFromFloat(m_positive - 256.0);
    }
    return @intFromFloat(m_positive);
}

pub fn toUint8(v: Value) CoercionError!u8 {
    const n = try toNumber(v);
    if (std.math.isNan(n) or std.math.isInf(n)) return 0;
    const m = @mod(@trunc(n), 256.0);
    const m_positive = if (m < 0) m + 256.0 else m;
    return @intFromFloat(m_positive);
}

pub fn toUint8Clamp(v: Value) CoercionError!u8 {
    const n = try toNumber(v);
    if (std.math.isNan(n)) return 0;
    if (n <= 0.0) return 0;
    if (n >= 255.0) return 255;

    const f = @floor(n);
    if (f + 0.5 < n) return @intFromFloat(f + 1);
    if (n < f + 0.5) return @intFromFloat(f);
    if (@mod(f, 2.0) == 0.0) return @intFromFloat(f);
    return @intFromFloat(f + 1);
}

pub fn toLength(v: Value) CoercionError!usize {
    const n = try toInteger(v);
    if (n <= 0.0) return 0;
    if (n >= 9007199254740991.0) return 9007199254740991;
    return @intFromFloat(n);
}

pub fn isTruthy(v: Value) bool {
    return toBoolean(v);
}

pub fn isFalsy(v: Value) bool {
    return !toBoolean(v);
}

test "toBoolean undefined" {
    try std.testing.expect(!toBoolean(Value.UNDEFINED));
}

test "toBoolean null" {
    try std.testing.expect(!toBoolean(Value.NULL));
}

test "toBoolean boolean" {
    try std.testing.expect(toBoolean(Value.TRUE));
    try std.testing.expect(!toBoolean(Value.FALSE));
}

test "toBoolean number zero" {
    try std.testing.expect(!toBoolean(Value.fromNumber(0.0)));
    try std.testing.expect(!toBoolean(Value.fromNumber(-0.0)));
}

test "toBoolean number nonzero" {
    try std.testing.expect(toBoolean(Value.fromNumber(1.0)));
    try std.testing.expect(toBoolean(Value.fromNumber(-1.0)));
}

test "toBoolean nan" {
    try std.testing.expect(!toBoolean(Value.NAN));
}

test "toNumber undefined" {
    try std.testing.expect(std.math.isNan(try toNumber(Value.UNDEFINED)));
}

test "toNumber null" {
    try std.testing.expectEqual(@as(f64, 0.0), try toNumber(Value.NULL));
}

test "toNumber boolean" {
    try std.testing.expectEqual(@as(f64, 1.0), try toNumber(Value.TRUE));
    try std.testing.expectEqual(@as(f64, 0.0), try toNumber(Value.FALSE));
}

test "toNumber number" {
    try std.testing.expectEqual(@as(f64, 3.14), try toNumber(Value.fromNumber(3.14)));
}

test "toNumber symbol error" {
    var dummy: u8 = 0;
    const sym: *@import("value.zig").Symbol = @ptrCast(&dummy);
    try std.testing.expectError(CoercionError.SymbolToNumber, toNumber(Value.fromSymbol(sym)));
}

test "toNumber bigint error" {
    var dummy: u8 = 0;
    const bi: *@import("value.zig").BigInt = @ptrCast(&dummy);
    try std.testing.expectError(CoercionError.BigIntToNumber, toNumber(Value.fromBigInt(bi)));
}

test "toInteger truncates" {
    try std.testing.expectEqual(@as(f64, 3.0), try toInteger(Value.fromNumber(3.7)));
    try std.testing.expectEqual(@as(f64, -3.0), try toInteger(Value.fromNumber(-3.7)));
}

test "toInteger nan is zero" {
    try std.testing.expectEqual(@as(f64, 0.0), try toInteger(Value.NAN));
}

test "toInt32 simple" {
    try std.testing.expectEqual(@as(i32, 0), try toInt32(Value.fromNumber(0.0)));
    try std.testing.expectEqual(@as(i32, 1), try toInt32(Value.fromNumber(1.0)));
    try std.testing.expectEqual(@as(i32, 42), try toInt32(Value.fromNumber(42.0)));
}

test "toInt32 wraps large" {
    try std.testing.expectEqual(@as(i32, -1), try toInt32(Value.fromNumber(4294967295.0)));
}

test "toInt32 nan is zero" {
    try std.testing.expectEqual(@as(i32, 0), try toInt32(Value.NAN));
}

test "toUint32 simple" {
    try std.testing.expectEqual(@as(u32, 42), try toUint32(Value.fromNumber(42.0)));
}

test "toUint32 wraps" {
    try std.testing.expectEqual(@as(u32, 4294967295), try toUint32(Value.fromNumber(4294967295.0)));
}

test "toUint32 negative" {
    try std.testing.expectEqual(@as(u32, 4294967295), try toUint32(Value.fromNumber(-1.0)));
}

test "toInt16 simple" {
    try std.testing.expectEqual(@as(i16, 42), try toInt16(Value.fromNumber(42.0)));
}

test "toInt16 wraps" {
    try std.testing.expectEqual(@as(i16, -1), try toInt16(Value.fromNumber(65535.0)));
}

test "toUint16 simple" {
    try std.testing.expectEqual(@as(u16, 42), try toUint16(Value.fromNumber(42.0)));
}

test "toUint16 wraps" {
    try std.testing.expectEqual(@as(u16, 65535), try toUint16(Value.fromNumber(65535.0)));
}

test "toInt8 simple" {
    try std.testing.expectEqual(@as(i8, 42), try toInt8(Value.fromNumber(42.0)));
}

test "toInt8 wraps" {
    try std.testing.expectEqual(@as(i8, -1), try toInt8(Value.fromNumber(255.0)));
}

test "toUint8 simple" {
    try std.testing.expectEqual(@as(u8, 42), try toUint8(Value.fromNumber(42.0)));
}

test "toUint8 wraps" {
    try std.testing.expectEqual(@as(u8, 255), try toUint8(Value.fromNumber(255.0)));
    try std.testing.expectEqual(@as(u8, 255), try toUint8(Value.fromNumber(511.0)));
}

test "toUint8Clamp simple" {
    try std.testing.expectEqual(@as(u8, 42), try toUint8Clamp(Value.fromNumber(42.0)));
}

test "toUint8Clamp clamps" {
    try std.testing.expectEqual(@as(u8, 0), try toUint8Clamp(Value.fromNumber(-5.0)));
    try std.testing.expectEqual(@as(u8, 255), try toUint8Clamp(Value.fromNumber(300.0)));
}

test "toUint8Clamp nan is zero" {
    try std.testing.expectEqual(@as(u8, 0), try toUint8Clamp(Value.NAN));
}

test "toLength" {
    try std.testing.expectEqual(@as(usize, 0), try toLength(Value.fromNumber(-5.0)));
    try std.testing.expectEqual(@as(usize, 10), try toLength(Value.fromNumber(10.0)));
}

test "isTruthy isFalsy" {
    try std.testing.expect(isTruthy(Value.TRUE));
    try std.testing.expect(isFalsy(Value.FALSE));
    try std.testing.expect(isFalsy(Value.UNDEFINED));
    try std.testing.expect(isTruthy(Value.fromNumber(1.0)));
}
