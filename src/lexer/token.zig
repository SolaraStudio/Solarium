const std = @import("std");

pub const Kind = enum(u8) {
    eof,
    invalid,
    identifier,
    private_identifier,

    number,
    bigint,
    string,
    template_string,
    template_head,
    template_middle,
    template_tail,
    regex,

    keyword_break,
    keyword_case,
    keyword_catch,
    keyword_class,
    keyword_const,
    keyword_continue,
    keyword_debugger,
    keyword_default,
    keyword_delete,
    keyword_do,
    keyword_else,
    keyword_enum,
    keyword_export,
    keyword_extends,
    keyword_false,
    keyword_finally,
    keyword_for,
    keyword_function,
    keyword_if,
    keyword_import,
    keyword_in,
    keyword_instanceof,
    keyword_new,
    keyword_null,
    keyword_return,
    keyword_super,
    keyword_switch,
    keyword_this,
    keyword_throw,
    keyword_true,
    keyword_try,
    keyword_typeof,
    keyword_var,
    keyword_void,
    keyword_while,
    keyword_with,

    keyword_as,
    keyword_async,
    keyword_await,
    keyword_from,
    keyword_get,
    keyword_let,
    keyword_meta,
    keyword_of,
    keyword_set,
    keyword_static,
    keyword_target,
    keyword_yield,

    punct_lbrace,
    punct_rbrace,
    punct_lparen,
    punct_rparen,
    punct_lbracket,
    punct_rbracket,
    punct_semicolon,
    punct_comma,
    punct_dot,
    punct_ellipsis,
    punct_colon,
    punct_question,
    punct_question_dot,
    punct_question_question,
    punct_arrow,

    op_assign,
    op_add,
    op_sub,
    op_mul,
    op_div,
    op_mod,
    op_exp,
    op_eq,
    op_strict_eq,
    op_neq,
    op_strict_neq,
    op_lt,
    op_gt,
    op_lte,
    op_gte,
    op_and,
    op_or,
    op_not,
    op_bit_and,
    op_bit_or,
    op_bit_xor,
    op_bit_not,
    op_shl,
    op_shr,
    op_ushr,
    op_add_assign,
    op_sub_assign,
    op_mul_assign,
    op_div_assign,
    op_mod_assign,
    op_exp_assign,
    op_and_assign,
    op_or_assign,
    op_xor_assign,
    op_shl_assign,
    op_shr_assign,
    op_ushr_assign,
    op_and_and,
    op_or_or,
    op_nullish,
    op_increment,
    op_decrement,
    op_and_and_assign,
    op_or_or_assign,
    op_nullish_assign,

    pub fn isKeyword(self: Kind) bool {
        return switch (self) {
            .keyword_break,
            .keyword_case,
            .keyword_catch,
            .keyword_class,
            .keyword_const,
            .keyword_continue,
            .keyword_debugger,
            .keyword_default,
            .keyword_delete,
            .keyword_do,
            .keyword_else,
            .keyword_enum,
            .keyword_export,
            .keyword_extends,
            .keyword_false,
            .keyword_finally,
            .keyword_for,
            .keyword_function,
            .keyword_if,
            .keyword_import,
            .keyword_in,
            .keyword_instanceof,
            .keyword_new,
            .keyword_null,
            .keyword_return,
            .keyword_super,
            .keyword_switch,
            .keyword_this,
            .keyword_throw,
            .keyword_true,
            .keyword_try,
            .keyword_typeof,
            .keyword_var,
            .keyword_void,
            .keyword_while,
            .keyword_with,
            => true,
            else => false,
        };
    }

    pub fn isReservedWord(self: Kind) bool {
        return self.isKeyword();
    }

    pub fn isContextualKeyword(self: Kind) bool {
        return switch (self) {
            .keyword_as,
            .keyword_async,
            .keyword_await,
            .keyword_from,
            .keyword_get,
            .keyword_let,
            .keyword_meta,
            .keyword_of,
            .keyword_set,
            .keyword_static,
            .keyword_target,
            .keyword_yield,
            => true,
            else => false,
        };
    }

    pub fn isLiteral(self: Kind) bool {
        return switch (self) {
            .number,
            .bigint,
            .string,
            .template_string,
            .template_head,
            .template_middle,
            .template_tail,
            .regex,
            .keyword_true,
            .keyword_false,
            .keyword_null,
            => true,
            else => false,
        };
    }

    pub fn isPunctuation(self: Kind) bool {
        return switch (self) {
            .punct_lbrace,
            .punct_rbrace,
            .punct_lparen,
            .punct_rparen,
            .punct_lbracket,
            .punct_rbracket,
            .punct_semicolon,
            .punct_comma,
            .punct_dot,
            .punct_ellipsis,
            .punct_colon,
            .punct_question,
            .punct_question_dot,
            .punct_question_question,
            .punct_arrow,
            => true,
            else => false,
        };
    }

    pub fn isOperator(self: Kind) bool {
        return switch (self) {
            .op_assign,
            .op_add,
            .op_sub,
            .op_mul,
            .op_div,
            .op_mod,
            .op_exp,
            .op_eq,
            .op_strict_eq,
            .op_neq,
            .op_strict_neq,
            .op_lt,
            .op_gt,
            .op_lte,
            .op_gte,
            .op_and,
            .op_or,
            .op_not,
            .op_bit_and,
            .op_bit_or,
            .op_bit_xor,
            .op_bit_not,
            .op_shl,
            .op_shr,
            .op_ushr,
            .op_add_assign,
            .op_sub_assign,
            .op_mul_assign,
            .op_div_assign,
            .op_mod_assign,
            .op_exp_assign,
            .op_and_assign,
            .op_or_assign,
            .op_xor_assign,
            .op_shl_assign,
            .op_shr_assign,
            .op_ushr_assign,
            .op_and_and,
            .op_or_or,
            .op_nullish,
            .op_increment,
            .op_decrement,
            .op_and_and_assign,
            .op_or_or_assign,
            .op_nullish_assign,
            => true,
            else => false,
        };
    }

    pub fn isAssignment(self: Kind) bool {
        return switch (self) {
            .op_assign,
            .op_add_assign,
            .op_sub_assign,
            .op_mul_assign,
            .op_div_assign,
            .op_mod_assign,
            .op_exp_assign,
            .op_and_assign,
            .op_or_assign,
            .op_xor_assign,
            .op_shl_assign,
            .op_shr_assign,
            .op_ushr_assign,
            .op_and_and_assign,
            .op_or_or_assign,
            .op_nullish_assign,
            => true,
            else => false,
        };
    }

    pub fn isTemplatePart(self: Kind) bool {
        return switch (self) {
            .template_head,
            .template_middle,
            .template_tail,
            .template_string,
            => true,
            else => false,
        };
    }

    pub fn isTrivia(self: Kind) bool {
        return self == .eof or self == .invalid;
    }

    pub fn isNewlineSensitive(self: Kind) bool {
        return switch (self) {
            .op_increment,
            .op_decrement,
            .op_add,
            .op_sub,
            .op_div,
            .op_mod,
            .op_exp,
            .op_and_and,
            .op_or_or,
            .op_nullish,
            .op_lt,
            .op_gt,
            .op_lte,
            .op_gte,
            .op_eq,
            .op_strict_eq,
            .op_neq,
            .op_strict_neq,
            .op_bit_and,
            .op_bit_or,
            .op_bit_xor,
            .op_shl,
            .op_shr,
            .op_ushr,
            .op_assign,
            .op_add_assign,
            .op_sub_assign,
            .op_mul_assign,
            .op_div_assign,
            .op_mod_assign,
            .op_exp_assign,
            .op_and_assign,
            .op_or_assign,
            .op_xor_assign,
            .op_shl_assign,
            .op_shr_assign,
            .op_ushr_assign,
            .op_and_and_assign,
            .op_or_or_assign,
            .op_nullish_assign,
            => true,
            else => false,
        };
    }

    pub fn toString(self: Kind) []const u8 {
        return @tagName(self);
    }
};

