const std = @import("std");
const ast = @import("ast.zig");

pub const Position = ast.Position;

pub const ParseErrorCode = enum(u8) {
    unexpected_token,
    unexpected_eof,
    invalid_identifier,
    invalid_number,
    invalid_string,
    invalid_regex,
    invalid_template,
    invalid_escape,
    unterminated_string,
    unterminated_template,
    unterminated_comment,
    unterminated_regex,
    duplicate_parameter,
    duplicate_property,
    duplicate_lexical,
    strict_reserved_word,
    strict_with,
    strict_delete,
    strict_octal,
    strict_duplicate_param,
    strict_function_name,
    invalid_assignment_target,
    invalid_destructuring,
    invalid_rest_parameter,
    invalid_default_param,
    invalid_return,
    invalid_break,
    invalid_continue,
    invalid_yield,
    invalid_await,
    invalid_super,
    invalid_new_target,
    invalid_import,
    invalid_export,
    invalid_label,
    duplicate_label,
    invalid_class,
    invalid_constructor,
    invalid_getter_setter,
    invalid_method,
    invalid_private_name,
    invalid_arrow_params,
    invalid_optional_chain,
    invalid_nullish_mix,
    invalid_exponentiation,
    invalid_async,
    invalid_generator,
    invalid_for_in_init,
    invalid_for_of_init,
    invalid_await_in_params,
    reserved_word,
    unexpected_reserved_word,
    illegal_character,
    mixed_logical_operators,
    parse_depth_exceeded,

    pub fn toString(self: ParseErrorCode) []const u8 {
        return @tagName(self);
    }

    pub fn description(self: ParseErrorCode) []const u8 {
        return switch (self) {
            .unexpected_token => "unexpected token",
            .unexpected_eof => "unexpected end of input",
            .invalid_identifier => "invalid identifier",
            .invalid_number => "invalid numeric literal",
            .invalid_string => "invalid string literal",
            .invalid_regex => "invalid regular expression",
            .invalid_template => "invalid template literal",
            .invalid_escape => "invalid escape sequence",
            .unterminated_string => "unterminated string literal",
            .unterminated_template => "unterminated template literal",
            .unterminated_comment => "unterminated comment",
            .unterminated_regex => "unterminated regular expression",
            .duplicate_parameter => "duplicate parameter name",
            .duplicate_property => "duplicate property name",
            .duplicate_lexical => "identifier has already been declared",
            .strict_reserved_word => "reserved word in strict mode",
            .strict_with => "with statement not allowed in strict mode",
            .strict_delete => "delete of unqualified identifier in strict mode",
            .strict_octal => "octal literal in strict mode",
            .strict_duplicate_param => "duplicate parameter in strict mode",
            .strict_function_name => "invalid function name in strict mode",
            .invalid_assignment_target => "invalid assignment target",
            .invalid_destructuring => "invalid destructuring pattern",
            .invalid_rest_parameter => "invalid rest parameter",
            .invalid_default_param => "invalid default parameter",
            .invalid_return => "return not allowed outside function",
            .invalid_break => "break not allowed outside loop or switch",
            .invalid_continue => "continue not allowed outside loop",
            .invalid_yield => "yield not allowed outside generator",
            .invalid_await => "await not allowed outside async function",
            .invalid_super => "super not allowed in this context",
            .invalid_new_target => "new.target not allowed in this context",
            .invalid_import => "invalid import declaration",
            .invalid_export => "invalid export declaration",
            .invalid_label => "invalid label",
            .duplicate_label => "duplicate label",
            .invalid_class => "invalid class",
            .invalid_constructor => "invalid constructor",
            .invalid_getter_setter => "invalid getter or setter",
            .invalid_method => "invalid method",
            .invalid_private_name => "invalid private name",
            .invalid_arrow_params => "invalid arrow function parameters",
            .invalid_optional_chain => "invalid optional chain",
            .invalid_nullish_mix => "cannot mix nullish coalescing with logical operators",
            .invalid_exponentiation => "unary expression not allowed before exponentiation",
            .invalid_async => "invalid async",
            .invalid_generator => "invalid generator",
            .invalid_for_in_init => "invalid for-in initialization",
            .invalid_for_of_init => "invalid for-of initialization",
            .invalid_await_in_params => "await not allowed in parameters",
            .reserved_word => "reserved word used as identifier",
            .unexpected_reserved_word => "unexpected reserved word",
            .illegal_character => "illegal character",
            .mixed_logical_operators => "cannot mix && and || without parentheses",
            .parse_depth_exceeded => "parse depth exceeded",
        };
    }
};

