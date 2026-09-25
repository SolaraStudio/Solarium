const std = @import("std");
const Value = @import("value.zig").Value;

pub const TRUE_STRING: []const u8 = "true";
pub const FALSE_STRING: []const u8 = "false";

pub fn isBoolean(v: Value) bool {
    return v == .boolean;
}

pub fn valueOf(v: Value) ?bool {
    return switch (v) {
        .boolean => |b| b,
        else => null,
    };
}

pub fn toNumber(v: Value) ?f64 {
    return switch (v) {
        .boolean => |b| if (b) 1.0 else 0.0,
        else => null,
    };
}

pub fn toString(v: Value) ?[]const u8 {
    return switch (v) {
        .boolean => |b| if (b) TRUE_STRING else FALSE_STRING,
        else => null,
    };
}

pub fn negate(v: Value) ?Value {
    return switch (v) {
        .boolean => |b| Value.fromBool(!b),
        else => null,
    };
}

pub fn and_(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromBool(x and y);
}

pub fn or_(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromBool(x or y);
}

pub fn xor(a: Value, b: Value) ?Value {
    const x = valueOf(a) orelse return null;
    const y = valueOf(b) orelse return null;
    return Value.fromBool(x != y);
}

pub fn fromString(s: []const u8) ?bool {
    if (std.mem.eql(u8, s, TRUE_STRING)) return true;
    if (std.mem.eql(u8, s, FALSE_STRING)) return false;
    return null;
}

test "isBoolean true" {
    try std.testing.expect(isBoolean(Value.TRUE));
}

test "isBoolean false" {
    try std.testing.expect(isBoolean(Value.FALSE));
}

test "isBoolean rejects number" {
    try std.testing.expect(!isBoolean(Value.fromNumber(1.0)));
    try std.testing.expect(!isBoolean(Value.UNDEFINED));
}

test "valueOf true" {
    try std.testing.expect(valueOf(Value.TRUE).?);
}

test "valueOf false" {
    try std.testing.expect(!valueOf(Value.FALSE).?);
}

test "valueOf returns null for non-boolean" {
    try std.testing.expectEqual(@as(?bool, null), valueOf(Value.fromNumber(1.0)));
}

test "toNumber true" {
    try std.testing.expectEqual(@as(?f64, 1.0), toNumber(Value.TRUE));
}

test "toNumber false" {
    try std.testing.expectEqual(@as(?f64, 0.0), toNumber(Value.FALSE));
}

test "toNumber null for non-boolean" {
    try std.testing.expectEqual(@as(?f64, null), toNumber(Value.UNDEFINED));
}

test "toString true" {
    try std.testing.expectEqualStrings("true", toString(Value.TRUE).?);
}

test "toString false" {
    try std.testing.expectEqualStrings("false", toString(Value.FALSE).?);
}

test "negate true" {
    try std.testing.expect(!negate(Value.TRUE).?.asBool().?);
}

test "negate false" {
    try std.testing.expect(negate(Value.FALSE).?.asBool().?);
}

test "negate non-boolean" {
    try std.testing.expectEqual(@as(?Value, null), negate(Value.fromNumber(1.0)));
}

test "and both true" {
    try std.testing.expect(and_(Value.TRUE, Value.TRUE).?.asBool().?);
}

test "and mixed" {
    try std.testing.expect(!and_(Value.TRUE, Value.FALSE).?.asBool().?);
    try std.testing.expect(!and_(Value.FALSE, Value.TRUE).?.asBool().?);
    try std.testing.expect(!and_(Value.FALSE, Value.FALSE).?.asBool().?);
}

test "or cases" {
    try std.testing.expect(or_(Value.TRUE, Value.TRUE).?.asBool().?);
    try std.testing.expect(or_(Value.TRUE, Value.FALSE).?.asBool().?);
    try std.testing.expect(or_(Value.FALSE, Value.TRUE).?.asBool().?);
    try std.testing.expect(!or_(Value.FALSE, Value.FALSE).?.asBool().?);
}

test "xor cases" {
    try std.testing.expect(!xor(Value.TRUE, Value.TRUE).?.asBool().?);
    try std.testing.expect(xor(Value.TRUE, Value.FALSE).?.asBool().?);
    try std.testing.expect(xor(Value.FALSE, Value.TRUE).?.asBool().?);
    try std.testing.expect(!xor(Value.FALSE, Value.FALSE).?.asBool().?);
}

test "fromString true" {
    try std.testing.expect(fromString("true").?);
}

test "fromString false" {
    try std.testing.expect(!fromString("false").?);
}

test "fromString invalid" {
    try std.testing.expectEqual(@as(?bool, null), fromString("True"));
    try std.testing.expectEqual(@as(?bool, null), fromString("yes"));
}
