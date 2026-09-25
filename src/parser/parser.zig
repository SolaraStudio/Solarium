const std = @import("std");
const token = @import("../lexer/token.zig");
const ast = @import("ast.zig");
const prec = @import("precedence.zig");
const err = @import("error.zig");
const expr_mod = @import("expression.zig");
const stmt_mod = @import("statement.zig");
const decl_mod = @import("declaration.zig");
const recov = @import("recovery.zig");

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
pub const ErrorList = err.ErrorList;

pub const ParseError_ = error{
    OutOfMemory,
    UnexpectedToken,
    UnexpectedEof,
    TooDeep,
    InvalidAssignment,
    InvalidDeclaration,
};

pub const MAX_DEPTH: u32 = 1000;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    ast: *Ast,
    errors: *ErrorList,
    tokens: []const Token,
    pos: usize,
    depth: u32,
    strict: bool,
    source_type: ast.SourceType,

    pub fn init(
        allocator: std.mem.Allocator,
        ast_ptr: *Ast,
        errors_ptr: *ErrorList,
        tokens: []const Token,
    ) Parser {
        return .{
            .allocator = allocator,
            .ast = ast_ptr,
            .errors = errors_ptr,
            .tokens = tokens,
            .pos = 0,
            .depth = 0,
            .strict = false,
            .source_type = .script,
        };
    }

    pub fn current(self: Parser) Token {
        if (self.pos >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }
        return self.tokens[self.pos];
    }

    pub fn peek(self: Parser, offset: usize) Token {
        const idx = self.pos + offset;
        if (idx >= self.tokens.len) {
            return self.tokens[self.tokens.len - 1];
        }
        return self.tokens[idx];
    }

    pub fn advance(self: *Parser) Token {
        const t = self.current();
        if (self.pos < self.tokens.len - 1) {
            self.pos += 1;
        }
        return t;
    }

    pub fn match(self: *Parser, kind: Kind) bool {
        if (self.current().kind == kind) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    pub fn atEnd(self: Parser) bool {
        return self.current().kind == .eof;
    }

    pub fn expect(self: *Parser, kind: Kind) ParseError_!Token {
        const t = self.current();
        if (t.kind != kind) {
            try self.errors.add(ParseError.init(.unexpected_token, makePos(t)).withToken(t.text));
            return error.UnexpectedToken;
        }
        return self.advance();
    }

    pub fn enter(self: *Parser) ParseError_!void {
        self.depth += 1;
        if (self.depth > MAX_DEPTH) {
            try self.errors.add(ParseError.init(.parse_depth_exceeded, makePos(self.current())));
            return error.TooDeep;
        }
    }

    pub fn leave(self: *Parser) void {
        if (self.depth > 0) self.depth -= 1;
    }

    pub fn spanOf(self: Parser, start: Token, end: Token) Span {
        _ = self;
        return .{ .start = makePos(start), .end = makePos(end) };
    }

    pub fn spanFrom(self: Parser, start: Token) Span {

        const end = if (self.pos > 0) self.tokens[self.pos - 1] else start;
        return .{ .start = makePos(start), .end = makePos(end) };
    }

    pub fn parseProgram(self: *Parser) ParseError_!NodeId {
        const start_tok = self.current();
        var body: std.ArrayList(NodeId) = .empty;
        errdefer body.deinit(self.allocator);

        while (!self.atEnd()) {
            const stmt = self.parseStatement() catch {
                _ = recov.skipToStatementStart(self.tokens, &self.pos);
                continue;
            };
            if (stmt != NO_NODE) {
                try body.append(self.allocator, stmt);
            }
        }

        const body_slice = try body.toOwnedSlice(self.allocator);
        const end_tok = self.current();
        return self.ast.add(.program, self.spanOf(start_tok, end_tok), .{
            .program = .{
                .body = body_slice,
                .strict = self.strict,
                .source_type = self.source_type,
            },
        });
    }

    pub fn parseStatement(self: *Parser) ParseError_!NodeId {
        try self.enter();
        defer self.leave();

        const t = self.current();
        return switch (t.kind) {
            .punct_lbrace => self.parseBlock(),
            .punct_semicolon => self.parseEmpty(),
            .keyword_var, .keyword_let, .keyword_const => self.parseVariableDeclaration(),
            .keyword_if => self.parseIf(),
            .keyword_return => self.parseReturn(),
            .keyword_break => self.parseBreak(),
            .keyword_continue => self.parseContinue(),
            .keyword_function => self.parseFunctionDeclaration(),
            else => self.parseExpressionStatement(),
        };
    }

    pub fn parseBlock(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.punct_lbrace);
        var stmts: std.ArrayList(NodeId) = .empty;
        errdefer stmts.deinit(self.allocator);

        while (!self.atEnd() and self.current().kind != .punct_rbrace) {
            const stmt = self.parseStatement() catch {
                _ = recov.skipToStatementStart(self.tokens, &self.pos);
                continue;
            };
            if (stmt != NO_NODE) {
                try stmts.append(self.allocator, stmt);
            }
        }

        _ = try self.expect(.punct_rbrace);

        const body = try stmts.toOwnedSlice(self.allocator);
        return self.ast.add(.block_statement, self.spanFrom(start_tok), .{
            .block_statement = .{ .body = body },
        });
    }

    pub fn parseEmpty(self: *Parser) ParseError_!NodeId {
        const t = try self.expect(.punct_semicolon);
        return self.ast.add(.empty_statement, self.spanOf(t, t), .{ .empty_statement = {} });
    }

    pub fn parseExpressionStatement(self: *Parser) ParseError_!NodeId {
        const start_tok = self.current();
        const e = try self.parseExpression();
        _ = self.match(.punct_semicolon);

        return self.ast.add(.expression_statement, self.spanFrom(start_tok), .{
            .expression_statement = .{ .expression = e, .directive = null },
        });
    }

    pub fn parseVariableDeclaration(self: *Parser) ParseError_!NodeId {
        const start_tok = self.current();
        const kind_tok = self.advance();
        const vk = decl_mod.toVariableKind(kind_tok.kind) orelse {
            try self.errors.add(ParseError.init(.invalid_assignment_target, makePos(kind_tok)));
            return error.InvalidDeclaration;
        };

        var decls: std.ArrayList(NodeId) = .empty;
        errdefer decls.deinit(self.allocator);

        while (true) {
            const id_tok = self.current();
            if (id_tok.kind != .identifier) {
                try self.errors.add(ParseError.init(.invalid_identifier, makePos(id_tok)));
                break;
            }
            _ = self.advance();

            const id_node = try self.ast.add(.identifier, self.spanOf(id_tok, id_tok), .{
                .identifier = .{ .name = id_tok.text },
            });

            var init_node: NodeId = NO_NODE;
            if (self.match(.op_assign)) {
                init_node = try self.parseExpression();
            }

            const decl_node = try self.ast.add(.variable_declarator, self.spanFrom(id_tok), .{
                .variable_declarator = .{ .id = id_node, .init = init_node },
            });
            try decls.append(self.allocator, decl_node);

            if (!self.match(.punct_comma)) break;
        }

        _ = self.match(.punct_semicolon);

        const decl_slice = try decls.toOwnedSlice(self.allocator);
        return self.ast.add(.variable_declaration, self.spanFrom(start_tok), .{
            .variable_declaration = .{ .kind = vk, .declarations = decl_slice },
        });
    }

    pub fn parseIf(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.keyword_if);
        _ = try self.expect(.punct_lparen);
        const cond = try self.parseExpression();
        _ = try self.expect(.punct_rparen);
        const then_stmt = try self.parseStatement();

        var else_stmt: NodeId = NO_NODE;
        if (self.match(.keyword_else)) {
            else_stmt = try self.parseStatement();
        }

        return self.ast.add(.if_statement, self.spanFrom(start_tok), .{
            .if_statement = .{
                .test_expr = cond,
                .consequent = then_stmt,
                .alternate = else_stmt,
            },
        });
    }

    pub fn parseReturn(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.keyword_return);

        var arg: NodeId = NO_NODE;
        if (self.current().kind != .punct_semicolon and
            self.current().kind != .punct_rbrace and
            !self.atEnd())
        {
            arg = try self.parseExpression();
        }
        _ = self.match(.punct_semicolon);

        return self.ast.add(.return_statement, self.spanFrom(start_tok), .{
            .return_statement = .{ .argument = arg },
        });
    }

    pub fn parseBreak(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.keyword_break);
        var label: NodeId = NO_NODE;
        if (self.current().kind == .identifier) {
            const lt = self.advance();
            label = try self.ast.add(.identifier, self.spanOf(lt, lt), .{
                .identifier = .{ .name = lt.text },
            });
        }
        _ = self.match(.punct_semicolon);
        return self.ast.add(.break_statement, self.spanFrom(start_tok), .{
            .break_statement = .{ .label = label },
        });
    }

    pub fn parseContinue(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.keyword_continue);
        var label: NodeId = NO_NODE;
        if (self.current().kind == .identifier) {
            const lt = self.advance();
            label = try self.ast.add(.identifier, self.spanOf(lt, lt), .{
                .identifier = .{ .name = lt.text },
            });
        }
        _ = self.match(.punct_semicolon);
        return self.ast.add(.continue_statement, self.spanFrom(start_tok), .{
            .continue_statement = .{ .label = label },
        });
    }

    pub fn parseFunctionDeclaration(self: *Parser) ParseError_!NodeId {
        const start_tok = try self.expect(.keyword_function);
        _ = self.match(.op_mul);

        var id: NodeId = NO_NODE;
        if (self.current().kind == .identifier) {
            const it = self.advance();
            id = try self.ast.add(.identifier, self.spanOf(it, it), .{
                .identifier = .{ .name = it.text },
            });
        }

        _ = try self.expect(.punct_lparen);
        var params: std.ArrayList(NodeId) = .empty;
        errdefer params.deinit(self.allocator);

        while (!self.atEnd() and self.current().kind != .punct_rparen) {
            if (self.current().kind == .identifier) {
                const pt = self.advance();
                const pnode = try self.ast.add(.identifier, self.spanOf(pt, pt), .{
                    .identifier = .{ .name = pt.text },
                });
                const param = try self.ast.add(.parameter, self.spanOf(pt, pt), .{
                    .parameter = .{ .pattern = pnode, .default_value = NO_NODE, .rest = false },
                });
                try params.append(self.allocator, param);
            }
            if (!self.match(.punct_comma)) break;
        }
        _ = try self.expect(.punct_rparen);

        const body = try self.parseBlock();
        const param_slice = try params.toOwnedSlice(self.allocator);

        return self.ast.add(.function_declaration, self.spanFrom(start_tok), .{
            .function = .{
                .id = id,
                .params = param_slice,
                .body = body,
                .kind = .normal,
                .strict = self.strict,
                .generator = false,
                .async_ = false,
                .expression = false,
            },
        });
    }

    pub fn parseExpression(self: *Parser) ParseError_!NodeId {
        return self.parseAssignment();
    }

    pub fn parseAssignment(self: *Parser) ParseError_!NodeId {
        try self.enter();
        defer self.leave();

        const left = try self.parseConditional();
        const t = self.current();

        if (prec.isAssignmentOperator(t.kind)) {
            _ = self.advance();
            const right = try self.parseAssignment();
            return self.ast.add(.assignment_expression, self.spanFrom(t), .{
                .assignment_expression = .{
                    .left = left,
                    .right = right,
                    .operator = .assign,
                },
            });
        }
        return left;
    }

    pub fn parseConditional(self: *Parser) ParseError_!NodeId {
        const cond = try self.parseBinary(0);
        if (self.match(.punct_question)) {
            const then_e = try self.parseAssignment();
            _ = try self.expect(.punct_colon);
            const else_e = try self.parseAssignment();
            return self.ast.add(.conditional_expression, self.spanFrom(self.current()), .{
                .conditional_expression = .{
                    .test_expr = cond,
                    .consequent = then_e,
                    .alternate = else_e,
                },
            });
        }
        return cond;
    }

    pub fn parseBinary(self: *Parser, min_prec: u8) ParseError_!NodeId {
        try self.enter();
        defer self.leave();

        var left = try self.parseUnary();

        while (true) {
            const t = self.current();
            const p = prec.precedenceOf(t.kind) orelse break;
            if (p < min_prec) break;

            if (prec.logicalInfo(t.kind)) |info| {
                _ = self.advance();
                const right = try self.parseBinary(info.precedence + 1);
                left = try self.ast.add(.logical_expression, self.spanFrom(t), .{
                    .logical_expression = .{
                        .left = left,
                        .right = right,
                        .operator = info.operator,
                    },
                });
            } else if (prec.binaryInfo(t.kind)) |info| {
                _ = self.advance();
                const next_min = if (info.right_associative) info.precedence else info.precedence + 1;
                const right = try self.parseBinary(next_min);
                left = try self.ast.add(.binary_expression, self.spanFrom(t), .{
                    .binary_expression = .{
                        .left = left,
                        .right = right,
                        .operator = info.operator,
                    },
                });
            }
        }
        return left;
    }

    pub fn parseUnary(self: *Parser) ParseError_!NodeId {
        try self.enter();
        defer self.leave();

        const t = self.current();
        const op: ?ast.UnaryOperator = switch (t.kind) {
            .op_sub => .neg,
            .op_add => .pos,
            .op_not => .not,
            .op_bit_not => .bit_not,
            .keyword_typeof => .typeof,
            .keyword_void => .void_,
            .keyword_delete => .delete,
            else => null,
        };

        if (op) |o| {
            _ = self.advance();
            const operand = try self.parseUnary();
            return self.ast.add(.unary_expression, self.spanFrom(t), .{
                .unary_expression = .{ .operand = operand, .operator = o },
            });
        }

        return self.parsePostfix();
    }

    pub fn parsePostfix(self: *Parser) ParseError_!NodeId {
        var e = try self.parseCallMember();
        const t = self.current();
        if (t.kind == .op_increment or t.kind == .op_decrement) {
            _ = self.advance();
            const op: ast.UpdateOperator = if (t.kind == .op_increment) .increment else .decrement;
            e = try self.ast.add(.update_expression, self.spanFrom(t), .{
                .update_expression = .{ .operand = e, .operator = op },
            });
        }
        return e;
    }

    pub fn parseCallMember(self: *Parser) ParseError_!NodeId {
        var e = try self.parsePrimary();

        while (true) {
            const t = self.current();
            switch (t.kind) {
                .punct_dot => {
                    _ = self.advance();
                    const prop = self.current();
                    if (prop.kind != .identifier and !prop.kind.isKeyword() and !prop.kind.isContextualKeyword()) {
                        try self.errors.add(ParseError.init(.invalid_identifier, makePos(prop)));
                        break;
                    }
                    _ = self.advance();
                    const prop_node = try self.ast.add(.identifier, self.spanOf(prop, prop), .{
                        .identifier = .{ .name = prop.text },
                    });
                    e = try self.ast.add(.member_expression, self.spanFrom(t), .{
                        .member_expression = .{
                            .object = e,
                            .property = prop_node,
                            .computed = false,
                            .optional = false,
                        },
                    });
                },
                .punct_lbracket => {
                    _ = self.advance();
                    const prop = try self.parseExpression();
                    _ = try self.expect(.punct_rbracket);
                    e = try self.ast.add(.member_expression, self.spanFrom(t), .{
                        .member_expression = .{
                            .object = e,
                            .property = prop,
                            .computed = true,
                            .optional = false,
                        },
                    });
                },
                .punct_lparen => {
                    _ = self.advance();
                    var args: std.ArrayList(NodeId) = .empty;
                    errdefer args.deinit(self.allocator);

                    while (!self.atEnd() and self.current().kind != .punct_rparen) {
                        const a = try self.parseAssignment();
                        try args.append(self.allocator, a);
                        if (!self.match(.punct_comma)) break;
                    }
                    _ = try self.expect(.punct_rparen);

                    const arg_slice = try args.toOwnedSlice(self.allocator);
                    e = try self.ast.add(.call_expression, self.spanFrom(t), .{
                        .call_expression = .{
                            .callee = e,
                            .arguments = arg_slice,
                            .optional = false,
                        },
                    });
                },
                else => break,
            }
        }

        return e;
    }

    pub fn parsePrimary(self: *Parser) ParseError_!NodeId {
        try self.enter();
        defer self.leave();

        const t = self.current();

        switch (t.kind) {
            .number => {
                _ = self.advance();
                return self.ast.add(.number_literal, self.spanOf(t, t), .{
                    .number_literal = .{ .raw = t.text, .value = 0.0 },
                });
            },
            .string => {
                _ = self.advance();
                return self.ast.add(.string_literal, self.spanOf(t, t), .{
                    .string_literal = .{ .raw = t.text, .value = t.text },
                });
            },
            .bigint => {
                _ = self.advance();
                return self.ast.add(.bigint_literal, self.spanOf(t, t), .{
                    .bigint_literal = .{ .raw = t.text },
                });
            },
            .keyword_true => {
                _ = self.advance();
                return self.ast.add(.boolean_literal, self.spanOf(t, t), .{
                    .boolean_literal = .{ .value = true },
                });
            },
            .keyword_false => {
                _ = self.advance();
                return self.ast.add(.boolean_literal, self.spanOf(t, t), .{
                    .boolean_literal = .{ .value = false },
                });
            },
            .keyword_null => {
                _ = self.advance();
                return self.ast.add(.null_literal, self.spanOf(t, t), .{ .null_literal = {} });
            },
            .keyword_this => {
                _ = self.advance();
                return self.ast.add(.this_expression, self.spanOf(t, t), .{ .this_expression = {} });
            },
            .identifier => {
                _ = self.advance();
                return self.ast.add(.identifier, self.spanOf(t, t), .{
                    .identifier = .{ .name = t.text },
                });
            },
            .punct_lparen => {
                _ = self.advance();
                const e = try self.parseExpression();
                _ = try self.expect(.punct_rparen);
                return e;
            },
            else => {
                try self.errors.add(ParseError.init(.unexpected_token, makePos(t)).withToken(t.text));
                return error.UnexpectedToken;
            },
        }
    }
};

