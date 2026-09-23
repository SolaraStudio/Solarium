const std = @import("std");
const f64_mod = @import("f64.zig");

pub const Tag = enum(u3) {
    object = 0,
    int32 = 1,
    undefined = 2,
    null_val = 3,
    boolean = 4,
    symbol = 5,
    string = 6,
    reserved = 7,
};

pub const NAN_BOX_MASK: u64 = 0xFFFF_0000_0000_0000;
pub const PAYLOAD_MASK: u64 = 0x0000_1FFF_FFFF_FFFF;
pub const TAG_SHIFT: u6 = 45;
pub const TAG_MASK: u64 = 0x7;

pub const CANONICAL_NAN: u64 = 0x7FF8_0000_0000_0000;
pub const BOXED_NAN_PREFIX: u64 = 0x7FF9_0000_0000_0000;
pub const BOXED_NAN_PREFIX_MASK: u64 = 0xFFFF_0000_0000_0000;

pub const UNDEFINED_BITS: u64 = BOXED_NAN_PREFIX | 0x1;
pub const NULL_BITS: u64 = BOXED_NAN_PREFIX | 0x2;
pub const TRUE_BITS: u64 = BOXED_NAN_PREFIX | 0x4;
pub const FALSE_BITS: u64 = BOXED_NAN_PREFIX | 0x8;

pub const TaggedValue = union(enum) {
    double: f64,
    int32: i32,
    boolean: bool,
    object: u48,
    string: u48,
    symbol: u48,
    null_val: void,
    undefined: void,

    pub fn isDouble(self: TaggedValue) bool {
        return self == .double;
    }

    pub fn isInt32(self: TaggedValue) bool {
        return self == .int32;
    }

    pub fn isBoolean(self: TaggedValue) bool {
        return self == .boolean;
    }

    pub fn isObject(self: TaggedValue) bool {
        return self == .object;
    }

    pub fn isString(self: TaggedValue) bool {
        return self == .string;
    }

    pub fn isSymbol(self: TaggedValue) bool {
        return self == .symbol;
    }

    pub fn isNull(self: TaggedValue) bool {
        return self == .null_val;
    }

    pub fn isUndefined(self: TaggedValue) bool {
        return self == .undefined;
    }

    pub fn isNumber(self: TaggedValue) bool {
        return self == .double or self == .int32;
    }

    pub fn asDouble(self: TaggedValue) ?f64 {
        return switch (self) {
            .double => |v| v,
            .int32 => |v| @floatFromInt(v),
            else => null,
        };
    }

    pub fn asInt32(self: TaggedValue) ?i32 {
        return switch (self) {
            .int32 => |v| v,
            else => null,
        };
    }

    pub fn asBoolean(self: TaggedValue) ?bool {
        return switch (self) {
            .boolean => |v| v,
            else => null,
        };
    }
};

pub fn boxDouble(value: f64) u64 {
    return @bitCast(value);
}

pub fn unboxDouble(bits: u64) f64 {
    return @bitCast(bits);
}

pub fn boxInt32(value: i32) u64 {
    const payload: u64 = @as(u32, @bitCast(value));
    return BOXED_NAN_PREFIX | (@as(u64, @intFromEnum(Tag.int32)) << TAG_SHIFT) | payload;
}

pub fn unboxInt32(bits: u64) i32 {
    const payload: u32 = @truncate(bits);
    return @bitCast(payload);
}

pub fn boxBoolean(value: bool) u64 {
    return if (value) TRUE_BITS else FALSE_BITS;
}

pub fn unboxBoolean(bits: u64) bool {
    return (bits & 0x4) != 0;
}

pub fn boxUndefined() u64 {
    return UNDEFINED_BITS;
}

pub fn boxNull() u64 {
    return NULL_BITS;
}

pub fn boxObject(index: u48) u64 {
    return BOXED_NAN_PREFIX | (@as(u64, @intFromEnum(Tag.object)) << TAG_SHIFT) | @as(u64, index);
}

pub fn boxString(index: u48) u64 {
    return BOXED_NAN_PREFIX | (@as(u64, @intFromEnum(Tag.string)) << TAG_SHIFT) | @as(u64, index);
}

pub fn boxSymbol(index: u48) u64 {
    return BOXED_NAN_PREFIX | (@as(u64, @intFromEnum(Tag.symbol)) << TAG_SHIFT) | @as(u64, index);
}

pub fn isBoxed(bits: u64) bool {


    return (bits & BOXED_NAN_PREFIX_MASK) == BOXED_NAN_PREFIX;
}

pub fn isCanonicalNan(bits: u64) bool {
    return bits == CANONICAL_NAN;
}

pub fn tagOf(bits: u64) ?Tag {
    if (!isBoxed(bits)) return null;
    if (bits == TRUE_BITS or bits == FALSE_BITS) return .boolean;
    if (bits == UNDEFINED_BITS) return .undefined;
    if (bits == NULL_BITS) return .null_val;
    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    return @enumFromInt(tag_bits);
}