pub const NEWLINE_FLAG: u16 = 0x0001;
pub const HAS_ESCAPE_FLAG: u16 = 0x0002;
pub const LEGACY_OCTAL_FLAG: u16 = 0x0004;
pub const STRICT_OCTAL_FLAG: u16 = 0x0008;
pub const UNTERMINATED_FLAG: u16 = 0x0010;
pub const IS_KEYWORD_FLAG: u16 = 0x0020;
pub const INVALID_ESCAPE_FLAG: u16 = 0x0040;
pub const COMPUTED_FLAG: u16 = 0x0080;

pub const Token = struct {
    kind: Kind,
    text: []const u8,
    line: u32,
    column: u32,
    offset: u32,
    flags: u16 = 0,

    pub fn hasNewlineBefore(self: Token) bool {
        return (self.flags & NEWLINE_FLAG) != 0;
    }

    pub fn hasEscape(self: Token) bool {
        return (self.flags & HAS_ESCAPE_FLAG) != 0;
    }

    pub fn isLegacyOctal(self: Token) bool {
        return (self.flags & LEGACY_OCTAL_FLAG) != 0;
    }

    pub fn isStrictOctal(self: Token) bool {
        return (self.flags & STRICT_OCTAL_FLAG) != 0;
    }

    pub fn isUnterminated(self: Token) bool {
        return (self.flags & UNTERMINATED_FLAG) != 0;
    }

    pub fn hasInvalidEscape(self: Token) bool {
        return (self.flags & INVALID_ESCAPE_FLAG) != 0;
    }

    pub fn isComputed(self: Token) bool {
        return (self.flags & COMPUTED_FLAG) != 0;
    }

    pub fn isEof(self: Token) bool {
        return self.kind == .eof;
    }

    pub fn isIdentifier(self: Token) bool {
        return self.kind == .identifier or self.kind == .private_identifier;
    }

    pub fn isKeyword(self: Token) bool {
        return self.kind.isKeyword();
    }

    pub fn isLiteral(self: Token) bool {
        return self.kind.isLiteral();
    }

    pub fn eql(self: Token, other: Token) bool {
        return self.kind == other.kind and std.mem.eql(u8, self.text, other.text);
    }

    pub fn isText(self: Token, text: []const u8) bool {
        return std.mem.eql(u8, self.text, text);
    }

    pub fn len(self: Token) usize {
        return self.text.len;
    }

    pub fn isEmpty(self: Token) bool {
        return self.text.len == 0;
    }
};

