const std = @import("std");
const errors = @import("error.zig");

pub const TypeError = struct {
    message: []const u8,
    operation: ?[]const u8 = null,

    pub fn init(message: []const u8) TypeError {
        return .{ .message = message };
    }

    pub fn withOperation(message: []const u8, op: []const u8) TypeError {
        return .{ .message = message, .operation = op };
    }

    pub fn name(self: TypeError) []const u8 {
        _ = self;
        return "TypeError";
    }

    pub fn format(
        self: TypeError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("TypeError: {s}", .{self.message});
        if (self.operation) |op| {
            try writer.print(" (in {s})", .{op});
        }
    }

    pub fn toError(self: TypeError) errors.Error {
        _ = self;
        return error.TypeError;
    }
};

pub const Kind = enum {
    not_callable,
    not_constructable,
    not_object,
    not_iterable,
    not_async_iterable,
    cannot_read_property,
    cannot_set_property,
    cannot_delete_property,
    cannot_define_property,
    cannot_redefine_property,
    cannot_extend_object,
    cannot_convert_to_primitive,
    cannot_convert_to_string,
    cannot_convert_to_number,
    cannot_convert_to_bigint,
    cannot_convert_to_object,
    invalid_argument,
    null_or_undefined,
    invalid_this,
    missing_property,
    incompatible_types,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .not_callable => "value is not a function",
            .not_constructable => "value is not a constructor",
            .not_object => "value is not an object",
            .not_iterable => "value is not iterable",
            .not_async_iterable => "value is not async iterable",
            .cannot_read_property => "cannot read property",
            .cannot_set_property => "cannot set property",
            .cannot_delete_property => "cannot delete property",
            .cannot_define_property => "cannot define property",
            .cannot_redefine_property => "cannot redefine property",
            .cannot_extend_object => "cannot add property, object is not extensible",
            .cannot_convert_to_primitive => "cannot convert object to primitive value",
            .cannot_convert_to_string => "cannot convert value to string",
            .cannot_convert_to_number => "cannot convert value to number",
            .cannot_convert_to_bigint => "cannot convert value to bigint",
            .cannot_convert_to_object => "cannot convert value to object",
            .invalid_argument => "invalid argument",
            .null_or_undefined => "cannot access property of null or undefined",
            .invalid_this => "invalid this binding",
            .missing_property => "missing required property",
            .incompatible_types => "incompatible types",
        };
    }
};

pub fn make(message: []const u8) TypeError {
    return TypeError.init(message);
}

pub fn fromKind(kind: Kind) TypeError {
    return TypeError.init(kind.message());
}

pub fn notCallable() TypeError {
    return TypeError.init(Kind.not_callable.message());
}

pub fn notConstructable() TypeError {
    return TypeError.init(Kind.not_constructable.message());
}

pub fn notObject() TypeError {
    return TypeError.init(Kind.not_object.message());
}

pub fn notIterable() TypeError {
    return TypeError.init(Kind.not_iterable.message());
}

pub fn notAsyncIterable() TypeError {
    return TypeError.init(Kind.not_async_iterable.message());
}

pub fn nullOrUndefined() TypeError {
    return TypeError.init(Kind.null_or_undefined.message());
}

pub fn invalidThis() TypeError {
    return TypeError.init(Kind.invalid_this.message());
}

pub fn cannotReadProperty(name: []const u8) TypeError {
    _ = name;
    return TypeError.init(Kind.cannot_read_property.message());
}

pub fn cannotSetProperty(name: []const u8) TypeError {
    _ = name;
    return TypeError.init(Kind.cannot_set_property.message());
}

pub fn cannotConvertToString() TypeError {
    return TypeError.init(Kind.cannot_convert_to_string.message());
}

pub fn cannotConvertToNumber() TypeError {
    return TypeError.init(Kind.cannot_convert_to_number.message());
}

pub fn cannotConvertToBigInt() TypeError {
    return TypeError.init(Kind.cannot_convert_to_bigint.message());
}

pub fn cannotConvertToObject() TypeError {
    return TypeError.init(Kind.cannot_convert_to_object.message());
}

test "init sets message" {
    const t = TypeError.init("bad thing");
    try std.testing.expectEqualStrings("bad thing", t.message);
}

test "withOperation sets both fields" {
    const t = TypeError.withOperation("bad", "add");
    try std.testing.expectEqualStrings("bad", t.message);
    try std.testing.expectEqualStrings("add", t.operation.?);
}

test "name returns TypeError" {
    const t = TypeError.init("x");
    try std.testing.expectEqualStrings("TypeError", t.name());
}

test "toError returns error.TypeError" {
    const t = TypeError.init("x");
    try std.testing.expectEqual(errors.Error.TypeError, t.toError());
}

test "make equals init" {
    const a = make("msg");
    const b = TypeError.init("msg");
    try std.testing.expectEqualStrings(a.message, b.message);
}

test "fromKind uses kind message" {
    const t = fromKind(.not_callable);
    try std.testing.expectEqualStrings("value is not a function", t.message);
}

test "convenience constructors" {
    try std.testing.expectEqualStrings("value is not a function", notCallable().message);
    try std.testing.expectEqualStrings("value is not a constructor", notConstructable().message);
    try std.testing.expectEqualStrings("value is not an object", notObject().message);
    try std.testing.expectEqualStrings("value is not iterable", notIterable().message);
    try std.testing.expectEqualStrings("value is not async iterable", notAsyncIterable().message);
}

test "nullOrUndefined and invalidThis" {
    try std.testing.expectEqualStrings("cannot access property of null or undefined", nullOrUndefined().message);
    try std.testing.expectEqualStrings("invalid this binding", invalidThis().message);
}

test "cannotReadProperty and cannotSetProperty" {
    try std.testing.expectEqualStrings("cannot read property", cannotReadProperty("x").message);
    try std.testing.expectEqualStrings("cannot set property", cannotSetProperty("x").message);
}

test "conversion constructors" {
    try std.testing.expectEqualStrings("cannot convert value to string", cannotConvertToString().message);
    try std.testing.expectEqualStrings("cannot convert value to number", cannotConvertToNumber().message);
    try std.testing.expectEqualStrings("cannot convert value to bigint", cannotConvertToBigInt().message);
    try std.testing.expectEqualStrings("cannot convert value to object", cannotConvertToObject().message);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("value is not a function", Kind.not_callable.message());
    try std.testing.expectEqualStrings("invalid argument", Kind.invalid_argument.message());
}
