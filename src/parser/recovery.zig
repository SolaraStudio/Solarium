const std = @import("std");
const token = @import("../lexer/token.zig");
const error_mod = @import("error.zig");

pub const Kind = token.Kind;
pub const Token = token.Token;
pub const ParseError = error_mod.ParseError;
pub const ParseErrorCode = error_mod.ParseErrorCode;
pub const ErrorList = error_mod.ErrorList;
pub const RecoveryMode = error_mod.RecoveryMode;

pub const RecoveryResult = struct {
    skipped: usize,
    found_sync: bool,
    consumed_current: bool,

    pub fn init() RecoveryResult {
        return .{ .skipped = 0, .found_sync = false, .consumed_current = false };
    }
};

pub const MAX_SKIP: usize = 1000;

pub const SynchronizationSet = struct {
    stop_kinds: []const Kind,

    pub fn init(kinds: []const Kind) SynchronizationSet {
        return .{ .stop_kinds = kinds };
    }

    pub fn contains(self: SynchronizationSet, kind: Kind) bool {
        for (self.stop_kinds) |k| {
            if (k == kind) return true;
        }
        return false;
    }

    pub fn statementSynchronization() SynchronizationSet {
        return .{ .stop_kinds = &STATEMENT_SYNC };
    }

    pub fn declarationSynchronization() SynchronizationSet {
        return .{ .stop_kinds = &DECLARATION_SYNC };
    }

    pub fn expressionSynchronization() SynchronizationSet {
        return .{ .stop_kinds = &EXPRESSION_SYNC };
    }
};

pub const STATEMENT_SYNC = [_]Kind{
    .punct_semicolon,
    .punct_rbrace,
    .keyword_if,
    .keyword_while,
    .keyword_do,
    .keyword_for,
    .keyword_return,
    .keyword_break,
    .keyword_continue,
    .keyword_switch,
    .keyword_try,
    .keyword_throw,
    .keyword_function,
    .keyword_class,
    .keyword_var,
    .keyword_let,
    .keyword_const,
    .keyword_import,
    .keyword_export,
    .eof,
};

pub const DECLARATION_SYNC = [_]Kind{
    .keyword_function,
    .keyword_class,
    .keyword_var,
    .keyword_let,
    .keyword_const,
    .keyword_import,
    .keyword_export,
    .punct_rbrace,
    .eof,
};

pub const EXPRESSION_SYNC = [_]Kind{
    .punct_semicolon,
    .punct_comma,
    .punct_rparen,
    .punct_rbracket,
    .punct_rbrace,
    .op_assign,
    .punct_arrow,
    .eof,
};

pub fn isStatementSync(kind: Kind) bool {
    for (STATEMENT_SYNC) |k| {
        if (k == kind) return true;
    }
    return false;
}

pub fn isDeclarationSync(kind: Kind) bool {
    for (DECLARATION_SYNC) |k| {
        if (k == kind) return true;
    }
    return false;
}

pub fn isExpressionSync(kind: Kind) bool {
    for (EXPRESSION_SYNC) |k| {
        if (k == kind) return true;
    }
    return false;
}

pub fn findSynchronization(
    tokens: []const Token,
    start: usize,
    sync_set: SynchronizationSet,
) RecoveryResult {
    var result = RecoveryResult.init();
    var i = start;

    while (i < tokens.len) : (i += 1) {
        if (result.skipped >= MAX_SKIP) break;

        const kind = tokens[i].kind;

        if (kind == .eof) {
            result.found_sync = true;
            break;
        }

        if (sync_set.contains(kind)) {
            result.found_sync = true;
            break;
        }

        result.skipped += 1;
    }

    return result;
}

pub fn skipUntilSync(
    tokens: []const Token,
    pos: *usize,
    sync_set: SynchronizationSet,
) RecoveryResult {
    const result = findSynchronization(tokens, pos.*, sync_set);
    pos.* += result.skipped;
    return result;
}

