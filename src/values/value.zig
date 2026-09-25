const std = @import("std");

pub const String = opaque {};
pub const Symbol = opaque {};
pub const BigInt = opaque {};
pub const Object = opaque {};

const F64_EPSILON: f64 = 2.220446049250313e-16;
const F64_MAX_SAFE_INTEGER: f64 = 9007199254740991.0;

inline fn f64IsNan(x: f64) bool {
    return std.math.isNan(x);
}

inline fn f64IsFinite(x: f64) bool {
    return std.math.isFinite(x);
}

inline fn f64SignBit(x: f64) bool {
    const bits: u64 = @bitCast(x);
    return (bits >> 63) != 0;
}

inline fn f64IsInteger(x: f64) bool {
    if (!std.math.isFinite(x)) return false;
    return @floor(x) == x;
}

pub const Value = union(enum) {
    undefined,
    null_val,
    boolean: bool,
    number: f64,
    bigint: *BigInt,
    string: *String,
    symbol: *Symbol,
    object: *Object,

    pub const UNDEFINED: Value = .{ .undefined = {} };
    pub const NULL: Value = .{ .null_val = {} };
    pub const TRUE: Value = .{ .boolean = true };
    pub const FALSE: Value = .{ .boolean = false };
    pub const ZERO: Value = .{ .number = 0.0 };
    pub const NAN: Value = .{ .number = std.math.nan(f64) };

    pub fn fromBool(b: bool) Value {
        return .{ .boolean = b };
    }

    pub fn fromNumber(n: f64) Value {
        return .{ .number = n };
    }

    pub fn fromString(s: *String) Value {
        return .{ .string = s };
    }

    pub fn fromSymbol(s: *Symbol) Value {
        return .{ .symbol = s };
    }

    pub fn fromBigInt(b: *BigInt) Value {
        return .{ .bigint = b };
    }

    pub fn fromObject(o: *Object) Value {
        return .{ .object = o };
    }

    pub fn isUndefined(self: Value) bool {
        return std.meta.activeTag(self) == .undefined;
    }

    pub fn isNull(self: Value) bool {
        return std.meta.activeTag(self) == .null_val;
    }

    pub fn isNullOrUndefined(self: Value) bool {
        const t = std.meta.activeTag(self);
        return t == .undefined or t == .null_val;
    }

    pub fn isBoolean(self: Value) bool {
        return std.meta.activeTag(self) == .boolean;
    }

    pub fn isNumber(self: Value) bool {
        return std.meta.activeTag(self) == .number;
    }

    pub fn isString(self: Value) bool {
        return std.meta.activeTag(self) == .string;
    }

    pub fn isSymbol(self: Value) bool {
        return std.meta.activeTag(self) == .symbol;
    }

    pub fn isBigInt(self: Value) bool {
        return std.meta.activeTag(self) == .bigint;
    }

    pub fn isObject(self: Value) bool {
        return std.meta.activeTag(self) == .object;
    }

    pub fn isPrimitive(self: Value) bool {
        return !self.isObject();
    }

    pub fn isNumeric(self: Value) bool {
        const t = std.meta.activeTag(self);
        return t == .number or t == .bigint;
    }

    pub fn isArrayIndex(self: Value) bool {
        if (!self.isNumber()) return false;
        const n = self.number;
        if (!f64IsFinite(n)) return false;
        if (n < 0) return false;
        if (@floor(n) != n) return false;
        if (n >= 4294967295.0) return false;
        return true;
    }

    pub fn asBool(self: Value) ?bool {
        return switch (self) {
            .boolean => |b| b,
            else => null,
        };
    }

    pub fn asNumber(self: Value) ?f64 {
        return switch (self) {
            .number => |n| n,
            else => null,
        };
    }

    pub fn asString(self: Value) ?*String {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn asSymbol(self: Value) ?*Symbol {
        return switch (self) {
            .symbol => |s| s,
            else => null,
        };
    }

    pub fn asBigInt(self: Value) ?*BigInt {
        return switch (self) {
            .bigint => |b| b,
            else => null,
        };
    }

    pub fn asObject(self: Value) ?*Object {
        return switch (self) {
            .object => |o| o,
            else => null,
        };
    }

    pub fn tagName(self: Value) []const u8 {
        return @tagName(std.meta.activeTag(self));
    }

    pub fn isSameValue(self: Value, other: Value) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);
        if (t1 != t2) return false;

        return switch (self) {
            .undefined => true,
            .null_val => true,
            .boolean => |a| a == other.boolean,
            .number => |a| {
                const b = other.number;
                if (f64IsNan(a) and f64IsNan(b)) return true;
                if (a == 0.0 and b == 0.0) {
                    return f64SignBit(a) == f64SignBit(b);
                }
                return a == b;
            },
            .string => |a| a == other.string,
            .symbol => |a| a == other.symbol,
            .bigint => |a| a == other.bigint,
            .object => |a| a == other.object,
        };
    }

    pub fn isSameValueZero(self: Value, other: Value) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);
        if (t1 != t2) return false;

        return switch (self) {
            .undefined => true,
            .null_val => true,
            .boolean => |a| a == other.boolean,
            .number => |a| {
                const b = other.number;
                if (f64IsNan(a) and f64IsNan(b)) return true;
                return a == b;
            },
            .string => |a| a == other.string,
            .symbol => |a| a == other.symbol,
            .bigint => |a| a == other.bigint,
            .object => |a| a == other.object,
        };
    }

    pub fn strictEquals(self: Value, other: Value) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);
        if (t1 != t2) return false;

        return switch (self) {
            .undefined => true,
            .null_val => true,
            .boolean => |a| a == other.boolean,
            .number => |a| a == other.number,
            .string => |a| a == other.string,
            .symbol => |a| a == other.symbol,
            .bigint => |a| a == other.bigint,
            .object => |a| a == other.object,
        };
    }

    pub fn looseEquals(self: Value, other: Value) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);

        if (t1 == t2) {
            return switch (self) {
                .undefined => true,
                .null_val => true,
                .boolean => |a| a == other.boolean,
                .number => |a| a == other.number,
                .string => |a| a == other.string,
                .symbol => |a| a == other.symbol,
                .bigint => |a| a == other.bigint,
                .object => |a| a == other.object,
            };
        }

        if (self.isNullOrUndefined() and other.isNullOrUndefined()) return true;

        if (t1 == .number and t2 == .string) return false;
        if (t1 == .string and t2 == .number) return false;

        if (t1 == .boolean) {
            return Value.fromNumber(if (self.boolean) 1.0 else 0.0).looseEquals(other);
        }

        if (t2 == .boolean) {
            return self.looseEquals(Value.fromNumber(if (other.boolean) 1.0 else 0.0));
        }

        return false;
    }
};

