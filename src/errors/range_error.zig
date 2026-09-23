const std = @import("std");
const errors = @import("error.zig");

pub const RangeError = struct {
    message: []const u8,
    value: ?i64 = null,
    min: ?i64 = null,
    max: ?i64 = null,

    pub fn init(message: []const u8) RangeError {
        return .{ .message = message };
    }

    pub fn withValue(message: []const u8, value: i64) RangeError {
        return .{ .message = message, .value = value };
    }

    pub fn withBounds(message: []const u8, value: i64, min: i64, max: i64) RangeError {
        return .{ .message = message, .value = value, .min = min, .max = max };
    }

    pub fn name(self: RangeError) []const u8 {
        _ = self;
        return "RangeError";
    }

    pub fn format(
        self: RangeError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("RangeError: {s}", .{self.message});
        if (self.value) |v| {
            try writer.print(" (value: {d}", .{v});
            if (self.min) |mn| {
                if (self.max) |mx| {
                    try writer.print(", range: [{d}, {d}]", .{ mn, mx });
                }
            }
            try writer.writeAll(")");
        }
    }

    pub fn toError(self: RangeError) errors.Error {
        _ = self;
        return error.RangeError;
    }
};

pub const Kind = enum {
    invalid_array_length,
    invalid_buffer_length,
    invalid_string_length,
    invalid_index,
    negative_index,
    out_of_bounds,
    invalid_radix,
    invalid_precision,
    invalid_date,
    invalid_time_value,
    invalid_repeat_count,
    invalid_code_point,
    invalid_arguments_length,
    invalid_stack_size,
    invalid_heap_size,
    invalid_call_depth,
    invalid_regex_backtrack,
    number_out_of_range,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .invalid_array_length => "invalid array length",
            .invalid_buffer_length => "invalid buffer length",
            .invalid_string_length => "invalid string length",
            .invalid_index => "invalid index",
            .negative_index => "index cannot be negative",
            .out_of_bounds => "index out of bounds",
            .invalid_radix => "radix must be between 2 and 36",
            .invalid_precision => "precision out of range",
            .invalid_date => "invalid date",
            .invalid_time_value => "invalid time value",
            .invalid_repeat_count => "repeat count must be non-negative",
            .invalid_code_point => "invalid code point",
            .invalid_arguments_length => "invalid arguments length",
            .invalid_stack_size => "invalid stack size",
            .invalid_heap_size => "invalid heap size",
            .invalid_call_depth => "invalid call depth",
            .invalid_regex_backtrack => "regex backtrack limit exceeded",
            .number_out_of_range => "number out of range",
        };
    }
};

pub fn make(message: []const u8) RangeError {
    return RangeError.init(message);
}

pub fn fromKind(kind: Kind) RangeError {
    return RangeError.init(kind.message());
}

pub fn invalidArrayLength() RangeError {
    return RangeError.init(Kind.invalid_array_length.message());
}

pub fn invalidBufferLength() RangeError {
    return RangeError.init(Kind.invalid_buffer_length.message());
}

pub fn invalidStringLength() RangeError {
    return RangeError.init(Kind.invalid_string_length.message());
}

pub fn invalidIndex(index: i64) RangeError {
    return RangeError.withValue(Kind.invalid_index.message(), index);
}

pub fn negativeIndex(index: i64) RangeError {
    return RangeError.withValue(Kind.negative_index.message(), index);
}

pub fn outOfBounds(index: i64, len: i64) RangeError {
    return RangeError.withBounds(Kind.out_of_bounds.message(), index, 0, len - 1);
}

pub fn invalidRadix(radix: i64) RangeError {
    return RangeError.withBounds(Kind.invalid_radix.message(), radix, 2, 36);
}

pub fn invalidPrecision(precision: i64) RangeError {
    return RangeError.withBounds(Kind.invalid_precision.message(), precision, 0, 100);
}

