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

pub const FunctionKind = ast.FunctionKind;
pub const VariableKind = ast.VariableKind;

pub const DeclarationTag = enum(u8) {
    variable,
    function,
    class_,
    import_,
    export_,

    pub fn toString(self: DeclarationTag) []const u8 {
        return @tagName(self);
    }

    pub fn isLexical(self: DeclarationTag) bool {
        return self == .variable;
    }

    pub fn isHoistable(self: DeclarationTag) bool {
        return self == .function;
    }

    pub fn isModule(self: DeclarationTag) bool {
        return self == .import_ or self == .export_;
    }

    pub fn isClass(self: DeclarationTag) bool {
        return self == .class_;
    }
};

pub const FunctionFlag = enum(u8) {
    strict,
    is_async,
    is_generator,
    is_arrow,
    is_method,
    is_constructor,
    is_getter,
    is_setter,
    has_simple_params,
    has_rest_param,
    is_anonymous,

    pub fn toString(self: FunctionFlag) []const u8 {
        return @tagName(self);
    }
};

pub const FunctionFlags = std.EnumSet(FunctionFlag);

pub const FunctionInfo = struct {
    name: []const u8,
    arity: u32,
    kind: FunctionKind,
    flags: FunctionFlags,

    pub fn init(name: []const u8, arity: u32, kind: FunctionKind) FunctionInfo {
        return .{
            .name = name,
            .arity = arity,
            .kind = kind,
            .flags = FunctionFlags.initEmpty(),
        };
    }

    pub fn isAsync(self: FunctionInfo) bool {
        return self.flags.contains(.is_async);
    }

    pub fn isGenerator(self: FunctionInfo) bool {
        return self.flags.contains(.is_generator);
    }

    pub fn isStrict(self: FunctionInfo) bool {
        return self.flags.contains(.strict);
    }

    pub fn isAnonymous(self: FunctionInfo) bool {
        return self.flags.contains(.is_anonymous);
    }
};

pub const ClassInfo = struct {
    name: []const u8,
    has_super: bool,
    is_expression: bool,
    is_declaration: bool,

    pub fn init(name: []const u8) ClassInfo {
        return .{
            .name = name,
            .has_super = false,
            .is_expression = false,
            .is_declaration = false,
        };
    }

    pub fn withSuper(self: ClassInfo) ClassInfo {
        var c = self;
        c.has_super = true;
        return c;
    }

    pub fn asExpression(self: ClassInfo) ClassInfo {
        var c = self;
        c.is_expression = true;
        return c;
    }
};

pub const VariableInfo = struct {
    kind: VariableKind,
    name: []const u8,
    has_initializer: bool,

    pub fn init(kind: VariableKind, name: []const u8) VariableInfo {
        return .{
            .kind = kind,
            .name = name,
            .has_initializer = false,
        };
    }

    pub fn withInitializer(self: VariableInfo) VariableInfo {
        var v = self;
        v.has_initializer = true;
        return v;
    }

    pub fn isConst(self: VariableInfo) bool {
        return self.kind == .const_;
    }

    pub fn requiresInitializer(self: VariableInfo) bool {
        return self.kind == .const_;
    }
};

pub const ImportKind = enum(u8) {
    default_,
    namespace,
    named,
    side_effect,

    pub fn toString(self: ImportKind) []const u8 {
        return @tagName(self);
    }

    pub fn hasBindings(self: ImportKind) bool {
        return self != .side_effect;
    }
};

pub const ExportKind = enum(u8) {
    named,
    default_,
    all,

    pub fn toString(self: ExportKind) []const u8 {
        return @tagName(self);
    }

    pub fn isNamed(self: ExportKind) bool {
        return self == .named;
    }

    pub fn isDefault(self: ExportKind) bool {
        return self == .default_;
    }

    pub fn isReExport(self: ExportKind) bool {
        return self == .all;
    }
};