pub const keyword_map = std.StaticStringMap(Kind).initComptime(.{
    .{ "break", .keyword_break },
    .{ "case", .keyword_case },
    .{ "catch", .keyword_catch },
    .{ "class", .keyword_class },
    .{ "const", .keyword_const },
    .{ "continue", .keyword_continue },
    .{ "debugger", .keyword_debugger },
    .{ "default", .keyword_default },
    .{ "delete", .keyword_delete },
    .{ "do", .keyword_do },
    .{ "else", .keyword_else },
    .{ "enum", .keyword_enum },
    .{ "export", .keyword_export },
    .{ "extends", .keyword_extends },
    .{ "false", .keyword_false },
    .{ "finally", .keyword_finally },
    .{ "for", .keyword_for },
    .{ "function", .keyword_function },
    .{ "if", .keyword_if },
    .{ "import", .keyword_import },
    .{ "in", .keyword_in },
    .{ "instanceof", .keyword_instanceof },
    .{ "new", .keyword_new },
    .{ "null", .keyword_null },
    .{ "return", .keyword_return },
    .{ "super", .keyword_super },
    .{ "switch", .keyword_switch },
    .{ "this", .keyword_this },
    .{ "throw", .keyword_throw },
    .{ "true", .keyword_true },
    .{ "try", .keyword_try },
    .{ "typeof", .keyword_typeof },
    .{ "var", .keyword_var },
    .{ "void", .keyword_void },
    .{ "while", .keyword_while },
    .{ "with", .keyword_with },
});