pub fn isF64Nan(x: f64) bool {
    return f64IsNan(x);
}

pub fn isF64Finite(x: f64) bool {
    return f64IsFinite(x);
}

pub fn isF64Integer(x: f64) bool {
    return f64IsInteger(x);
}

pub fn isF64SafeInteger(x: f64) bool {
    if (!f64IsInteger(x)) return false;
    return @abs(x) <= F64_MAX_SAFE_INTEGER;
}

pub fn f64SignBitOf(x: f64) bool {
    return f64SignBit(x);
}

test "undefined construct" {
    const v = Value.UNDEFINED;
    try std.testing.expect(v.isUndefined());
    try std.testing.expect(!v.isNull());
    try std.testing.expect(v.isPrimitive());
    try std.testing.expect(!v.isObject());
}

test "null construct" {
    const v = Value.NULL;
    try std.testing.expect(v.isNull());
    try std.testing.expect(!v.isUndefined());
    try std.testing.expect(v.isPrimitive());
}

test "isNullOrUndefined" {
    try std.testing.expect(Value.UNDEFINED.isNullOrUndefined());
    try std.testing.expect(Value.NULL.isNullOrUndefined());
    try std.testing.expect(!Value.TRUE.isNullOrUndefined());
    try std.testing.expect(!Value.ZERO.isNullOrUndefined());
}