pub fn skipToStatementStart(tokens: []const Token, pos: *usize) RecoveryResult {
    const sync = SynchronizationSet.statementSynchronization();
    var result = skipUntilSync(tokens, pos, sync);

    if (pos.* < tokens.len) {
        const kind = tokens[pos.*].kind;
        if (kind == .punct_semicolon) {
            pos.* += 1;
            result.consumed_current = true;
        }
    }

    return result;
}

pub fn skipToDeclarationStart(tokens: []const Token, pos: *usize) RecoveryResult {
    const sync = SynchronizationSet.declarationSynchronization();
    return skipUntilSync(tokens, pos, sync);
}

pub fn skipToExpressionEnd(tokens: []const Token, pos: *usize) RecoveryResult {
    const sync = SynchronizationSet.expressionSynchronization();
    return skipUntilSync(tokens, pos, sync);
}

pub fn isRecoveryPoint(kind: Kind) bool {
    return switch (kind) {
        .punct_semicolon,
        .punct_rbrace,
        .keyword_function,
        .keyword_class,
        .keyword_var,
        .keyword_let,
        .keyword_const,
        .eof,
        => true,
        else => false,
    };
}

pub fn canStartStatement(kind: Kind) bool {
    return switch (kind) {
        .punct_lbrace,
        .punct_semicolon,
        .keyword_if,
        .keyword_while,
        .keyword_do,
        .keyword_for,
        .keyword_return,
        .keyword_break,
        .keyword_continue,
        .keyword_switch,
        .keyword_try,
        .keyword_throw,
        .keyword_with,
        .keyword_debugger,
        .keyword_var,
        .keyword_let,
        .keyword_const,
        .keyword_function,
        .keyword_class,
        .keyword_import,
        .keyword_export,
        => true,
        else => false,
    };
}

pub fn canStartDeclaration(kind: Kind) bool {
    return switch (kind) {
        .keyword_var,
        .keyword_let,
        .keyword_const,
        .keyword_function,
        .keyword_class,
        .keyword_import,
        .keyword_export,
        => true,
        else => false,
    };
}

pub fn canEndExpression(kind: Kind) bool {
    return switch (kind) {
        .punct_semicolon,
        .punct_comma,
        .punct_rparen,
        .punct_rbracket,
        .punct_rbrace,
        .punct_colon,
        .eof,
        => true,
        else => false,
    };
}

test "RecoveryResult init" {
    const r = RecoveryResult.init();
    try std.testing.expectEqual(@as(usize, 0), r.skipped);
    try std.testing.expect(!r.found_sync);
}

test "SynchronizationSet contains" {
    const set = SynchronizationSet.init(&STATEMENT_SYNC);
    try std.testing.expect(set.contains(.punct_semicolon));
    try std.testing.expect(set.contains(.keyword_if));
    try std.testing.expect(!set.contains(.op_add));
}

test "statementSynchronization" {
    const set = SynchronizationSet.statementSynchronization();
    try std.testing.expect(set.contains(.keyword_function));
}

test "declarationSynchronization" {
    const set = SynchronizationSet.declarationSynchronization();
    try std.testing.expect(set.contains(.keyword_function));
    try std.testing.expect(!set.contains(.keyword_if));
}

test "expressionSynchronization" {
    const set = SynchronizationSet.expressionSynchronization();
    try std.testing.expect(set.contains(.punct_rparen));
    try std.testing.expect(set.contains(.punct_semicolon));
}

test "isStatementSync" {
    try std.testing.expect(isStatementSync(.keyword_if));
    try std.testing.expect(isStatementSync(.keyword_for));
    try std.testing.expect(isStatementSync(.punct_semicolon));
    try std.testing.expect(!isStatementSync(.op_add));
}

test "isDeclarationSync" {
    try std.testing.expect(isDeclarationSync(.keyword_function));
    try std.testing.expect(isDeclarationSync(.keyword_var));
    try std.testing.expect(!isDeclarationSync(.keyword_if));
}

