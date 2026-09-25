const std = @import("std");
const token = @import("../lexer/token.zig");
const ast = @import("ast.zig");
const prec = @import("precedence.zig");
const err = @import("error.zig");

pub const Kind = token.Kind;
pub const Token = token.Token;
pub const NodeId = ast.NodeId;
pub const NO_NODE = ast.NO_NODE;
pub const NodeTag = ast.NodeTag;
pub const Data = ast.Data;
pub const Span = ast.Span;
pub const Position = ast.Position;
pub const Ast = ast.Ast;
pub const ParseError = err.ParseError;
pub const ParseErrorCode = err.ParseErrorCode;

pub const ExpressionContext = struct {
    in_async: bool = false,
    in_generator: bool = false,
    in_function: bool = false,
    allow_in: bool = true,
    allow_yield: bool = false,
    allow_await: bool = false,
    allow_super: bool = false,
    allow_super_call: bool = false,
    allow_super_property: bool = false,
    allow_new_target: bool = false,
    allow_optional_chain: bool = true,
    strict: bool = false,
    no_call: bool = false,
    no_brace: bool = false,

    pub fn forFunction() ExpressionContext {
        return .{
            .in_function = true,
            .allow_super = true,
            .allow_super_property = true,
            .allow_new_target = true,
        };
    }

    pub fn forArrow() ExpressionContext {
        return .{
            .in_function = true,
            .allow_super = true,
            .allow_super_property = true,
        };
    }

    pub fn forGenerator() ExpressionContext {
        var c = forFunction();
        c.in_generator = true;
        c.allow_yield = true;
        return c;
    }

    pub fn forAsync() ExpressionContext {
        var c = forFunction();
        c.in_async = true;
        c.allow_await = true;
        return c;
    }

    pub fn forMethod() ExpressionContext {
        var c = forFunction();
        c.allow_super_call = true;
        c.allow_super_property = true;
        return c;
    }
};

pub const ParseContext = struct {
    ast: *Ast,
    errors: *err.ErrorList,
    strict: bool = false,

    pub fn init(ast_ptr: *Ast, errors_ptr: *err.ErrorList) ParseContext {
        return .{
            .ast = ast_ptr,
            .errors = errors_ptr,
            .strict = false,
        };
    }

    pub fn setStrict(self: *ParseContext, strict: bool) void {
        self.strict = strict;
    }

    pub fn report(self: *ParseContext, code: ParseErrorCode, pos: Position) !void {
        try self.errors.add(ParseError.init(code, pos));
    }

    pub fn reportToken(self: *ParseContext, code: ParseErrorCode, pos: Position, text: []const u8) !void {
        try self.errors.add(ParseError.init(code, pos).withToken(text));
    }
};

pub const ExpressionParser = struct {
    ctx: *ParseContext,
    tokens: []const Token,
    pos: usize,

    pub fn init(ctx: *ParseContext, tokens: []const Token) ExpressionParser {
        return .{
            .ctx = ctx,
            .tokens = tokens,
            .pos = 0,
        };
    }

    pub fn current(self: ExpressionParser) Token {
        if (self.pos >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }
        return self.tokens[self.pos];
    }

    pub fn peek(self: ExpressionParser, offset: usize) Token {
        const idx = self.pos + offset;
        if (idx >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }
        return self.tokens[idx];
    }

    pub fn advance(self: *ExpressionParser) Token {
        const t = self.current();
        if (self.pos < self.tokens.len - 1) {
            self.pos += 1;
        }
        return t;
    }

    pub fn expect(self: *ExpressionParser, kind: Kind) !Token {
        const t = self.current();
        if (t.kind != kind) {
            try self.ctx.report(.unexpected_token, makePos(t));
            return error.UnexpectedToken;
        }
        return self.advance();
    }

    pub fn match(self: *ExpressionParser, kind: Kind) bool {
        if (self.current().kind == kind) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    pub fn atEnd(self: ExpressionParser) bool {
        return self.current().kind == .eof;
    }

    pub fn nodeSpan(self: ExpressionParser, start: Token, end: Token) Span {
        _ = self;
        return .{
            .start = makePos(start),
            .end = makePos(end),
        };
    }

    pub fn addNode(self: *ExpressionParser, tag: NodeTag, span: Span, data: Data) !NodeId {
        return try self.ctx.ast.add(tag, span, data);
    }
};

pub fn makePos(t: Token) Position {
    return .{
        .offset = t.offset,
        .line = t.line,
        .column = t.column,
    };
}

pub fn isLiteralKind(kind: Kind) bool {
    return switch (kind) {
        .number,
        .string,
        .bigint,
        .regex,
        .template_string,
        .template_head,
        .keyword_true,
        .keyword_false,
        .keyword_null,
        => true,
        else => false,
    };
}

pub fn isPrimaryStart(kind: Kind) bool {
    return switch (kind) {
        .identifier,
        .private_identifier,
        .keyword_this,
        .keyword_super,
        .keyword_null,
        .keyword_true,
        .keyword_false,
        .keyword_new,
        .keyword_function,
        .keyword_class,
        .keyword_import,
        .number,
        .string,
        .bigint,
        .regex,
        .template_string,
        .template_head,
        .punct_lparen,
        .punct_lbracket,
        .punct_lbrace,
        .keyword_typeof,
        .keyword_void,
        .keyword_delete,
        .op_not,
        .op_bit_not,
        .op_add,
        .op_sub,
        .op_increment,
        .op_decrement,
        .keyword_await,
        .keyword_yield,
        => true,
        else => false,
    };
}

pub fn isAssignmentTarget(tag: NodeTag) bool {
    return switch (tag) {
        .identifier,
        .member_expression,
        .optional_member_expression,
        .array_literal,
        .object_literal,
        .this_expression,
        => true,
        else => false,
    };
}

test "ExpressionContext forFunction" {
    const c = ExpressionContext.forFunction();
    try std.testing.expect(c.in_function);
    try std.testing.expect(c.allow_super);
    try std.testing.expect(c.allow_new_target);
    try std.testing.expect(!c.in_async);
}

test "ExpressionContext forArrow" {
    const c = ExpressionContext.forArrow();
    try std.testing.expect(c.in_function);
    try std.testing.expect(!c.allow_new_target);
}

test "ExpressionContext forGenerator" {
    const c = ExpressionContext.forGenerator();
    try std.testing.expect(c.in_generator);
    try std.testing.expect(c.allow_yield);
}

test "ExpressionContext forAsync" {
    const c = ExpressionContext.forAsync();
    try std.testing.expect(c.in_async);
    try std.testing.expect(c.allow_await);
}

test "ExpressionContext forMethod" {
    const c = ExpressionContext.forMethod();
    try std.testing.expect(c.allow_super_call);
    try std.testing.expect(c.allow_super_property);
}

test "ParseContext init" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();

    var ctx = ParseContext.init(&a, &e);
    try std.testing.expect(!ctx.strict);
    ctx.setStrict(true);
    try std.testing.expect(ctx.strict);
}

