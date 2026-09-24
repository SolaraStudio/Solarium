const std = @import("std");
const token = @import("token.zig");

pub const Kind = token.Kind;

pub const Context = enum {
    normal,
    strict,
    module,
    function_body,
    class_body,
    object_literal,
    property_name,
    label,
    after_dot,
    before_expression,
    after_expression,
};

pub const Category = enum {
    reserved,
    contextual,
    future_reserved,
    strict_reserved,
    literal,
    not_keyword,
};

pub const reserved_words = [_][]const u8{
    "break",
    "case",
    "catch",
    "class",
    "const",
    "continue",
    "debugger",
    "default",
    "delete",
    "do",
    "else",
    "enum",
    "export",
    "extends",
    "false",
    "finally",
    "for",
    "function",
    "if",
    "import",
    "in",
    "instanceof",
    "new",
    "null",
    "return",
    "super",
    "switch",
    "this",
    "throw",
    "true",
    "try",
    "typeof",
    "var",
    "void",
    "while",
    "with",
};

pub const contextual_keywords = [_][]const u8{
    "as",
    "async",
    "await",
    "from",
    "get",
    "let",
    "meta",
    "of",
    "set",
    "static",
    "target",
    "yield",
};

pub const strict_reserved = [_][]const u8{
    "implements",
    "interface",
    "package",
    "private",
    "protected",
    "public",
};

pub const future_reserved = [_][]const u8{
    "enum",
};

pub const literals = [_][]const u8{
    "true",
    "false",
    "null",
};

pub const unary_keywords = [_][]const u8{
    "delete",
    "void",
    "typeof",
    "await",
};

pub const binary_keywords = [_][]const u8{
    "in",
    "instanceof",
};

pub const statement_keywords = [_][]const u8{
    "break",
    "case",
    "catch",
    "class",
    "const",
    "continue",
    "debugger",
    "default",
    "do",
    "else",
    "export",
    "finally",
    "for",
    "function",
    "if",
    "import",
    "return",
    "switch",
    "throw",
    "try",
    "var",
    "while",
    "with",
    "let",
};

pub const expression_keywords = [_][]const u8{
    "this",
    "super",
    "new",
    "function",
    "class",
    "true",
    "false",
    "null",
};