pub fn makePos(t: Token) Position {
    return .{ .offset = t.offset, .line = t.line, .column = t.column };
}

pub fn parse(allocator: std.mem.Allocator, tokens: []const Token) !struct {
    ast: Ast,
    errors: ErrorList,
} {
    var a = Ast.init(allocator);
    var e = ErrorList.init(allocator);

    var p = Parser.init(allocator, &a, &e, tokens);
    _ = p.parseProgram() catch {};

    return .{ .ast = a, .errors = e };
}

test "Parser init" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .eof, .text = "", .line = 1, .column = 1, .offset = 0 },
    };
    const p = Parser.init(std.testing.allocator, &a, &e, &toks);
    try std.testing.expectEqual(@as(usize, 0), p.pos);
    try std.testing.expect(p.atEnd());
}

test "Parser advance and match" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);

    try std.testing.expect(p.match(.identifier));
    try std.testing.expect(p.match(.punct_semicolon));
    try std.testing.expect(p.atEnd());
}

test "Parser expect succeeds" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .punct_lparen, .text = "(", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    _ = try p.expect(.punct_lparen);
    try std.testing.expectEqual(@as(usize, 0), e.count());
}

test "Parser expect fails" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    try std.testing.expectError(error.UnexpectedToken, p.expect(.punct_lparen));
}