test "boolean value" {
    const t = Value.fromBool(true);
    const f = Value.fromBool(false);
    try std.testing.expect(t.isBoolean());
    try std.testing.expect(f.isBoolean());
    try std.testing.expect(t.asBool().?);
    try std.testing.expect(!f.asBool().?);
    try std.testing.expectEqual(@as(?f64, null), t.asNumber());
}

test "number value" {
    const n = Value.fromNumber(3.14);
    try std.testing.expect(n.isNumber());
    try std.testing.expectEqual(@as(f64, 3.14), n.asNumber().?);
    try std.testing.expect(!n.isString());
}

test "numeric predicate" {
    try std.testing.expect(Value.fromNumber(1.0).isNumeric());
    try std.testing.expect(!Value.TRUE.isNumeric());
    try std.testing.expect(!Value.UNDEFINED.isNumeric());
}

test "isArrayIndex positive" {
    try std.testing.expect(Value.fromNumber(0.0).isArrayIndex());
    try std.testing.expect(Value.fromNumber(1.0).isArrayIndex());
    try std.testing.expect(Value.fromNumber(100.0).isArrayIndex());
}

test "isArrayIndex negative" {
    try std.testing.expect(!Value.fromNumber(-1.0).isArrayIndex());
}

test "isArrayIndex non-integer" {
    try std.testing.expect(!Value.fromNumber(1.5).isArrayIndex());
    try std.testing.expect(!Value.fromNumber(3.14).isArrayIndex());
}

test "isArrayIndex nan infinity" {
    try std.testing.expect(!Value.NAN.isArrayIndex());
    try std.testing.expect(!Value.fromNumber(std.math.inf(f64)).isArrayIndex());
}

test "isArrayIndex out of range" {
    try std.testing.expect(!Value.fromNumber(4294967295.0).isArrayIndex());
    try std.testing.expect(Value.fromNumber(4294967294.0).isArrayIndex());
}

test "string pointer" {
    var dummy: u8 = 0;
    const fake: *String = @ptrCast(&dummy);
    const v = Value.fromString(fake);
    try std.testing.expect(v.isString());
    try std.testing.expectEqual(fake, v.asString().?);
}

test "symbol pointer" {
    var dummy: u8 = 0;
    const fake: *Symbol = @ptrCast(&dummy);
    const v = Value.fromSymbol(fake);
    try std.testing.expect(v.isSymbol());
    try std.testing.expectEqual(fake, v.asSymbol().?);
}

test "bigint pointer" {
    var dummy: u8 = 0;
    const fake: *BigInt = @ptrCast(&dummy);
    const v = Value.fromBigInt(fake);
    try std.testing.expect(v.isBigInt());
    try std.testing.expectEqual(fake, v.asBigInt().?);
}

test "object pointer" {
    var dummy: u8 = 0;
    const fake: *Object = @ptrCast(&dummy);
    const v = Value.fromObject(fake);
    try std.testing.expect(v.isObject());
    try std.testing.expect(!v.isPrimitive());
    try std.testing.expectEqual(fake, v.asObject().?);
}

test "tagName" {
    try std.testing.expectEqualStrings("undefined", Value.UNDEFINED.tagName());
    try std.testing.expectEqualStrings("null_val", Value.NULL.tagName());
    try std.testing.expectEqualStrings("boolean", Value.TRUE.tagName());
    try std.testing.expectEqualStrings("number", Value.ZERO.tagName());
}