pub fn isReserved(text: []const u8) bool {
    for (reserved_words) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isContextual(text: []const u8) bool {
    for (contextual_keywords) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isStrictReserved(text: []const u8) bool {
    for (strict_reserved) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isFutureReserved(text: []const u8) bool {
    for (future_reserved) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isLiteral(text: []const u8) bool {
    for (literals) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isUnaryKeyword(text: []const u8) bool {
    for (unary_keywords) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isBinaryKeyword(text: []const u8) bool {
    for (binary_keywords) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isStatementKeyword(text: []const u8) bool {
    for (statement_keywords) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isExpressionKeyword(text: []const u8) bool {
    for (expression_keywords) |kw| {
        if (std.mem.eql(u8, kw, text)) return true;
    }
    return false;
}

pub fn isAnyKeyword(text: []const u8) bool {
    return isReserved(text) or isContextual(text) or
        isStrictReserved(text) or isFutureReserved(text);
}

pub fn categorize(text: []const u8) Category {
    if (isReserved(text)) {
        if (isLiteral(text)) return .literal;
        return .reserved;
    }
    if (isContextual(text)) return .contextual;
    if (isFutureReserved(text)) return .future_reserved;
    if (isStrictReserved(text)) return .strict_reserved;
    return .not_keyword;
}

pub fn isKeywordInContext(text: []const u8, context: Context) bool {
    if (isReserved(text)) return true;
    if (isLiteral(text)) return true;

    if (isStrictReserved(text)) {
        return context == .strict or context == .module;
    }

    if (isFutureReserved(text)) {
        return context == .strict or context == .module;
    }

    if (isContextual(text)) {
        return context != .after_dot;
    }

    return false;
}

pub fn canBeIdentifier(text: []const u8, context: Context) bool {
    if (isReserved(text)) return false;
    if (isLiteral(text)) return false;

    if (isStrictReserved(text)) {
        return context != .strict and context != .module;
    }

    if (isFutureReserved(text)) {
        return context != .strict and context != .module;
    }

    return true;
}

pub fn canBePropertyName(text: []const u8) bool {
    return isAnyKeyword(text);
}

pub fn canBeLabel(text: []const u8) bool {
    if (isReserved(text)) return false;
    if (isLiteral(text)) return false;
    return true;
}

pub fn keywordToKind(text: []const u8) ?Kind {
    return token.lookupKeyword(text);
}

pub fn contextualToKind(text: []const u8) ?Kind {
    return token.lookupContextualKeyword(text);
}

pub fn classify(text: []const u8) Kind {
    if (token.lookupKeyword(text)) |kw| return kw;
    if (token.lookupContextualKeyword(text)) |kw| return kw;
    return .identifier;
}

pub fn isEscapedKeyword(text: []const u8) bool {
    for (text) |c| {
        if (c == '\\') return true;
    }
    return false;
}

pub fn normalize(text: []const u8) []const u8 {
    return text;
}

pub const KeywordSet = struct {
    bits: u64,

    pub fn init() KeywordSet {
        return .{ .bits = 0 };
    }

    pub fn fromContext(context: Context) KeywordSet {
        var set = KeywordSet.init();
        for (reserved_words, 0..) |_, i| {
            if (i < 64) set.bits |= @as(u64, 1) << @intCast(i);
        }
        if (context == .strict or context == .module) {
            var i: usize = 0;
            while (i < strict_reserved.len and i + 36 < 64) : (i += 1) {
                set.bits |= @as(u64, 1) << @intCast(36 + i);
            }
        }
        return set;
    }

    pub fn contains(self: KeywordSet, index: u6) bool {
        return (self.bits & (@as(u64, 1) << index)) != 0;
    }
};

test "isReserved" {
    try std.testing.expect(isReserved("if"));
    try std.testing.expect(isReserved("function"));
    try std.testing.expect(isReserved("return"));
    try std.testing.expect(isReserved("true"));
    try std.testing.expect(!isReserved("let"));
    try std.testing.expect(!isReserved("foo"));
}

test "isContextual" {
    try std.testing.expect(isContextual("let"));
    try std.testing.expect(isContextual("async"));
    try std.testing.expect(isContextual("await"));
    try std.testing.expect(isContextual("yield"));
    try std.testing.expect(isContextual("get"));
    try std.testing.expect(isContextual("set"));
    try std.testing.expect(isContextual("of"));
    try std.testing.expect(!isContextual("if"));
    try std.testing.expect(!isContextual("var"));
}

test "isStrictReserved" {
    try std.testing.expect(isStrictReserved("implements"));
    try std.testing.expect(isStrictReserved("interface"));
    try std.testing.expect(isStrictReserved("private"));
    try std.testing.expect(isStrictReserved("public"));
    try std.testing.expect(isStrictReserved("protected"));
    try std.testing.expect(isStrictReserved("package"));
    try std.testing.expect(!isStrictReserved("if"));
}

test "isFutureReserved" {
    try std.testing.expect(isFutureReserved("enum"));
    try std.testing.expect(!isFutureReserved("if"));
}

test "isLiteral" {
    try std.testing.expect(isLiteral("true"));
    try std.testing.expect(isLiteral("false"));
    try std.testing.expect(isLiteral("null"));
    try std.testing.expect(!isLiteral("if"));
}

test "isUnaryKeyword" {
    try std.testing.expect(isUnaryKeyword("typeof"));
    try std.testing.expect(isUnaryKeyword("delete"));
    try std.testing.expect(isUnaryKeyword("void"));
    try std.testing.expect(isUnaryKeyword("await"));
    try std.testing.expect(!isUnaryKeyword("if"));
}

test "isBinaryKeyword" {
    try std.testing.expect(isBinaryKeyword("in"));
    try std.testing.expect(isBinaryKeyword("instanceof"));
    try std.testing.expect(!isBinaryKeyword("if"));
}

test "isStatementKeyword" {
    try std.testing.expect(isStatementKeyword("if"));
    try std.testing.expect(isStatementKeyword("while"));
    try std.testing.expect(isStatementKeyword("return"));
    try std.testing.expect(isStatementKeyword("let"));
    try std.testing.expect(!isStatementKeyword("true"));
}

test "isExpressionKeyword" {
    try std.testing.expect(isExpressionKeyword("this"));
    try std.testing.expect(isExpressionKeyword("new"));
    try std.testing.expect(isExpressionKeyword("function"));
    try std.testing.expect(isExpressionKeyword("true"));
    try std.testing.expect(!isExpressionKeyword("if"));
}

test "isAnyKeyword" {
    try std.testing.expect(isAnyKeyword("if"));
    try std.testing.expect(isAnyKeyword("let"));
    try std.testing.expect(isAnyKeyword("implements"));
    try std.testing.expect(!isAnyKeyword("foo"));
}

test "categorize" {
    try std.testing.expectEqual(Category.reserved, categorize("if"));
    try std.testing.expectEqual(Category.literal, categorize("true"));
    try std.testing.expectEqual(Category.contextual, categorize("let"));
    try std.testing.expectEqual(Category.strict_reserved, categorize("implements"));
    try std.testing.expectEqual(Category.reserved, categorize("enum"));
    try std.testing.expectEqual(Category.not_keyword, categorize("foo"));
}

test "isKeywordInContext normal" {
    try std.testing.expect(isKeywordInContext("if", .normal));
    try std.testing.expect(isKeywordInContext("true", .normal));
    try std.testing.expect(isKeywordInContext("let", .normal));
    try std.testing.expect(!isKeywordInContext("implements", .normal));
    try std.testing.expect(!isKeywordInContext("foo", .normal));
}

test "isKeywordInContext strict" {
    try std.testing.expect(isKeywordInContext("implements", .strict));
    try std.testing.expect(isKeywordInContext("package", .strict));
    try std.testing.expect(isKeywordInContext("interface", .strict));
}

test "isKeywordInContext module" {
    try std.testing.expect(isKeywordInContext("implements", .module));
    try std.testing.expect(isKeywordInContext("await", .module));
}

test "isKeywordInContext after dot" {
    try std.testing.expect(!isKeywordInContext("let", .after_dot));
    try std.testing.expect(isKeywordInContext("if", .after_dot));
    try std.testing.expect(isKeywordInContext("true", .after_dot));
}

test "canBeIdentifier normal" {
    try std.testing.expect(!canBeIdentifier("if", .normal));
    try std.testing.expect(!canBeIdentifier("true", .normal));
    try std.testing.expect(canBeIdentifier("let", .normal));
    try std.testing.expect(canBeIdentifier("implements", .normal));
    try std.testing.expect(canBeIdentifier("foo", .normal));
}

test "canBeIdentifier strict" {
    try std.testing.expect(!canBeIdentifier("implements", .strict));
    try std.testing.expect(!canBeIdentifier("package", .strict));
    try std.testing.expect(canBeIdentifier("let", .strict));
    try std.testing.expect(canBeIdentifier("foo", .strict));
}

test "canBeIdentifier module" {
    try std.testing.expect(!canBeIdentifier("implements", .module));
    try std.testing.expect(!canBeIdentifier("enum", .module));
}

test "canBePropertyName" {
    try std.testing.expect(canBePropertyName("if"));
    try std.testing.expect(canBePropertyName("let"));
    try std.testing.expect(canBePropertyName("true"));
    try std.testing.expect(!canBePropertyName("foo"));
}

test "canBeLabel" {
    try std.testing.expect(!canBeLabel("if"));
    try std.testing.expect(!canBeLabel("true"));
    try std.testing.expect(canBeLabel("let"));
    try std.testing.expect(canBeLabel("loop"));
}

test "keywordToKind" {
    try std.testing.expectEqual(Kind.keyword_if, keywordToKind("if").?);
    try std.testing.expectEqual(Kind.keyword_return, keywordToKind("return").?);
    try std.testing.expect(keywordToKind("let") == null);
}

test "contextualToKind" {
    try std.testing.expectEqual(Kind.keyword_let, contextualToKind("let").?);
    try std.testing.expectEqual(Kind.keyword_async, contextualToKind("async").?);
    try std.testing.expect(contextualToKind("if") == null);
}

test "classify" {
    try std.testing.expectEqual(Kind.keyword_if, classify("if"));
    try std.testing.expectEqual(Kind.keyword_let, classify("let"));
    try std.testing.expectEqual(Kind.identifier, classify("foo"));
}

test "isEscapedKeyword" {
    try std.testing.expect(!isEscapedKeyword("if"));
    try std.testing.expect(isEscapedKeyword("\\u0069f"));
}

test "all reserved words count" {
    try std.testing.expectEqual(@as(usize, 36), reserved_words.len);
}

test "all contextual count" {
    try std.testing.expectEqual(@as(usize, 12), contextual_keywords.len);
}

test "all strict reserved count" {
    try std.testing.expectEqual(@as(usize, 6), strict_reserved.len);
}

test "KeywordSet init" {
    const set = KeywordSet.init();
    try std.testing.expectEqual(@as(u64, 0), set.bits);
}

test "KeywordSet fromContext normal" {
    const set = KeywordSet.fromContext(.normal);
    try std.testing.expect(set.contains(0));
}

test "KeywordSet fromContext strict" {
    const set = KeywordSet.fromContext(.strict);
    try std.testing.expect(set.contains(0));
    try std.testing.expect(set.contains(36));
}

test "KeywordSet contains" {
    var set = KeywordSet.init();
    set.bits = 0b1010;
    try std.testing.expect(set.contains(1));
    try std.testing.expect(!set.contains(0));
    try std.testing.expect(set.contains(3));
}