pub fn isDeclarationStart(kind: Kind) bool {
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

pub fn isFunctionKind(kind: Kind) bool {
    return kind == .keyword_function;
}

pub fn isClassKind(kind: Kind) bool {
    return kind == .keyword_class;
}

pub fn isVariableKind(kind: Kind) bool {
    return switch (kind) {
        .keyword_var, .keyword_let, .keyword_const => true,
        else => false,
    };
}

pub fn toVariableKind(kind: Kind) ?VariableKind {
    return switch (kind) {
        .keyword_var => .var_,
        .keyword_let => .let_,
        .keyword_const => .const_,
        else => null,
    };
}

pub fn isModuleKind(kind: Kind) bool {
    return kind == .keyword_import or kind == .keyword_export;
}

pub fn isAsyncKeyword(t: Token) bool {
    return t.kind == .keyword_async;
}

pub fn isGeneratorStar(t: Token) bool {
    return t.kind == .op_mul;
}

pub fn countParameters(params: []const NodeId) u32 {
    var count: u32 = 0;
    for (params) |p| {
        if (p != NO_NODE) count += 1;
    }
    return count;
}

pub fn hasRestParameter(params: []const NodeId, ast_ref: *ast.Ast) bool {
    for (params) |p| {
        if (p == NO_NODE) continue;
        const node = ast_ref.get(p);
        if (node.tag == .parameter) {
            if (node.data.parameter.rest) return true;
        }
    }
    return false;
}

pub fn parametersBeforeFirstDefault(params: []const NodeId, ast_ref: *ast.Ast) u32 {
    var count: u32 = 0;
    for (params) |p| {
        if (p == NO_NODE) continue;
        const node = ast_ref.get(p);
        if (node.tag == .parameter) {
            if (node.data.parameter.default_value != NO_NODE) break;
            if (node.data.parameter.rest) break;
            count += 1;
        }
    }
    return count;
}

test "DeclarationTag toString" {
    try std.testing.expectEqualStrings("variable", DeclarationTag.variable.toString());
    try std.testing.expectEqualStrings("function", DeclarationTag.function.toString());
}

test "DeclarationTag isLexical" {
    try std.testing.expect(DeclarationTag.variable.isLexical());
    try std.testing.expect(!DeclarationTag.function.isLexical());
}

test "DeclarationTag isHoistable" {
    try std.testing.expect(DeclarationTag.function.isHoistable());
    try std.testing.expect(!DeclarationTag.variable.isHoistable());
}

test "DeclarationTag isModule" {
    try std.testing.expect(DeclarationTag.import_.isModule());
    try std.testing.expect(DeclarationTag.export_.isModule());
    try std.testing.expect(!DeclarationTag.variable.isModule());
}

test "FunctionFlag toString" {
    try std.testing.expectEqualStrings("strict", FunctionFlag.strict.toString());
    try std.testing.expectEqualStrings("is_async", FunctionFlag.is_async.toString());
}

test "FunctionInfo init" {
    const fi = FunctionInfo.init("foo", 2, .normal);
    try std.testing.expectEqualStrings("foo", fi.name);
    try std.testing.expectEqual(@as(u32, 2), fi.arity);
    try std.testing.expect(!fi.isAsync());
    try std.testing.expect(!fi.isGenerator());
}

test "FunctionInfo isAsync" {
    var fi = FunctionInfo.init("foo", 0, .async);
    fi.flags.insert(.is_async);
    try std.testing.expect(fi.isAsync());
}

test "FunctionInfo isGenerator" {
    var fi = FunctionInfo.init("foo", 0, .generator);
    fi.flags.insert(.is_generator);
    try std.testing.expect(fi.isGenerator());
}

test "ClassInfo init" {
    const ci = ClassInfo.init("Foo");
    try std.testing.expectEqualStrings("Foo", ci.name);
    try std.testing.expect(!ci.has_super);
}

test "ClassInfo withSuper" {
    const ci = ClassInfo.init("Foo").withSuper();
    try std.testing.expect(ci.has_super);
}

test "ClassInfo asExpression" {
    const ci = ClassInfo.init("Foo").asExpression();
    try std.testing.expect(ci.is_expression);
}

test "VariableInfo init" {
    const vi = VariableInfo.init(.let_, "x");
    try std.testing.expect(!vi.has_initializer);
    try std.testing.expect(!vi.isConst());
}

test "VariableInfo const" {
    const vi = VariableInfo.init(.const_, "x");
    try std.testing.expect(vi.isConst());
    try std.testing.expect(vi.requiresInitializer());
}

test "VariableInfo withInitializer" {
    const vi = VariableInfo.init(.let_, "x").withInitializer();
    try std.testing.expect(vi.has_initializer);
}

test "ImportKind toString" {
    try std.testing.expectEqualStrings("default_", ImportKind.default_.toString());
    try std.testing.expectEqualStrings("side_effect", ImportKind.side_effect.toString());
}

test "ImportKind hasBindings" {
    try std.testing.expect(ImportKind.default_.hasBindings());
    try std.testing.expect(!ImportKind.side_effect.hasBindings());
}

test "ExportKind toString" {
    try std.testing.expectEqualStrings("named", ExportKind.named.toString());
    try std.testing.expectEqualStrings("default_", ExportKind.default_.toString());
    try std.testing.expectEqualStrings("all", ExportKind.all.toString());
}

test "isDeclarationStart" {
    try std.testing.expect(isDeclarationStart(.keyword_var));
    try std.testing.expect(isDeclarationStart(.keyword_function));
    try std.testing.expect(isDeclarationStart(.keyword_class));
    try std.testing.expect(!isDeclarationStart(.keyword_if));
}

test "isFunctionKind" {
    try std.testing.expect(isFunctionKind(.keyword_function));
    try std.testing.expect(!isFunctionKind(.keyword_class));
}

test "isClassKind" {
    try std.testing.expect(isClassKind(.keyword_class));
    try std.testing.expect(!isClassKind(.keyword_function));
}

test "isVariableKind" {
    try std.testing.expect(isVariableKind(.keyword_var));
    try std.testing.expect(isVariableKind(.keyword_let));
    try std.testing.expect(isVariableKind(.keyword_const));
    try std.testing.expect(!isVariableKind(.keyword_function));
}

test "toVariableKind" {
    try std.testing.expectEqual(VariableKind.var_, toVariableKind(.keyword_var).?);
    try std.testing.expectEqual(VariableKind.let_, toVariableKind(.keyword_let).?);
    try std.testing.expectEqual(VariableKind.const_, toVariableKind(.keyword_const).?);
    try std.testing.expectEqual(@as(?VariableKind, null), toVariableKind(.keyword_if));
}

test "isModuleKind" {
    try std.testing.expect(isModuleKind(.keyword_import));
    try std.testing.expect(isModuleKind(.keyword_export));
    try std.testing.expect(!isModuleKind(.keyword_if));
}

test "countParameters" {
    const params = [_]NodeId{ 1, 2, 3 };
    try std.testing.expectEqual(@as(u32, 3), countParameters(&params));
}

test "countParameters with NO_NODE" {
    const params = [_]NodeId{ 1, NO_NODE, 3 };
    try std.testing.expectEqual(@as(u32, 2), countParameters(&params));
}