pub const ParseError = struct {
    code: ParseErrorCode,
    message: []const u8,
    position: Position,
    token_text: ?[]const u8 = null,

    pub fn init(code: ParseErrorCode, position: Position) ParseError {
        return .{
            .code = code,
            .message = code.description(),
            .position = position,
        };
    }

    pub fn initWithMessage(code: ParseErrorCode, position: Position, message: []const u8) ParseError {
        return .{
            .code = code,
            .message = message,
            .position = position,
        };
    }

    pub fn withToken(self: ParseError, token: []const u8) ParseError {
        var e = self;
        e.token_text = token;
        return e;
    }

    pub fn getCode(self: ParseError) ParseErrorCode {
        return self.code;
    }

    pub fn getMessage(self: ParseError) []const u8 {
        return self.message;
    }

    pub fn getPosition(self: ParseError) Position {
        return self.position;
    }

    pub fn line(self: ParseError) u32 {
        return self.position.line;
    }

    pub fn column(self: ParseError) u32 {
        return self.position.column;
    }

    pub fn offset(self: ParseError) u32 {
        return self.position.offset;
    }
};

pub const ErrorList = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(ParseError),
    max_errors: usize,

    pub fn init(allocator: std.mem.Allocator) ErrorList {
        return .{
            .allocator = allocator,
            .errors = .empty,
            .max_errors = 100,
        };
    }

    pub fn deinit(self: *ErrorList) void {
        self.errors.deinit(self.allocator);
    }

    pub fn add(self: *ErrorList, err: ParseError) !void {
        if (self.errors.items.len >= self.max_errors) return;
        try self.errors.append(self.allocator, err);
    }

    pub fn count(self: ErrorList) usize {
        return self.errors.items.len;
    }

    pub fn isEmpty(self: ErrorList) bool {
        return self.errors.items.len == 0;
    }

    pub fn hasErrors(self: ErrorList) bool {
        return self.errors.items.len > 0;
    }

    pub fn clear(self: *ErrorList) void {
        self.errors.clearRetainingCapacity();
    }

    pub fn first(self: ErrorList) ?ParseError {
        if (self.errors.items.len == 0) return null;
        return self.errors.items[0];
    }

    pub fn last(self: ErrorList) ?ParseError {
        if (self.errors.items.len == 0) return null;
        return self.errors.items[self.errors.items.len - 1];
    }

    pub fn get(self: ErrorList, index: usize) ?ParseError {
        if (index >= self.errors.items.len) return null;
        return self.errors.items[index];
    }

    pub fn isFull(self: ErrorList) bool {
        return self.errors.items.len >= self.max_errors;
    }
};

pub const RecoveryMode = enum(u8) {
    none,
    statement,
    expression,
    declaration,
    block,
    member,

    pub fn toString(self: RecoveryMode) []const u8 {
        return @tagName(self);
    }
};

pub fn isStrictError(code: ParseErrorCode) bool {
    return switch (code) {
        .strict_reserved_word,
        .strict_with,
        .strict_delete,
        .strict_octal,
        .strict_duplicate_param,
        .strict_function_name,
        => true,
        else => false,
    };
}