test "ParseContext report" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();

    var ctx = ParseContext.init(&a, &e);
    try ctx.report(.unexpected_token, .{ .offset = 0, .line = 1, .column = 1 });
    try std.testing.expectEqual(@as(usize, 1), e.count());
}

test "ExpressionParser init" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();
    var ctx = ParseContext.init(&a, &e);

    const toks = [_]Token{
        .{ .kind = .number, .text = "1", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };

    var p = ExpressionParser.init(&ctx, &toks);
    try std.testing.expectEqual(Kind.number, p.current().kind);
}

test "ExpressionParser advance" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();
    var ctx = ParseContext.init(&a, &e);

    const toks = [_]Token{
        .{ .kind = .number, .text = "1", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };

    var p = ExpressionParser.init(&ctx, &toks);
    _ = p.advance();
    try std.testing.expectEqual(Kind.op_add, p.current().kind);
}

test "ExpressionParser match" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();
    var ctx = ParseContext.init(&a, &e);

    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };

    var p = ExpressionParser.init(&ctx, &toks);
    try std.testing.expect(p.match(.op_add));
    try std.testing.expect(!p.match(.op_add));
}

test "ExpressionParser peek" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = err.ErrorList.init(std.testing.allocator);
    defer e.deinit();
    var ctx = ParseContext.init(&a, &e);

    const toks = [_]Token{
        .{ .kind = .number, .text = "1", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };

    const p = ExpressionParser.init(&ctx, &toks);
    try std.testing.expectEqual(Kind.op_add, p.peek(1).kind);
}

test "isLiteralKind" {
    try std.testing.expect(isLiteralKind(.number));
    try std.testing.expect(isLiteralKind(.string));
    try std.testing.expect(isLiteralKind(.keyword_null));
    try std.testing.expect(!isLiteralKind(.identifier));
}

test "isPrimaryStart" {
    try std.testing.expect(isPrimaryStart(.identifier));
    try std.testing.expect(isPrimaryStart(.number));
    try std.testing.expect(isPrimaryStart(.punct_lparen));
    try std.testing.expect(!isPrimaryStart(.op_add_assign));
}

test "isAssignmentTarget" {
    try std.testing.expect(isAssignmentTarget(.identifier));
    try std.testing.expect(isAssignmentTarget(.member_expression));
    try std.testing.expect(!isAssignmentTarget(.number_literal));
}

test "makePos" {
    const t = Token{ .kind = .identifier, .text = "x", .line = 3, .column = 7, .offset = 20 };
    const p = makePos(t);
    try std.testing.expectEqual(@as(u32, 3), p.line);
    try std.testing.expectEqual(@as(u32, 7), p.column);
    try std.testing.expectEqual(@as(u32, 20), p.offset);
}