pub fn payloadOf(bits: u64) u48 {
    return @truncate(bits & PAYLOAD_MASK);
}

pub fn isUndefined(bits: u64) bool {
    return bits == UNDEFINED_BITS;
}

pub fn isNull(bits: u64) bool {
    return bits == NULL_BITS;
}

pub fn isBoolean(bits: u64) bool {
    return bits == TRUE_BITS or bits == FALSE_BITS;
}

pub fn isInt32Boxed(bits: u64) bool {
    if (!isBoxed(bits)) return false;
    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    return @as(Tag, @enumFromInt(tag_bits)) == .int32;
}

pub fn isObjectBoxed(bits: u64) bool {
    if (!isBoxed(bits)) return false;
    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    return @as(Tag, @enumFromInt(tag_bits)) == .object;
}

pub fn isStringBoxed(bits: u64) bool {
    if (!isBoxed(bits)) return false;
    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    return @as(Tag, @enumFromInt(tag_bits)) == .string;
}

pub fn isSymbolBoxed(bits: u64) bool {
    if (!isBoxed(bits)) return false;
    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    return @as(Tag, @enumFromInt(tag_bits)) == .symbol;
}

pub fn pack(value: TaggedValue) u64 {
    return switch (value) {
        .double => |v| boxDouble(v),
        .int32 => |v| boxInt32(v),
        .boolean => |v| boxBoolean(v),
        .object => |i| boxObject(i),
        .string => |i| boxString(i),
        .symbol => |i| boxSymbol(i),
        .null_val => boxNull(),
        .undefined => boxUndefined(),
    };
}

pub fn unpack(bits: u64) TaggedValue {
    if (!isBoxed(bits)) {
        return .{ .double = unboxDouble(bits) };
    }
    if (bits == TRUE_BITS) return .{ .boolean = true };
    if (bits == FALSE_BITS) return .{ .boolean = false };
    if (bits == UNDEFINED_BITS) return .undefined;
    if (bits == NULL_BITS) return .null_val;

    const tag_bits: u3 = @truncate((bits >> TAG_SHIFT) & TAG_MASK);
    const tag: Tag = @enumFromInt(tag_bits);
    return switch (tag) {
        .int32 => .{ .int32 = unboxInt32(bits) },
        .object => .{ .object = payloadOf(bits) },
        .string => .{ .string = payloadOf(bits) },
        .symbol => .{ .symbol = payloadOf(bits) },
        .undefined => .undefined,
        .null_val => .null_val,
        .boolean => .{ .boolean = unboxBoolean(bits) },
        .reserved => .undefined,
    };
}

pub fn isTruthy(bits: u64) bool {
    if (!isBoxed(bits)) {
        const v = unboxDouble(bits);
        if (v == 0.0) return false;
        if (f64_mod.isNan(v)) return false;
        return true;
    }
    if (bits == FALSE_BITS) return false;
    if (bits == UNDEFINED_BITS) return false;
    if (bits == NULL_BITS) return false;
    if (bits == TRUE_BITS) return true;
    if (isInt32Boxed(bits)) return unboxInt32(bits) != 0;
    return true;
}

test "box and unbox double" {
    const v = 3.14;
    const bits = boxDouble(v);
    const back = unboxDouble(bits);
    try std.testing.expectEqual(v, back);
}

test "double is not boxed" {
    try std.testing.expect(!isBoxed(boxDouble(1.0)));
    try std.testing.expect(!isBoxed(boxDouble(0.0)));
    try std.testing.expect(!isBoxed(boxDouble(-1.0)));
}

test "box and unbox int32" {
    const v: i32 = -42;
    const bits = boxInt32(v);
    try std.testing.expect(isBoxed(bits));
    try std.testing.expect(isInt32Boxed(bits));
    try std.testing.expectEqual(v, unboxInt32(bits));
}

test "box and unbox boolean" {
    const t_bits = boxBoolean(true);
    const f_bits = boxBoolean(false);
    try std.testing.expect(isBoolean(t_bits));
    try std.testing.expect(isBoolean(f_bits));
    try std.testing.expect(unboxBoolean(t_bits));
    try std.testing.expect(!unboxBoolean(f_bits));
}

test "box undefined and null" {
    const u = boxUndefined();
    const n = boxNull();
    try std.testing.expect(isUndefined(u));
    try std.testing.expect(!isUndefined(n));
    try std.testing.expect(isNull(n));
    try std.testing.expect(!isNull(u));
}

test "box object string symbol" {
    const o = boxObject(1234);
    const s = boxString(5678);
    const y = boxSymbol(9012);
    try std.testing.expect(isObjectBoxed(o));
    try std.testing.expect(isStringBoxed(s));
    try std.testing.expect(isSymbolBoxed(y));
    try std.testing.expectEqual(@as(u48, 1234), payloadOf(o));
    try std.testing.expectEqual(@as(u48, 5678), payloadOf(s));
    try std.testing.expectEqual(@as(u48, 9012), payloadOf(y));
}