pub fn invalidDate() RangeError {
    return RangeError.init(Kind.invalid_date.message());
}

pub fn invalidTimeValue() RangeError {
    return RangeError.init(Kind.invalid_time_value.message());
}

pub fn invalidRepeatCount(count: i64) RangeError {
    return RangeError.withValue(Kind.invalid_repeat_count.message(), count);
}

pub fn invalidCodePoint(cp: i64) RangeError {
    return RangeError.withBounds(Kind.invalid_code_point.message(), cp, 0, 0x10FFFF);
}

pub fn numberOutOfRange(value: i64) RangeError {
    return RangeError.withValue(Kind.number_out_of_range.message(), value);
}

test "init sets message" {
    const r = RangeError.init("bad range");
    try std.testing.expectEqualStrings("bad range", r.message);
}

test "withValue sets value" {
    const r = RangeError.withValue("oob", 42);
    try std.testing.expectEqual(@as(i64, 42), r.value.?);
}

test "withBounds sets value min max" {
    const r = RangeError.withBounds("oob", 100, 0, 10);
    try std.testing.expectEqual(@as(i64, 100), r.value.?);
    try std.testing.expectEqual(@as(i64, 0), r.min.?);
    try std.testing.expectEqual(@as(i64, 10), r.max.?);
}

test "name returns RangeError" {
    const r = RangeError.init("x");
    try std.testing.expectEqualStrings("RangeError", r.name());
}

test "toError returns error.RangeError" {
    const r = RangeError.init("x");
    try std.testing.expectEqual(errors.Error.RangeError, r.toError());
}

test "fromKind uses kind message" {
    const r = fromKind(.out_of_bounds);
    try std.testing.expectEqualStrings("index out of bounds", r.message);
}

test "length errors" {
    try std.testing.expectEqualStrings("invalid array length", invalidArrayLength().message);
    try std.testing.expectEqualStrings("invalid buffer length", invalidBufferLength().message);
    try std.testing.expectEqualStrings("invalid string length", invalidStringLength().message);
}

test "index errors carry values" {
    const a = invalidIndex(500);
    try std.testing.expectEqual(@as(i64, 500), a.value.?);
    const b = negativeIndex(-1);
    try std.testing.expectEqual(@as(i64, -1), b.value.?);
}

test "outOfBounds sets range" {
    const r = outOfBounds(15, 10);
    try std.testing.expectEqual(@as(i64, 15), r.value.?);
    try std.testing.expectEqual(@as(i64, 0), r.min.?);
    try std.testing.expectEqual(@as(i64, 9), r.max.?);
}

test "invalidRadix range" {
    const r = invalidRadix(1);
    try std.testing.expectEqual(@as(i64, 2), r.min.?);
    try std.testing.expectEqual(@as(i64, 36), r.max.?);
}

test "invalidPrecision range" {
    const r = invalidPrecision(200);
    try std.testing.expectEqual(@as(i64, 0), r.min.?);
    try std.testing.expectEqual(@as(i64, 100), r.max.?);
}

test "date errors" {
    try std.testing.expectEqualStrings("invalid date", invalidDate().message);
    try std.testing.expectEqualStrings("invalid time value", invalidTimeValue().message);
}

test "repeat count" {
    const r = invalidRepeatCount(-3);
    try std.testing.expectEqual(@as(i64, -3), r.value.?);
}

test "code point range" {
    const r = invalidCodePoint(0x110000);
    try std.testing.expectEqual(@as(i64, 0), r.min.?);
    try std.testing.expectEqual(@as(i64, 0x10FFFF), r.max.?);
}

test "numberOutOfRange carries value" {
    const r = numberOutOfRange(999999);
    try std.testing.expectEqual(@as(i64, 999999), r.value.?);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("invalid array length", Kind.invalid_array_length.message());
    try std.testing.expectEqualStrings("radix must be between 2 and 36", Kind.invalid_radix.message());
}