test "isSameValue undefined" {
    try std.testing.expect(Value.UNDEFINED.isSameValue(Value.UNDEFINED));
    try std.testing.expect(!Value.UNDEFINED.isSameValue(Value.NULL));
}

test "isSameValue number" {
    try std.testing.expect(Value.fromNumber(1.0).isSameValue(Value.fromNumber(1.0)));
    try std.testing.expect(!Value.fromNumber(1.0).isSameValue(Value.fromNumber(2.0)));
}

test "isSameValue nan equals nan" {
    try std.testing.expect(Value.NAN.isSameValue(Value.NAN));
}

test "isSameValue positive zero differs from negative zero" {
    const pz = Value.fromNumber(0.0);
    const nz = Value.fromNumber(-0.0);
    try std.testing.expect(!pz.isSameValue(nz));
}

test "isSameValueZero zero equal" {
    const pz = Value.fromNumber(0.0);
    const nz = Value.fromNumber(-0.0);
    try std.testing.expect(pz.isSameValueZero(nz));
}

test "isSameValueZero nan equals nan" {
    try std.testing.expect(Value.NAN.isSameValueZero(Value.NAN));
}

test "strictEquals different tags" {
    try std.testing.expect(!Value.UNDEFINED.strictEquals(Value.NULL));
    try std.testing.expect(!Value.TRUE.strictEquals(Value.fromNumber(1.0)));
}

test "strictEquals numbers" {
    try std.testing.expect(Value.fromNumber(1.0).strictEquals(Value.fromNumber(1.0)));
    try std.testing.expect(!Value.fromNumber(1.0).strictEquals(Value.fromNumber(2.0)));
}

test "strictEquals nan not equal" {
    try std.testing.expect(!Value.NAN.strictEquals(Value.NAN));
}

test "strictEquals zero equals zero" {
    try std.testing.expect(Value.fromNumber(0.0).strictEquals(Value.fromNumber(-0.0)));
}

test "looseEquals null and undefined" {
    try std.testing.expect(Value.UNDEFINED.looseEquals(Value.NULL));
    try std.testing.expect(Value.NULL.looseEquals(Value.UNDEFINED));
}

test "looseEquals same tags" {
    try std.testing.expect(Value.fromNumber(1.0).looseEquals(Value.fromNumber(1.0)));
    try std.testing.expect(Value.TRUE.looseEquals(Value.TRUE));
}

test "looseEquals bool and number" {
    try std.testing.expect(Value.TRUE.looseEquals(Value.fromNumber(1.0)));
    try std.testing.expect(Value.FALSE.looseEquals(Value.fromNumber(0.0)));
    try std.testing.expect(!Value.TRUE.looseEquals(Value.fromNumber(2.0)));
}

test "looseEquals bool and bool" {
    try std.testing.expect(Value.TRUE.looseEquals(Value.TRUE));
    try std.testing.expect(!Value.TRUE.looseEquals(Value.FALSE));
}

test "constants are correct" {
    try std.testing.expect(Value.TRUE.asBool().?);
    try std.testing.expect(!Value.FALSE.asBool().?);
    try std.testing.expectEqual(@as(f64, 0.0), Value.ZERO.asNumber().?);
    try std.testing.expect(f64IsNan(Value.NAN.asNumber().?));
}

test "helper isF64Nan" {
    try std.testing.expect(isF64Nan(std.math.nan(f64)));
    try std.testing.expect(!isF64Nan(1.0));
}

test "helper isF64Finite" {
    try std.testing.expect(isF64Finite(1.0));
    try std.testing.expect(!isF64Finite(std.math.inf(f64)));
}

test "helper isF64Integer" {
    try std.testing.expect(isF64Integer(1.0));
    try std.testing.expect(!isF64Integer(1.5));
}

test "helper isF64SafeInteger" {
    try std.testing.expect(isF64SafeInteger(1.0));
    try std.testing.expect(!isF64SafeInteger(F64_MAX_SAFE_INTEGER + 2.0));
}
