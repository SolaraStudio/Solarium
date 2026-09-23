const std = @import("std");
const errors = @import("error.zig");

pub const SyntaxError = struct {
    message: []const u8,
    line: ?u32 = null,
    column: ?u32 = null,
    offset: ?u32 = null,

    pub fn init(message: []const u8) SyntaxError {
        return .{ .message = message };
    }

    pub fn at(message: []const u8, line: u32, column: u32) SyntaxError {
        return .{ .message = message, .line = line, .column = column };
    }

    pub fn atOffset(message: []const u8, offset: u32, line: u32, column: u32) SyntaxError {
        return .{
            .message = message,
            .line = line,
            .column = column,
            .offset = offset,
        };
    }

    pub fn name(self: SyntaxError) []const u8 {
        _ = self;
        return "SyntaxError";
    }

    pub fn format(
        self: SyntaxError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("SyntaxError: {s}", .{self.message});
        if (self.line) |line| {
            if (self.column) |col| {
                try writer.print(" at line {d}, column {d}", .{ line, col });
            } else {
                try writer.print(" at line {d}", .{line});
            }
        }
    }

    pub fn toError(self: SyntaxError) errors.Error {
        _ = self;
        return error.SyntaxError;
    }
};

pub const Kind = enum {
    unexpected_token,
    unexpected_end_of_input,
    invalid_escape,
    invalid_numeric,
    invalid_string,
    invalid_regex,
    invalid_template,
    invalid_identifier,
    duplicate_parameter,
    strict_violation,
    reserved_word,
    invalid_assignment_target,
    invalid_destructuring,
    invalid_lhs,
    invalid_use_strict,
    invalid_return,
    invalid_break,
    invalid_continue,
    invalid_label,
    invalid_yield,
    invalid_await,
    invalid_import,
    invalid_export,
    invalid_class,
    invalid_getter_setter,
    invalid_super,
    invalid_new_target,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .unexpected_token => "unexpected token",
            .unexpected_end_of_input => "unexpected end of input",
            .invalid_escape => "invalid escape sequence",
            .invalid_numeric => "invalid numeric literal",
            .invalid_string => "invalid string literal",
            .invalid_regex => "invalid regular expression",
            .invalid_template => "invalid template literal",
            .invalid_identifier => "invalid identifier",
            .duplicate_parameter => "duplicate parameter name",
            .strict_violation => "strict mode violation",
            .reserved_word => "reserved word used as identifier",
            .invalid_assignment_target => "invalid assignment target",
            .invalid_destructuring => "invalid destructuring pattern",
            .invalid_lhs => "invalid left-hand side in assignment",
            .invalid_use_strict => "invalid use strict directive",
            .invalid_return => "return not allowed outside function",
            .invalid_break => "break not allowed outside loop or switch",
            .invalid_continue => "continue not allowed outside loop",
            .invalid_label => "invalid or duplicate label",
            .invalid_yield => "yield not allowed outside generator",
            .invalid_await => "await not allowed outside async function",
            .invalid_import => "invalid import declaration",
            .invalid_export => "invalid export declaration",
            .invalid_class => "invalid class declaration",
            .invalid_getter_setter => "invalid getter or setter",
            .invalid_super => "super not allowed in this context",
            .invalid_new_target => "new.target not allowed in this context",
        };
    }
};

pub fn make(message: []const u8) SyntaxError {
    return SyntaxError.init(message);
}

pub fn fromKind(kind: Kind) SyntaxError {
    return SyntaxError.init(kind.message());
}

pub fn unexpectedToken(token: []const u8) SyntaxError {
    _ = token;
    return SyntaxError.init(Kind.unexpected_token.message());
}

pub fn unexpectedEndOfInput() SyntaxError {
    return SyntaxError.init(Kind.unexpected_end_of_input.message());
}

pub fn invalidEscape() SyntaxError {
    return SyntaxError.init(Kind.invalid_escape.message());
}

pub fn invalidNumeric() SyntaxError {
    return SyntaxError.init(Kind.invalid_numeric.message());
}

pub fn invalidString() SyntaxError {
    return SyntaxError.init(Kind.invalid_string.message());
}

