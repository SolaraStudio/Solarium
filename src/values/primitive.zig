const std = @import("std");
const Value = @import("value.zig").Value;

pub const PrimitiveTag = enum(u8) {
    undefined,
    null_val,
    boolean,
    number,
    string,
    symbol,
    bigint,
};

pub fn tagOf(v: Value) ?PrimitiveTag {
    return switch (v) {
        .undefined => .undefined,
        .null_val => .null_val,
        .boolean => .boolean,
        .number => .number,
        .string => .string,
        .symbol => .symbol,
        .bigint => .bigint,
        .object => null,
    };
}

pub fn isPrimitive(v: Value) bool {
    return tagOf(v) != null;
}

pub fn isObject(v: Value) bool {
    return tagOf(v) == null;
}

pub fn isNullOrUndefined(v: Value) bool {
    const t = tagOf(v) orelse return false;
    return t == .null_val or t == .undefined;
}

pub fn primitiveName(tag: PrimitiveTag) []const u8 {
    return @tagName(tag);
}

pub fn stableHash(v: Value) u64 {
    return switch (v) {
        .undefined => 0x1111111111111111,
        .null_val => 0x2222222222222222,
        .boolean => |b| if (b) 0x3333333333333333 else 0x4444444444444444,
        .number => |n| @bitCast(n),
        .string => |s| @intFromPtr(s),
        .symbol => |s| @intFromPtr(s),
        .bigint => |b| @intFromPtr(b),
        .object => |o| @intFromPtr(o),
    };
}

pub const OrderResult = enum {
    less,
    equal,
    greater,
    unordered,
};

pub fn compare(a: Value, b: Value) OrderResult {
    const ta = tagOf(a) orelse return .unordered;
    const tb = tagOf(b) orelse return .unordered;

    if (ta != tb) {
        if (@intFromEnum(ta) < @intFromEnum(tb)) return .less;
        return .greater;
    }

    return switch (ta) {
        .undefined => .equal,
        .null_val => .equal,
        .boolean => blk: {
            const x = @intFromBool(a.boolean);
            const y = @intFromBool(b.boolean);
            if (x == y) break :blk .equal;
            break :blk if (x < y) .less else .greater;
        },
        .number => blk: {
            if (a.number < b.number) break :blk .less;
            if (a.number > b.number) break :blk .greater;
            break :blk .equal;
        },
        .string => blk: {
            const x = @intFromPtr(a.string);
            const y = @intFromPtr(b.string);
            if (x == y) break :blk .equal;
            break :blk if (x < y) .less else .greater;
        },
        .symbol => blk: {
            const x = @intFromPtr(a.symbol);
            const y = @intFromPtr(b.symbol);
            if (x == y) break :blk .equal;
            break :blk if (x < y) .less else .greater;
        },
        .bigint => blk: {
            const x = @intFromPtr(a.bigint);
            const y = @intFromPtr(b.bigint);
            if (x == y) break :blk .equal;
            break :blk if (x < y) .less else .greater;
        },
    };
}

test "tagOf undefined" {
    try std.testing.expectEqual(PrimitiveTag.undefined, tagOf(Value.UNDEFINED).?);
}

test "tagOf null" {
    try std.testing.expectEqual(PrimitiveTag.null_val, tagOf(Value.NULL).?);
}

test "tagOf boolean" {
    try std.testing.expectEqual(PrimitiveTag.boolean, tagOf(Value.TRUE).?);
}

test "tagOf number" {
    try std.testing.expectEqual(PrimitiveTag.number, tagOf(Value.fromNumber(1.0)).?);
}

test "tagOf object returns null" {
    var dummy: u8 = 0;
    const obj: *@import("value.zig").Object = @ptrCast(&dummy);
    try std.testing.expectEqual(@as(?PrimitiveTag, null), tagOf(Value.fromObject(obj)));
}

test "isPrimitive" {
    try std.testing.expect(isPrimitive(Value.UNDEFINED));
    try std.testing.expect(isPrimitive(Value.NULL));
    try std.testing.expect(isPrimitive(Value.TRUE));
    try std.testing.expect(isPrimitive(Value.fromNumber(1.0)));
}

test "isObject" {
    var dummy: u8 = 0;
    const obj: *@import("value.zig").Object = @ptrCast(&dummy);
    try std.testing.expect(isObject(Value.fromObject(obj)));
    try std.testing.expect(!isObject(Value.TRUE));
}

test "isNullOrUndefined" {
    try std.testing.expect(isNullOrUndefined(Value.UNDEFINED));
    try std.testing.expect(isNullOrUndefined(Value.NULL));
    try std.testing.expect(!isNullOrUndefined(Value.TRUE));
    try std.testing.expect(!isNullOrUndefined(Value.fromNumber(0.0)));
}

test "primitiveName" {
    try std.testing.expectEqualStrings("undefined", primitiveName(.undefined));
    try std.testing.expectEqualStrings("number", primitiveName(.number));
    try std.testing.expectEqualStrings("boolean", primitiveName(.boolean));
}

test "stableHash distinct tags" {
    try std.testing.expect(stableHash(Value.UNDEFINED) != stableHash(Value.NULL));
    try std.testing.expect(stableHash(Value.TRUE) != stableHash(Value.FALSE));
}

test "stableHash deterministic" {
    try std.testing.expectEqual(stableHash(Value.fromNumber(3.14)), stableHash(Value.fromNumber(3.14)));
    try std.testing.expectEqual(stableHash(Value.TRUE), stableHash(Value.TRUE));
}

test "compare equal undefined" {
    try std.testing.expectEqual(OrderResult.equal, compare(Value.UNDEFINED, Value.UNDEFINED));
}

test "compare less across tags" {
    try std.testing.expectEqual(OrderResult.less, compare(Value.UNDEFINED, Value.NULL));
    try std.testing.expectEqual(OrderResult.greater, compare(Value.NULL, Value.UNDEFINED));
}

test "compare booleans" {
    try std.testing.expectEqual(OrderResult.less, compare(Value.FALSE, Value.TRUE));
    try std.testing.expectEqual(OrderResult.greater, compare(Value.TRUE, Value.FALSE));
}

test "compare numbers" {
    try std.testing.expectEqual(OrderResult.less, compare(Value.fromNumber(1.0), Value.fromNumber(2.0)));
    try std.testing.expectEqual(OrderResult.greater, compare(Value.fromNumber(3.0), Value.fromNumber(2.0)));
    try std.testing.expectEqual(OrderResult.equal, compare(Value.fromNumber(2.0), Value.fromNumber(2.0)));
}

test "compare object unordered" {
    var dummy: u8 = 0;
    const obj: *@import("value.zig").Object = @ptrCast(&dummy);
    try std.testing.expectEqual(OrderResult.unordered, compare(Value.fromObject(obj), Value.TRUE));
    try std.testing.expectEqual(OrderResult.unordered, compare(Value.TRUE, Value.fromObject(obj)));
}
