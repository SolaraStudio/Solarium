const std = @import("std");
const token = @import("../lexer/token.zig");
const ast = @import("ast.zig");

pub const Kind = token.Kind;
pub const Token = token.Token;
pub const NodeId = ast.NodeId;
pub const NO_NODE = ast.NO_NODE;
pub const NodeTag = ast.NodeTag;
pub const Data = ast.Data;
pub const Span = ast.Span;
pub const Position = ast.Position;

pub const StatementTag = enum(u8) {
    block,
    empty,
    expression,
    if_,
    while_,
    do_while,
    for_,
    for_in,
    for_of,
    return_,
    break_,
    continue_,
    switch_,
    try_,
    throw_,
    labeled,
    with_,
    debugger_,
    variable,
    function_decl,
    class_decl,
    import_,
    export_,
    expression_statement,

    pub fn toString(self: StatementTag) []const u8 {
        return @tagName(self);
    }

    pub fn isDeclaration(self: StatementTag) bool {
        return switch (self) {
            .variable, .function_decl, .class_decl, .import_, .export_ => true,
            else => false,
        };
    }

    pub fn isIteration(self: StatementTag) bool {
        return switch (self) {
            .while_, .do_while, .for_, .for_in, .for_of => true,
            else => false,
        };
    }

    pub fn isJump(self: StatementTag) bool {
        return switch (self) {
            .return_, .break_, .continue_ => true,
            else => false,
        };
    }

    pub fn isBlock(self: StatementTag) bool {
        return self == .block;
    }

    pub fn canBeLabelled(self: StatementTag) bool {
        return switch (self) {
            .block, .empty, .expression, .if_, .while_, .do_while, .for_, .for_in, .for_of, .switch_, .try_, .with_, .debugger_ => true,
            else => false,
        };
    }
};

pub const StatementKind = enum(u8) {
    normal,
    declaration,
    hoistable,
    lexical,
    module_only,
    block_scoped,

    pub fn toString(self: StatementKind) []const u8 {
        return @tagName(self);
    }
};

pub fn classifyStatement(tag: StatementTag) StatementKind {
    return switch (tag) {
        .variable => .lexical,
        .function_decl => .hoistable,
        .class_decl => .block_scoped,
        .import_, .export_ => .module_only,
        else => .normal,
    };
}

pub const StatementInfo = struct {
    tag: StatementTag,
    kind: StatementKind,
    is_declaration: bool,
    is_hoistable: bool,
    is_module_only: bool,

    pub fn init(tag: StatementTag) StatementInfo {
        const kind = classifyStatement(tag);
        return .{
            .tag = tag,
            .kind = kind,
            .is_declaration = tag.isDeclaration(),
            .is_hoistable = kind == .hoistable,
            .is_module_only = kind == .module_only,
        };
    }
};

pub const LoopKind = enum(u8) {
    while_,
    do_while,
    for_,
    for_in,
    for_of,

    pub fn toString(self: LoopKind) []const u8 {
        return @tagName(self);
    }

    pub fn hasCondition(self: LoopKind) bool {
        return switch (self) {
            .while_, .for_ => true,
            else => false,
        };
    }

    pub fn hasBody(self: LoopKind) bool {
        _ = self;
        return true;
    }
};

pub const JumpKind = enum(u8) {
    return_,
    break_,
    continue_,

    pub fn toString(self: JumpKind) []const u8 {
        return @tagName(self);
    }

    pub fn requiresLabel(self: JumpKind) bool {
        _ = self;
        return false;
    }

    pub fn canHaveLabel(self: JumpKind) bool {
        return self != .return_;
    }
};