test "tagOf" {
    try std.testing.expectEqual(Tag.int32, tagOf(boxInt32(1)).?);
    try std.testing.expectEqual(Tag.boolean, tagOf(boxBoolean(true)).?);
    try std.testing.expectEqual(Tag.object, tagOf(boxObject(0)).?);
    try std.testing.expectEqual(Tag.string, tagOf(boxString(0)).?);
    try std.testing.expectEqual(Tag.symbol, tagOf(boxSymbol(0)).?);
    try std.testing.expectEqual(Tag.undefined, tagOf(boxUndefined()).?);
    try std.testing.expectEqual(Tag.null_val, tagOf(boxNull()).?);
}

test "tagOf on plain double" {
    try std.testing.expect(tagOf(boxDouble(1.0)) == null);
}

test "pack and unpack round trip" {
    const values = [_]TaggedValue{
        .{ .double = 3.14 },
        .{ .double = -2.71 },
        .{ .int32 = 42 },
        .{ .int32 = -1 },
        .{ .boolean = true },
        .{ .boolean = false },
        .{ .undefined = {} },
        .{ .null_val = {} },
        .{ .object = 100 },
        .{ .string = 200 },
        .{ .symbol = 300 },
    };

    for (values) |v| {
        const bits = pack(v);
        const back = unpack(bits);
        try std.testing.expectEqual(std.meta.activeTag(v), std.meta.activeTag(back));
        switch (v) {
            .double => |x| try std.testing.expectEqual(x, back.double),
            .int32 => |x| try std.testing.expectEqual(x, back.int32),
            .boolean => |x| try std.testing.expectEqual(x, back.boolean),
            .undefined => try std.testing.expect(back == .undefined),
            .null_val => try std.testing.expect(back == .null_val),
            .object => |x| try std.testing.expectEqual(x, back.object),
            .string => |x| try std.testing.expectEqual(x, back.string),
            .symbol => |x| try std.testing.expectEqual(x, back.symbol),
        }
    }
}

test "TaggedValue predicates" {
    try std.testing.expect((TaggedValue{ .double = 1.0 }).isDouble());
    try std.testing.expect((TaggedValue{ .int32 = 1 }).isInt32());
    try std.testing.expect((TaggedValue{ .boolean = true }).isBoolean());
    try std.testing.expect((TaggedValue{ .object = 1 }).isObject());
    try std.testing.expect((TaggedValue{ .string = 1 }).isString());
    try std.testing.expect((TaggedValue{ .symbol = 1 }).isSymbol());
    try std.testing.expect((TaggedValue{ .null_val = {} }).isNull());
    try std.testing.expect((TaggedValue{ .undefined = {} }).isUndefined());
    try std.testing.expect((TaggedValue{ .double = 1.0 }).isNumber());
    try std.testing.expect((TaggedValue{ .int32 = 1 }).isNumber());
}

test "asDouble and asInt32 and asBoolean" {
    try std.testing.expectEqual(@as(?f64, 3.14), (TaggedValue{ .double = 3.14 }).asDouble());
    try std.testing.expectEqual(@as(?f64, 42.0), (TaggedValue{ .int32 = 42 }).asDouble());
    try std.testing.expect((TaggedValue{ .boolean = true }).asDouble() == null);

    try std.testing.expectEqual(@as(?i32, 42), (TaggedValue{ .int32 = 42 }).asInt32());
    try std.testing.expect((TaggedValue{ .double = 1.0 }).asInt32() == null);

    try std.testing.expectEqual(@as(?bool, true), (TaggedValue{ .boolean = true }).asBoolean());
    try std.testing.expect((TaggedValue{ .int32 = 1 }).asBoolean() == null);
}

test "isTruthy for doubles" {
    try std.testing.expect(isTruthy(boxDouble(1.0)));
    try std.testing.expect(!isTruthy(boxDouble(0.0)));
    try std.testing.expect(!isTruthy(boxDouble(-0.0)));
    try std.testing.expect(isTruthy(boxDouble(-1.0)));
    try std.testing.expect(!isTruthy(boxDouble(f64_mod.nan())));
}

test "isTruthy for boxed values" {
    try std.testing.expect(isTruthy(boxBoolean(true)));
    try std.testing.expect(!isTruthy(boxBoolean(false)));
    try std.testing.expect(!isTruthy(boxUndefined()));
    try std.testing.expect(!isTruthy(boxNull()));
    try std.testing.expect(isTruthy(boxInt32(1)));
    try std.testing.expect(!isTruthy(boxInt32(0)));
    try std.testing.expect(isTruthy(boxObject(0)));
    try std.testing.expect(isTruthy(boxString(0)));
}

test "canonical nan detection" {
    try std.testing.expect(isCanonicalNan(CANONICAL_NAN));
    try std.testing.expect(!isCanonicalNan(0));
    try std.testing.expect(!isCanonicalNan(BOXED_NAN_PREFIX));
}