pub fn isRecoverable(code: ParseErrorCode) bool {
    return switch (code) {
        .unexpected_token,
        .invalid_assignment_target,
        .duplicate_property,
        .duplicate_parameter,
        .unexpected_reserved_word,
        => true,
        else => false,
    };
}

pub fn makePosition(offset: u32, line: u32, column: u32) Position {
    return .{ .offset = offset, .line = line, .column = column };
}

test "ParseErrorCode toString" {
    try std.testing.expectEqualStrings("unexpected_token", ParseErrorCode.unexpected_token.toString());
    try std.testing.expectEqualStrings("invalid_identifier", ParseErrorCode.invalid_identifier.toString());
}

test "ParseErrorCode description non-empty" {
    try std.testing.expect(ParseErrorCode.unexpected_token.description().len > 0);
    try std.testing.expect(ParseErrorCode.invalid_number.description().len > 0);
}

test "ParseError init" {
    const p = makePosition(10, 2, 5);
    const e = ParseError.init(.unexpected_token, p);
    try std.testing.expectEqual(ParseErrorCode.unexpected_token, e.getCode());
    try std.testing.expectEqual(@as(u32, 2), e.line());
    try std.testing.expectEqual(@as(u32, 5), e.column());
    try std.testing.expectEqual(@as(u32, 10), e.offset());
}

test "ParseError initWithMessage" {
    const p = makePosition(0, 1, 1);
    const e = ParseError.initWithMessage(.invalid_identifier, p, "custom message");
    try std.testing.expectEqualStrings("custom message", e.getMessage());
}

test "ParseError withToken" {
    const p = makePosition(0, 1, 1);
    const e = ParseError.init(.unexpected_token, p).withToken("+");
    try std.testing.expectEqualStrings("+", e.token_text.?);
}

test "ErrorList init" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 0), list.count());
    try std.testing.expect(list.isEmpty());
    try std.testing.expect(!list.hasErrors());
}

test "ErrorList add" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(ParseError.init(.unexpected_token, makePosition(0, 1, 1)));
    try std.testing.expectEqual(@as(usize, 1), list.count());
    try std.testing.expect(list.hasErrors());
}

test "ErrorList first and last" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(ParseError.init(.unexpected_token, makePosition(0, 1, 1)));
    try list.add(ParseError.init(.invalid_number, makePosition(5, 1, 6)));

    try std.testing.expectEqual(ParseErrorCode.unexpected_token, list.first().?.code);
    try std.testing.expectEqual(ParseErrorCode.invalid_number, list.last().?.code);
}

test "ErrorList clear" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(ParseError.init(.unexpected_token, makePosition(0, 1, 1)));
    list.clear();
    try std.testing.expectEqual(@as(usize, 0), list.count());
}

test "ErrorList max limit" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();
    list.max_errors = 3;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try list.add(ParseError.init(.unexpected_token, makePosition(0, 1, 1)));
    }
    try std.testing.expectEqual(@as(usize, 3), list.count());
    try std.testing.expect(list.isFull());
}

test "ErrorList get" {
    var list = ErrorList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(ParseError.init(.unexpected_token, makePosition(0, 1, 1)));
    try std.testing.expectEqual(ParseErrorCode.unexpected_token, list.get(0).?.code);
    try std.testing.expectEqual(@as(?ParseError, null), list.get(5));
}

test "RecoveryMode toString" {
    try std.testing.expectEqualStrings("statement", RecoveryMode.statement.toString());
    try std.testing.expectEqualStrings("expression", RecoveryMode.expression.toString());
}

test "isStrictError" {
    try std.testing.expect(isStrictError(.strict_with));
    try std.testing.expect(isStrictError(.strict_octal));
    try std.testing.expect(!isStrictError(.unexpected_token));
}

test "isRecoverable" {
    try std.testing.expect(isRecoverable(.unexpected_token));
    try std.testing.expect(isRecoverable(.duplicate_property));
    try std.testing.expect(!isRecoverable(.unterminated_string));
}