pub const contextual_keyword_map = std.StaticStringMap(Kind).initComptime(.{
    .{ "as", .keyword_as },
    .{ "async", .keyword_async },
    .{ "await", .keyword_await },
    .{ "from", .keyword_from },
    .{ "get", .keyword_get },
    .{ "let", .keyword_let },
    .{ "meta", .keyword_meta },
    .{ "of", .keyword_of },
    .{ "set", .keyword_set },
    .{ "static", .keyword_static },
    .{ "target", .keyword_target },
    .{ "yield", .keyword_yield },
});

pub fn lookupKeyword(text: []const u8) ?Kind {
    return keyword_map.get(text);
}

pub fn lookupContextualKeyword(text: []const u8) ?Kind {
    return contextual_keyword_map.get(text);
}

pub fn isKeywordText(text: []const u8) bool {
    return keyword_map.get(text) != null;
}

pub fn isContextualKeywordText(text: []const u8) bool {
    return contextual_keyword_map.get(text) != null;
}

test "Kind isKeyword" {
    try std.testing.expect(Kind.keyword_break.isKeyword());
    try std.testing.expect(Kind.keyword_function.isKeyword());
    try std.testing.expect(!Kind.identifier.isKeyword());
    try std.testing.expect(!Kind.keyword_let.isKeyword());
}

test "Kind isContextualKeyword" {
    try std.testing.expect(Kind.keyword_let.isContextualKeyword());
    try std.testing.expect(Kind.keyword_yield.isContextualKeyword());
    try std.testing.expect(!Kind.keyword_break.isContextualKeyword());
}

test "Kind isLiteral" {
    try std.testing.expect(Kind.number.isLiteral());
    try std.testing.expect(Kind.string.isLiteral());
    try std.testing.expect(Kind.regex.isLiteral());
    try std.testing.expect(Kind.keyword_true.isLiteral());
    try std.testing.expect(!Kind.identifier.isLiteral());
}

test "Kind isPunctuation" {
    try std.testing.expect(Kind.punct_lbrace.isPunctuation());
    try std.testing.expect(Kind.punct_semicolon.isPunctuation());
    try std.testing.expect(Kind.punct_arrow.isPunctuation());
    try std.testing.expect(!Kind.op_add.isPunctuation());
}

test "Kind isOperator" {
    try std.testing.expect(Kind.op_add.isOperator());
    try std.testing.expect(Kind.op_strict_eq.isOperator());
    try std.testing.expect(Kind.op_nullish.isOperator());
    try std.testing.expect(!Kind.punct_lbrace.isOperator());
}

test "Kind isAssignment" {
    try std.testing.expect(Kind.op_assign.isAssignment());
    try std.testing.expect(Kind.op_add_assign.isAssignment());
    try std.testing.expect(Kind.op_nullish_assign.isAssignment());
    try std.testing.expect(!Kind.op_add.isAssignment());
}

test "Kind isTemplatePart" {
    try std.testing.expect(Kind.template_head.isTemplatePart());
    try std.testing.expect(Kind.template_middle.isTemplatePart());
    try std.testing.expect(Kind.template_tail.isTemplatePart());
    try std.testing.expect(Kind.template_string.isTemplatePart());
    try std.testing.expect(!Kind.string.isTemplatePart());
}

test "Kind isNewlineSensitive" {
    try std.testing.expect(Kind.op_increment.isNewlineSensitive());
    try std.testing.expect(Kind.op_add.isNewlineSensitive());
    try std.testing.expect(!Kind.punct_semicolon.isNewlineSensitive());
}