test "parse empty program" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .eof, .text = "", .line = 1, .column = 1, .offset = 0 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const prog = try p.parseProgram();
    try std.testing.expectEqual(NodeTag.program, a.tagOf(prog));
}

test "parse empty statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseStatement();
    try std.testing.expectEqual(NodeTag.empty_statement, a.tagOf(s));
}

test "parse number literal" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .number, .text = "42", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.number_literal, a.tagOf(n));
}

test "parse identifier" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .identifier, .text = "foo", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 4, .offset = 3 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const id = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.identifier, a.tagOf(id));
    try std.testing.expectEqualStrings("foo", a.get(id).data.identifier.name);
}

test "parse boolean literal" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_true, .text = "true", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 5, .offset = 4 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const b = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.boolean_literal, a.tagOf(b));
}

test "parse this" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_this, .text = "this", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 5, .offset = 4 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.this_expression, a.tagOf(n));
}

test "parse parenthesized expression" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .punct_lparen, .text = "(", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .number, .text = "1", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 3, .offset = 2 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 4, .offset = 3 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.number_literal, a.tagOf(n));
}

test "parse binary addition" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .number, .text = "1", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 3, .offset = 2 },
        .{ .kind = .number, .text = "2", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 6, .offset = 5 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.binary_expression, a.tagOf(n));
}