pub fn isStatementKind(kind: Kind) bool {
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

pub fn isLoopKind(kind: Kind) bool {
    return switch (kind) {
        .keyword_while,
        .keyword_do,
        .keyword_for,
        => true,
        else => false,
    };
}

pub fn isJumpKind(kind: Kind) bool {
    return switch (kind) {
        .keyword_return,
        .keyword_break,
        .keyword_continue,
        => true,
        else => false,
    };
}

pub fn isBlockKind(kind: Kind) bool {
    return kind == .punct_lbrace;
}

pub fn isDeclarationKind(kind: Kind) bool {
    return switch (kind) {
        .keyword_var,
        .keyword_let,
        .keyword_const,
        .keyword_function,
        .keyword_class,
        => true,
        else => false,
    };
}

pub fn isModuleKind(kind: Kind) bool {
    return switch (kind) {
        .keyword_import, .keyword_export => true,
        else => false,
    };
}

test "StatementTag toString" {
    try std.testing.expectEqualStrings("block", StatementTag.block.toString());
    try std.testing.expectEqualStrings("if_", StatementTag.if_.toString());
}

test "StatementTag isDeclaration" {
    try std.testing.expect(StatementTag.variable.isDeclaration());
    try std.testing.expect(StatementTag.function_decl.isDeclaration());
    try std.testing.expect(!StatementTag.block.isDeclaration());
}

test "StatementTag isIteration" {
    try std.testing.expect(StatementTag.while_.isIteration());
    try std.testing.expect(StatementTag.for_of.isIteration());
    try std.testing.expect(!StatementTag.if_.isIteration());
}

test "StatementTag isJump" {
    try std.testing.expect(StatementTag.return_.isJump());
    try std.testing.expect(StatementTag.break_.isJump());
    try std.testing.expect(!StatementTag.block.isJump());
}

test "StatementTag canBeLabelled" {
    try std.testing.expect(StatementTag.block.canBeLabelled());
    try std.testing.expect(StatementTag.for_.canBeLabelled());
    try std.testing.expect(!StatementTag.function_decl.canBeLabelled());
}

test "StatementKind toString" {
    try std.testing.expectEqualStrings("normal", StatementKind.normal.toString());
    try std.testing.expectEqualStrings("hoistable", StatementKind.hoistable.toString());
}

test "classifyStatement" {
    try std.testing.expectEqual(StatementKind.hoistable, classifyStatement(.function_decl));
    try std.testing.expectEqual(StatementKind.lexical, classifyStatement(.variable));
    try std.testing.expectEqual(StatementKind.block_scoped, classifyStatement(.class_decl));
    try std.testing.expectEqual(StatementKind.module_only, classifyStatement(.import_));
    try std.testing.expectEqual(StatementKind.normal, classifyStatement(.if_));
}

test "StatementInfo init" {
    const info = StatementInfo.init(.function_decl);
    try std.testing.expect(info.is_declaration);
    try std.testing.expect(info.is_hoistable);
    try std.testing.expect(!info.is_module_only);
}

test "StatementInfo module" {
    const info = StatementInfo.init(.import_);
    try std.testing.expect(info.is_module_only);
    try std.testing.expect(info.is_declaration);
}

test "LoopKind toString" {
    try std.testing.expectEqualStrings("while_", LoopKind.while_.toString());
    try std.testing.expectEqualStrings("for_of", LoopKind.for_of.toString());
}

test "LoopKind hasCondition" {
    try std.testing.expect(LoopKind.while_.hasCondition());
    try std.testing.expect(LoopKind.for_.hasCondition());
    try std.testing.expect(!LoopKind.do_while.hasCondition());
}

test "JumpKind toString" {
    try std.testing.expectEqualStrings("return_", JumpKind.return_.toString());
    try std.testing.expectEqualStrings("break_", JumpKind.break_.toString());
}

test "JumpKind canHaveLabel" {
    try std.testing.expect(!JumpKind.return_.canHaveLabel());
    try std.testing.expect(JumpKind.break_.canHaveLabel());
    try std.testing.expect(JumpKind.continue_.canHaveLabel());
}

test "isStatementKind" {
    try std.testing.expect(isStatementKind(.keyword_if));
    try std.testing.expect(isStatementKind(.punct_lbrace));
    try std.testing.expect(isStatementKind(.keyword_for));
    try std.testing.expect(!isStatementKind(.op_add));
}

test "isLoopKind" {
    try std.testing.expect(isLoopKind(.keyword_while));
    try std.testing.expect(isLoopKind(.keyword_for));
    try std.testing.expect(!isLoopKind(.keyword_if));
}

test "isJumpKind" {
    try std.testing.expect(isJumpKind(.keyword_return));
    try std.testing.expect(isJumpKind(.keyword_break));
    try std.testing.expect(!isJumpKind(.keyword_if));
}

test "isBlockKind" {
    try std.testing.expect(isBlockKind(.punct_lbrace));
    try std.testing.expect(!isBlockKind(.punct_lparen));
}

test "isDeclarationKind" {
    try std.testing.expect(isDeclarationKind(.keyword_var));
    try std.testing.expect(isDeclarationKind(.keyword_let));
    try std.testing.expect(isDeclarationKind(.keyword_const));
    try std.testing.expect(isDeclarationKind(.keyword_function));
    try std.testing.expect(!isDeclarationKind(.keyword_if));
}

test "isModuleKind" {
    try std.testing.expect(isModuleKind(.keyword_import));
    try std.testing.expect(isModuleKind(.keyword_export));
    try std.testing.expect(!isModuleKind(.keyword_if));
}
