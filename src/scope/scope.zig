const std = @import("std");
const value_mod = @import("../values/value.zig");
const binding_mod = @import("binding.zig");
const env_mod = @import("environment.zig");

pub const Value = value_mod.Value;
pub const Binding = binding_mod.Binding;
pub const BindingKind = binding_mod.BindingKind;
pub const Environment = env_mod.Environment;
pub const EnvironmentKind = env_mod.EnvironmentKind;

pub const ScopeType = enum(u8) {
    global,
    module,
    function,
    block,
    catch_clause,
    with_stmt,
    class_body,
    switch_body,
    for_body,
    for_in_body,
    for_of_body,

    pub fn toString(self: ScopeType) []const u8 {
        return @tagName(self);
    }

    pub fn toEnvironmentKind(self: ScopeType) EnvironmentKind {
        return switch (self) {
            .global => .global,
            .module => .module,
            .function => .function,
            .catch_clause => .catch_clause,
            .with_stmt => .with_stmt,
            .class_body => .class_body,
            else => .block,
        };
    }

    pub fn isFunctionBoundary(self: ScopeType) bool {
        return switch (self) {
            .global, .module, .function => true,
            else => false,
        };
    }

    pub fn isBlockScoped(self: ScopeType) bool {
        return !self.isFunctionBoundary();
    }
};

pub const Scope = struct {
    allocator: std.mem.Allocator,
    env: *Environment,
    scope_type: ScopeType,
    strict: bool,
    has_var_declarations: bool,
    has_lexical_declarations: bool,
    has_function_declarations: bool,
    has_direct_eval: bool,
    has_this_reference: bool,
    has_arguments_reference: bool,

    pub fn init(
        allocator: std.mem.Allocator,
        env: *Environment,
        scope_type: ScopeType,
    ) Scope {
        return .{
            .allocator = allocator,
            .env = env,
            .scope_type = scope_type,
            .strict = false,
            .has_var_declarations = false,
            .has_lexical_declarations = false,
            .has_function_declarations = false,
            .has_direct_eval = false,
            .has_this_reference = false,
            .has_arguments_reference = false,
        };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        scope_type: ScopeType,
        parent: ?*Environment,
    ) !Scope {
        const kind = scope_type.toEnvironmentKind();
        const env = try Environment.createWithParent(allocator, kind, parent);
        return Scope.init(allocator, env, scope_type);
    }

    pub fn deinit(self: *Scope) void {
        self.env.destroy();
    }

    pub fn getEnvironment(self: Scope) *Environment {
        return self.env;
    }

    pub fn getType(self: Scope) ScopeType {
        return self.scope_type;
    }

    pub fn getParentEnv(self: Scope) ?*Environment {
        return self.env.getParent();
    }

    pub fn isStrict(self: Scope) bool {
        return self.strict;
    }

    pub fn setStrict(self: *Scope, strict: bool) void {
        self.strict = strict;
    }

    pub fn hasVarDeclarations(self: Scope) bool {
        return self.has_var_declarations;
    }

    pub fn markVarDeclaration(self: *Scope) void {
        self.has_var_declarations = true;
    }

    pub fn hasLexicalDeclarations(self: Scope) bool {
        return self.has_lexical_declarations;
    }

    pub fn markLexicalDeclaration(self: *Scope) void {
        self.has_lexical_declarations = true;
    }

    pub fn hasFunctionDeclarations(self: Scope) bool {
        return self.has_function_declarations;
    }

    pub fn markFunctionDeclaration(self: *Scope) void {
        self.has_function_declarations = true;
    }

    pub fn hasDirectEval(self: Scope) bool {
        return self.has_direct_eval;
    }

    pub fn markDirectEval(self: *Scope) void {
        self.has_direct_eval = true;
    }

    pub fn hasThisReference(self: Scope) bool {
        return self.has_this_reference;
    }

    pub fn markThisReference(self: *Scope) void {
        self.has_this_reference = true;
    }

    pub fn hasArgumentsReference(self: Scope) bool {
        return self.has_arguments_reference;
    }

    pub fn markArgumentsReference(self: *Scope) void {
        self.has_arguments_reference = true;
    }

    pub fn declares(self: *Scope, name: []const u8, kind: BindingKind) !*Binding {
        switch (kind) {
            .var_, .function_decl => self.markVarDeclaration(),
            .let_, .const_, .class_decl => self.markLexicalDeclaration(),
            else => {},
        }
        return try self.env.declareOwn(name, kind);
    }

    pub fn declaresWithValue(
        self: *Scope,
        name: []const u8,
        kind: BindingKind,
        value: Value,
    ) !*Binding {
        const b = try self.declares(name, kind);
        b.forceSet(value);
        return b;
    }

    pub fn hasOwnBinding(self: Scope, name: []const u8) bool {
        return self.env.hasOwn(name);
    }

    pub fn resolve(self: Scope, name: []const u8) ?*Binding {
        return self.env.findBinding(name);
    }

    pub fn get(self: Scope, name: []const u8) !Value {
        return self.env.get(name);
    }

    pub fn set(self: Scope, name: []const u8, value: Value) !void {
        return self.env.set(name, value);
    }

    pub fn requiresOwnEnvironment(self: Scope) bool {
        if (self.has_lexical_declarations) return true;
        if (self.has_function_declarations) return true;
        if (self.has_direct_eval) return true;
        if (self.has_this_reference) return true;
        if (self.has_arguments_reference) return true;
        return false;
    }

    pub fn bindingCount(self: Scope) usize {
        return self.env.count();
    }

    pub fn depth(self: Scope) usize {
        return self.env.depth();
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    scope_type: ScopeType,
    parent: ?*Environment,
) !Scope {
    return Scope.create(allocator, scope_type, parent);
}

test "ScopeType toString" {
    try std.testing.expectEqualStrings("global", ScopeType.global.toString());
    try std.testing.expectEqualStrings("function", ScopeType.function.toString());
    try std.testing.expectEqualStrings("block", ScopeType.block.toString());
}

test "ScopeType toEnvironmentKind" {
    try std.testing.expectEqual(EnvironmentKind.global, ScopeType.global.toEnvironmentKind());
    try std.testing.expectEqual(EnvironmentKind.function, ScopeType.function.toEnvironmentKind());
    try std.testing.expectEqual(EnvironmentKind.block, ScopeType.block.toEnvironmentKind());
    try std.testing.expectEqual(EnvironmentKind.block, ScopeType.for_body.toEnvironmentKind());
}

test "ScopeType isFunctionBoundary" {
    try std.testing.expect(ScopeType.global.isFunctionBoundary());
    try std.testing.expect(ScopeType.function.isFunctionBoundary());
    try std.testing.expect(!ScopeType.block.isFunctionBoundary());
}

test "ScopeType isBlockScoped" {
    try std.testing.expect(ScopeType.block.isBlockScoped());
    try std.testing.expect(!ScopeType.global.isBlockScoped());
}

test "Scope create global" {
    var scope = try Scope.create(std.testing.allocator, .global, null);
    defer scope.deinit();

    try std.testing.expectEqual(ScopeType.global, scope.getType());
    try std.testing.expectEqual(@as(usize, 0), scope.bindingCount());
}

test "Scope create with parent" {
    var parent = try Scope.create(std.testing.allocator, .global, null);
    defer parent.deinit();

    var child = try Scope.create(std.testing.allocator, .function, parent.getEnvironment());
    defer child.deinit();

    try std.testing.expectEqual(parent.getEnvironment(), child.getParentEnv().?);
}

test "Scope strict flag" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    try std.testing.expect(!scope.isStrict());
    scope.setStrict(true);
    try std.testing.expect(scope.isStrict());
}