test "parse unary negation" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .op_sub, .text = "-", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .number, .text = "5", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.unary_expression, a.tagOf(n));
}

test "parse expression statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseStatement();
    try std.testing.expectEqual(NodeTag.expression_statement, a.tagOf(s));
}

test "parse block statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .punct_lbrace, .text = "{", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .punct_rbrace, .text = "}", .line = 1, .column = 3, .offset = 2 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 4, .offset = 3 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseBlock();
    try std.testing.expectEqual(NodeTag.block_statement, a.tagOf(s));
}

test "parse if statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_if, .text = "if", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_lparen, .text = "(", .line = 1, .column = 4, .offset = 3 },
        .{ .kind = .keyword_true, .text = "true", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 9, .offset = 8 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 10, .offset = 9 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 11, .offset = 10 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseIf();
    try std.testing.expectEqual(NodeTag.if_statement, a.tagOf(s));
}

test "parse return statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_return, .text = "return", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .number, .text = "1", .line = 1, .column = 8, .offset = 7 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 9, .offset = 8 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 10, .offset = 9 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseReturn();
    try std.testing.expectEqual(NodeTag.return_statement, a.tagOf(s));
}

test "parse break statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_break, .text = "break", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 6, .offset = 5 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 7, .offset = 6 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseBreak();
    try std.testing.expectEqual(NodeTag.break_statement, a.tagOf(s));
}