pub fn invalidRegex() SyntaxError {
    return SyntaxError.init(Kind.invalid_regex.message());
}

pub fn invalidIdentifier() SyntaxError {
    return SyntaxError.init(Kind.invalid_identifier.message());
}

pub fn strictViolation() SyntaxError {
    return SyntaxError.init(Kind.strict_violation.message());
}

pub fn reservedWord() SyntaxError {
    return SyntaxError.init(Kind.reserved_word.message());
}

pub fn invalidAssignmentTarget() SyntaxError {
    return SyntaxError.init(Kind.invalid_assignment_target.message());
}

pub fn invalidReturn() SyntaxError {
    return SyntaxError.init(Kind.invalid_return.message());
}

pub fn invalidBreak() SyntaxError {
    return SyntaxError.init(Kind.invalid_break.message());
}

pub fn invalidContinue() SyntaxError {
    return SyntaxError.init(Kind.invalid_continue.message());
}

pub fn invalidYield() SyntaxError {
    return SyntaxError.init(Kind.invalid_yield.message());
}

pub fn invalidAwait() SyntaxError {
    return SyntaxError.init(Kind.invalid_await.message());
}

test "init sets message" {
    const s = SyntaxError.init("bad syntax");
    try std.testing.expectEqualStrings("bad syntax", s.message);
}

test "at sets line and column" {
    const s = SyntaxError.at("bad", 3, 15);
    try std.testing.expectEqual(@as(u32, 3), s.line.?);
    try std.testing.expectEqual(@as(u32, 15), s.column.?);
    try std.testing.expect(s.offset == null);
}

test "atOffset sets all fields" {
    const s = SyntaxError.atOffset("bad", 42, 3, 15);
    try std.testing.expectEqual(@as(u32, 42), s.offset.?);
    try std.testing.expectEqual(@as(u32, 3), s.line.?);
    try std.testing.expectEqual(@as(u32, 15), s.column.?);
}

test "name returns SyntaxError" {
    const s = SyntaxError.init("x");
    try std.testing.expectEqualStrings("SyntaxError", s.name());
}

test "toError returns error.SyntaxError" {
    const s = SyntaxError.init("x");
    try std.testing.expectEqual(errors.Error.SyntaxError, s.toError());
}

test "fromKind uses kind message" {
    const s = fromKind(.unexpected_token);
    try std.testing.expectEqualStrings("unexpected token", s.message);
}

test "convenience constructors part one" {
    try std.testing.expectEqualStrings("unexpected token", unexpectedToken("x").message);
    try std.testing.expectEqualStrings("unexpected end of input", unexpectedEndOfInput().message);
    try std.testing.expectEqualStrings("invalid escape sequence", invalidEscape().message);
    try std.testing.expectEqualStrings("invalid numeric literal", invalidNumeric().message);
}

test "convenience constructors part two" {
    try std.testing.expectEqualStrings("invalid string literal", invalidString().message);
    try std.testing.expectEqualStrings("invalid regular expression", invalidRegex().message);
    try std.testing.expectEqualStrings("invalid identifier", invalidIdentifier().message);
}

test "strict and control flow errors" {
    try std.testing.expectEqualStrings("strict mode violation", strictViolation().message);
    try std.testing.expectEqualStrings("reserved word used as identifier", reservedWord().message);
    try std.testing.expectEqualStrings("invalid assignment target", invalidAssignmentTarget().message);
    try std.testing.expectEqualStrings("return not allowed outside function", invalidReturn().message);
    try std.testing.expectEqualStrings("break not allowed outside loop or switch", invalidBreak().message);
    try std.testing.expectEqualStrings("continue not allowed outside loop", invalidContinue().message);
}

test "generator and async errors" {
    try std.testing.expectEqualStrings("yield not allowed outside generator", invalidYield().message);
    try std.testing.expectEqualStrings("await not allowed outside async function", invalidAwait().message);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("unexpected token", Kind.unexpected_token.message());
    try std.testing.expectEqualStrings("invalid import declaration", Kind.invalid_import.message());
}