test "Scope declares var" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    _ = try scope.declares("x", .var_);
    try std.testing.expect(scope.hasOwnBinding("x"));
    try std.testing.expect(scope.hasVarDeclarations());
}

test "Scope declares let" {
    var scope = try Scope.create(std.testing.allocator, .block, null);
    defer scope.deinit();

    _ = try scope.declares("x", .let_);
    try std.testing.expect(scope.hasLexicalDeclarations());
}

test "Scope declares function" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    _ = try scope.declares("foo", .function_decl);
    try std.testing.expect(scope.hasVarDeclarations());
}

test "Scope declares const" {
    var scope = try Scope.create(std.testing.allocator, .block, null);
    defer scope.deinit();

    _ = try scope.declares("x", .const_);
    try std.testing.expect(scope.hasLexicalDeclarations());
}

test "Scope declaresWithValue" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    _ = try scope.declaresWithValue("x", .const_, Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), (try scope.get("x")).asNumber().?);
}

test "Scope resolve walks chain" {
    var parent = try Scope.create(std.testing.allocator, .function, null);
    defer parent.deinit();
    _ = try parent.declaresWithValue("x", .let_, Value.fromNumber(42.0));

    var child = try Scope.create(std.testing.allocator, .block, parent.getEnvironment());
    defer child.deinit();

    const b = child.resolve("x").?;
    try std.testing.expectEqual(@as(f64, 42.0), b.getValue().asNumber().?);
}

test "Scope set in parent" {
    var parent = try Scope.create(std.testing.allocator, .function, null);
    defer parent.deinit();
    _ = try parent.declaresWithValue("x", .var_, Value.fromNumber(1.0));

    var child = try Scope.create(std.testing.allocator, .block, parent.getEnvironment());
    defer child.deinit();

    try child.set("x", Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), (try parent.get("x")).asNumber().?);
}

test "Scope marks eval" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    try std.testing.expect(!scope.hasDirectEval());
    scope.markDirectEval();
    try std.testing.expect(scope.hasDirectEval());
}

test "Scope marks this" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    try std.testing.expect(!scope.hasThisReference());
    scope.markThisReference();
    try std.testing.expect(scope.hasThisReference());
}

test "Scope marks arguments" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    try std.testing.expect(!scope.hasArgumentsReference());
    scope.markArgumentsReference();
    try std.testing.expect(scope.hasArgumentsReference());
}

test "Scope requiresOwnEnvironment" {
    var scope = try Scope.create(std.testing.allocator, .function, null);
    defer scope.deinit();

    try std.testing.expect(!scope.requiresOwnEnvironment());
    scope.markDirectEval();
    try std.testing.expect(scope.requiresOwnEnvironment());
}

test "Scope depth" {
    var a = try Scope.create(std.testing.allocator, .global, null);
    defer a.deinit();

    var b = try Scope.create(std.testing.allocator, .function, a.getEnvironment());
    defer b.deinit();

    try std.testing.expectEqual(@as(usize, 0), a.depth());
    try std.testing.expectEqual(@as(usize, 1), b.depth());
}

test "create helper" {
    var scope = try create(std.testing.allocator, .block, null);
    defer scope.deinit();
    try std.testing.expectEqual(ScopeType.block, scope.getType());
}