test "parse continue statement" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_continue, .text = "continue", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 9, .offset = 8 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 10, .offset = 9 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseContinue();
    try std.testing.expectEqual(NodeTag.continue_statement, a.tagOf(s));
}

test "parse variable declaration var" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_var, .text = "var", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 6, .offset = 5 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 7, .offset = 6 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseVariableDeclaration();
    try std.testing.expectEqual(NodeTag.variable_declaration, a.tagOf(s));
}

test "parse variable declaration with init" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_let, .text = "let", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .op_assign, .text = "=", .line = 1, .column = 7, .offset = 6 },
        .{ .kind = .number, .text = "42", .line = 1, .column = 9, .offset = 8 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 11, .offset = 10 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 12, .offset = 11 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseVariableDeclaration();
    try std.testing.expectEqual(NodeTag.variable_declaration, a.tagOf(s));
}

test "parse function declaration" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_function, .text = "function", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .identifier, .text = "foo", .line = 1, .column = 10, .offset = 9 },
        .{ .kind = .punct_lparen, .text = "(", .line = 1, .column = 13, .offset = 12 },
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 14, .offset = 13 },
        .{ .kind = .punct_lbrace, .text = "{", .line = 1, .column = 16, .offset = 15 },
        .{ .kind = .punct_rbrace, .text = "}", .line = 1, .column = 17, .offset = 16 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 18, .offset = 17 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const s = try p.parseFunctionDeclaration();
    try std.testing.expectEqual(NodeTag.function_declaration, a.tagOf(s));
}