test "Kind toString" {
    try std.testing.expectEqualStrings("keyword_break", Kind.keyword_break.toString());
    try std.testing.expectEqualStrings("op_add", Kind.op_add.toString());
}

test "Token flags" {
    const t = Token{
        .kind = .op_add,
        .text = "+",
        .line = 1,
        .column = 5,
        .offset = 4,
        .flags = NEWLINE_FLAG,
    };
    try std.testing.expect(t.hasNewlineBefore());
    try std.testing.expect(!t.hasEscape());
}

test "Token isEof" {
    const t = Token{ .kind = .eof, .text = "", .line = 1, .column = 1, .offset = 0 };
    try std.testing.expect(t.isEof());
}

test "Token isIdentifier" {
    const t = Token{ .kind = .identifier, .text = "foo", .line = 1, .column = 1, .offset = 0 };
    try std.testing.expect(t.isIdentifier());

    const p = Token{ .kind = .private_identifier, .text = "#bar", .line = 1, .column = 1, .offset = 0 };
    try std.testing.expect(p.isIdentifier());
}

test "Token eql" {
    const a = Token{ .kind = .identifier, .text = "foo", .line = 1, .column = 1, .offset = 0 };
    const b = Token{ .kind = .identifier, .text = "foo", .line = 1, .column = 1, .offset = 0 };
    const c = Token{ .kind = .identifier, .text = "bar", .line = 1, .column = 1, .offset = 0 };
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
}

test "Token isText" {
    const t = Token{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 };
    try std.testing.expect(t.isText("+"));
    try std.testing.expect(!t.isText("-"));
}

test "lookupKeyword" {
    try std.testing.expectEqual(Kind.keyword_break, lookupKeyword("break").?);
    try std.testing.expectEqual(Kind.keyword_function, lookupKeyword("function").?);
    try std.testing.expectEqual(Kind.keyword_null, lookupKeyword("null").?);
    try std.testing.expect(lookupKeyword("foo") == null);
    try std.testing.expect(lookupKeyword("let") == null);
}

test "lookupContextualKeyword" {
    try std.testing.expectEqual(Kind.keyword_let, lookupContextualKeyword("let").?);
    try std.testing.expectEqual(Kind.keyword_async, lookupContextualKeyword("async").?);
    try std.testing.expectEqual(Kind.keyword_await, lookupContextualKeyword("await").?);
    try std.testing.expect(lookupContextualKeyword("break") == null);
}

test "isKeywordText" {
    try std.testing.expect(isKeywordText("if"));
    try std.testing.expect(isKeywordText("while"));
    try std.testing.expect(!isKeywordText("let"));
    try std.testing.expect(!isKeywordText("foo"));
}

test "isContextualKeywordText" {
    try std.testing.expect(isContextualKeywordText("let"));
    try std.testing.expect(isContextualKeywordText("yield"));
    try std.testing.expect(!isContextualKeywordText("if"));
}

test "all reserved keywords present" {
    const reserved = [_][]const u8{
        "break",    "case",     "catch",  "class", "const",
        "continue", "debugger", "default", "delete", "do",
        "else",     "enum",     "export", "extends", "false",
        "finally",  "for",      "function", "if",    "import",
        "in",       "instanceof", "new",  "null",    "return",
        "super",    "switch",   "this",    "throw",  "true",
        "try",      "typeof",   "var",     "void",   "while",
        "with",
    };
    for (reserved) |kw| {
        try std.testing.expect(isKeywordText(kw));
    }
}

test "all contextual keywords present" {
    const contextual = [_][]const u8{
        "as", "async", "await", "from", "get",
        "let", "meta", "of", "set", "static", "target", "yield",
    };
    for (contextual) |kw| {
        try std.testing.expect(isContextualKeywordText(kw));
    }
}