test "isExpressionSync" {
    try std.testing.expect(isExpressionSync(.punct_rparen));
    try std.testing.expect(isExpressionSync(.punct_semicolon));
    try std.testing.expect(!isExpressionSync(.identifier));
}

test "findSynchronization finds statement keyword" {
    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .keyword_if, .text = "if", .line = 1, .column = 3, .offset = 2 },
    };
    const sync = SynchronizationSet.statementSynchronization();
    const r = findSynchronization(&toks, 0, sync);
    try std.testing.expect(r.found_sync);
    try std.testing.expectEqual(@as(usize, 2), r.skipped);
}

test "findSynchronization hits eof" {
    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .eof, .text = "", .line = 1, .column = 2, .offset = 1 },
    };
    const sync = SynchronizationSet.statementSynchronization();
    const r = findSynchronization(&toks, 0, sync);
    try std.testing.expect(r.found_sync);
    try std.testing.expectEqual(@as(usize, 1), r.skipped);
}

test "skipUntilSync updates pos" {
    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .keyword_if, .text = "if", .line = 1, .column = 2, .offset = 1 },
    };
    const sync = SynchronizationSet.statementSynchronization();
    var pos: usize = 0;
    _ = skipUntilSync(&toks, &pos, sync);
    try std.testing.expectEqual(@as(usize, 1), pos);
}

test "skipToStatementStart consumes semicolon" {
    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .punct_semicolon, .text = ";", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .keyword_if, .text = "if", .line = 1, .column = 3, .offset = 2 },
    };
    var pos: usize = 0;
    _ = skipToStatementStart(&toks, &pos);
    try std.testing.expectEqual(@as(usize, 2), pos);
}

test "skipToDeclarationStart" {
    const toks = [_]Token{
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .keyword_function, .text = "function", .line = 1, .column = 2, .offset = 1 },
    };
    var pos: usize = 0;
    _ = skipToDeclarationStart(&toks, &pos);
    try std.testing.expectEqual(@as(usize, 1), pos);
}

test "skipToExpressionEnd" {
    const toks = [_]Token{
        .{ .kind = .identifier, .text = "x", .line = 1, .column = 1, .offset = 0 },
        .{ .kind = .op_add, .text = "+", .line = 1, .column = 2, .offset = 1 },
        .{ .kind = .punct_rparen, .text = ")", .line = 1, .column = 3, .offset = 2 },
    };
    var pos: usize = 0;
    _ = skipToExpressionEnd(&toks, &pos);
    try std.testing.expectEqual(@as(usize, 2), pos);
}

test "isRecoveryPoint" {
    try std.testing.expect(isRecoveryPoint(.punct_semicolon));
    try std.testing.expect(isRecoveryPoint(.keyword_function));
    try std.testing.expect(!isRecoveryPoint(.op_add));
}

test "canStartStatement" {
    try std.testing.expect(canStartStatement(.keyword_if));
    try std.testing.expect(canStartStatement(.keyword_var));
    try std.testing.expect(!canStartStatement(.op_add));
}

test "canStartDeclaration" {
    try std.testing.expect(canStartDeclaration(.keyword_var));
    try std.testing.expect(canStartDeclaration(.keyword_function));
    try std.testing.expect(!canStartDeclaration(.keyword_if));
}

test "canEndExpression" {
    try std.testing.expect(canEndExpression(.punct_semicolon));
    try std.testing.expect(canEndExpression(.punct_rparen));
    try std.testing.expect(!canEndExpression(.op_add));
}

test "MAX_SKIP is finite" {
    try std.testing.expect(MAX_SKIP > 0);
    try std.testing.expect(MAX_SKIP < 100000);
}

test "RecoveryMode toString" {
    try std.testing.expectEqualStrings("statement", RecoveryMode.statement.toString());
    try std.testing.expectEqualStrings("expression", RecoveryMode.expression.toString());
    try std.testing.expectEqualStrings("block", RecoveryMode.block.toString());
}