test "parse member access" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .identifier, .text = "obj", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_dot, .text = ".", .line = 1, .column = 4, .offset = 3 },
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 6, .offset = 5 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.member_expression, a.tagOf(n));
}

test "parse call expression" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .identifier, .text = "f", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_lparen, .text = "(", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .number, .text = "1", .line = 1, .column = 3, .offset = 2 },
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 4, .offset = 3 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 5, .offset = 4 },
    };
    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const n = try p.parseExpression();
    try std.testing.expectEqual(NodeTag.call_expression, a.tagOf(n));
}

test "parse full program" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .keyword_var, .text = "var", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 5, .offset = 4 },
        .{ .kind = .op_assign, .text = "=", .line = 1, .column = 7, .offset = 6 },
        .{ .kind = .number, .text = "1", .line = 1, .column = 9, .offset = 8 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 10, .offset = 9 },
        .{ .kind = .identifier, .text = "x", .line = 2, .column = 1, .offset = 10 },
        .{ .kind = .op_add, .text = "+", .line = 2, .column = 3, .offset = 12 },
        .{ .kind = .number, .text = "2", .line = 2, .column = 5, .offset = 14 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 2, .column = 6, .offset = 15 },
        .{ .kind = .eof, .text = "", .line = 2, .column = 7, .offset = 16 },
    };

    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    const prog = try p.parseProgram();
    try std.testing.expectEqual(NodeTag.program, a.tagOf(prog));
    try std.testing.expectEqual(@as(usize, 2), a.get(prog).data.program.body.len);
    try std.testing.expectEqual(@as(usize, 0), e.count());
}

test "parse error recovery in program" {
    var a = Ast.init(std.testing.allocator);
    defer a.deinit();
    var e = ErrorList.init(std.testing.allocator);
    defer e.deinit();

    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .keyword_var, .text = "var", .line = 2, .column = 1, .offset = 2 },
        .{ .kind = .identifier, .text = "x", .line = 2, .column = 5, .offset = 6 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 2, .column = 6, .offset = 7 },
        .{ .kind = .eof, .text = "", .line = 2, .column = 7, .offset = 8 },
    };

    var p = Parser.init(std.testing.allocator, &a, &e, &toks);
    _ = try p.parseProgram();
    try std.testing.expect(e.count() >= 1);
}

test "parse helper" {
    const toks = [_]Token{
        .{ .kind = .number, .text = "1", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 3, .offset = 2 },
    };

    const result = try parse(std.testing.allocator, &toks);
    var ast_mut = result.ast;
    var errs_mut = result.errors;
    defer ast_mut.deinit();
    defer errs_mut.deinit();

    try std.testing.expect(ast_mut.count() > 0);
}
