const std = @import("std");
const value_mod = @import("../values/value.zig");
const binding_mod = @import("binding.zig");
const env_mod = @import("environment.zig");

pub const Value = value_mod.Value;
pub const Binding = binding_mod.Binding;
pub const BindingKind = binding_mod.BindingKind;
pub const Environment = env_mod.Environment;

pub const Declaration = struct {
    name: []const u8,
    kind: BindingKind,
    initialized: bool,
    is_function: bool,

    pub fn init(name: []const u8, kind: BindingKind) Declaration {
        return .{
            .name = name,
            .kind = kind,
            .initialized = kind == .function_decl or kind == .var_,
            .is_function = kind == .function_decl,
        };
    }

    pub fn withFunction(name: []const u8) Declaration {
        return .{
            .name = name,
            .kind = .function_decl,
            .initialized = true,
            .is_function = true,
        };
    }

    pub fn hasTDZ(self: Declaration) bool {
        return !self.initialized and self.kind.hasTDZ();
    }
};

pub const DeclarationList = struct {
    allocator: std.mem.Allocator,
    decls: std.ArrayList(Declaration),

    pub fn init(allocator: std.mem.Allocator) DeclarationList {
        return .{
            .allocator = allocator,
            .decls = .empty,
        };
    }

    pub fn deinit(self: *DeclarationList) void {
        self.decls.deinit(self.allocator);
    }

    pub fn add(self: *DeclarationList, d: Declaration) !void {
        try self.decls.append(self.allocator, d);
    }

    pub fn count(self: DeclarationList) usize {
        return self.decls.items.len;
    }

    pub fn contains(self: DeclarationList, name: []const u8) bool {
        for (self.decls.items) |d| {
            if (std.mem.eql(u8, d.name, name)) return true;
        }
        return false;
    }

    pub fn find(self: DeclarationList, name: []const u8) ?Declaration {
        for (self.decls.items) |d| {
            if (std.mem.eql(u8, d.name, name)) return d;
        }
        return null;
    }
};

pub const HoistResult = struct {
    var_count: usize,
    let_count: usize,
    const_count: usize,
    function_count: usize,

    pub fn init() HoistResult {
        return .{
            .var_count = 0,
            .let_count = 0,
            .const_count = 0,
            .function_count = 0,
        };
    }

    pub fn total(self: HoistResult) usize {
        return self.var_count + self.let_count +
            self.const_count + self.function_count;
    }
};

pub fn classifyVar(kind: BindingKind) HoistResult {
    var r = HoistResult.init();
    switch (kind) {
        .var_ => r.var_count = 1,
        .let_ => r.let_count = 1,
        .const_ => r.const_count = 1,
        .function_decl => r.function_count = 1,
        else => {},
    }
    return r;
}

pub fn applyVarHoisting(
    env: *Environment,
    declarations: []const Declaration,
) !HoistResult {
    var result = HoistResult.init();

    for (declarations) |d| {
        if (d.kind != .var_ and d.kind != .function_decl) continue;

        if (env.hasOwn(d.name)) continue;

        const b = try env.declareOwn(d.name, d.kind);
        if (d.kind == .function_decl) {
            b.forceSet(Value.UNDEFINED);
            result.function_count += 1;
        } else {
            b.forceSet(Value.UNDEFINED);
            result.var_count += 1;
        }
    }

    return result;
}

pub fn applyLexicalHoisting(
    env: *Environment,
    declarations: []const Declaration,
) !HoistResult {
    var result = HoistResult.init();

    for (declarations) |d| {
        if (d.kind != .let_ and d.kind != .const_) continue;

        if (env.hasOwn(d.name)) {
            return error.AlreadyDeclared;
        }

        _ = try env.declareOwn(d.name, d.kind);

        if (d.kind == .let_) {
            result.let_count += 1;
        } else {
            result.const_count += 1;
        }
    }

    return result;
}

pub fn applyAllHoisting(
    env: *Environment,
    declarations: []const Declaration,
) !HoistResult {
    var result = HoistResult.init();

    for (declarations) |d| {
        if (env.hasOwn(d.name)) {
            if (d.kind == .var_ or d.kind == .function_decl) continue;
            return error.AlreadyDeclared;
        }

        _ = try env.declareOwn(d.name, d.kind);

        switch (d.kind) {
            .var_ => result.var_count += 1,
            .let_ => result.let_count += 1,
            .const_ => result.const_count += 1,
            .function_decl => result.function_count += 1,
            else => {},
        }
    }

    return result;
}

pub fn findConflicts(declarations: []const Declaration) ?[]const u8 {
    for (declarations, 0..) |d, i| {
        var j: usize = i + 1;
        while (j < declarations.len) : (j += 1) {
            const other = declarations[j];
            if (!std.mem.eql(u8, d.name, other.name)) continue;

            if (d.kind == .var_ and other.kind == .var_) continue;

            const both_functional =
                (d.kind == .var_ and other.kind == .function_decl) or
                (d.kind == .function_decl and other.kind == .var_) or
                (d.kind == .function_decl and other.kind == .function_decl);
            if (both_functional) continue;

            return d.name;
        }
    }
    return null;
}

pub fn collectFromArray(allocator: std.mem.Allocator, decls: []const Declaration) !DeclarationList {
    var list = DeclarationList.init(allocator);
    for (decls) |d| {
        try list.add(d);
    }
    return list;
}

test "Declaration init var" {
    const d = Declaration.init("x", .var_);
    try std.testing.expect(d.initialized);
    try std.testing.expect(!d.is_function);
}

test "Declaration init let" {
    const d = Declaration.init("x", .let_);
    try std.testing.expect(!d.initialized);
    try std.testing.expect(d.hasTDZ());
}

test "Declaration init function" {
    const d = Declaration.init("foo", .function_decl);
    try std.testing.expect(d.initialized);
    try std.testing.expect(d.is_function);
}

test "Declaration withFunction" {
    const d = Declaration.withFunction("foo");
    try std.testing.expect(d.is_function);
    try std.testing.expect(d.initialized);
}

test "Declaration hasTDZ" {
    try std.testing.expect(Declaration.init("x", .let_).hasTDZ());
    try std.testing.expect(Declaration.init("x", .const_).hasTDZ());
    try std.testing.expect(!Declaration.init("x", .var_).hasTDZ());
}

test "DeclarationList init" {
    var list = DeclarationList.init(std.testing.allocator);
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 0), list.count());
}

test "DeclarationList add and contains" {
    var list = DeclarationList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(Declaration.init("x", .var_));
    try std.testing.expect(list.contains("x"));
    try std.testing.expect(!list.contains("y"));
}

test "DeclarationList find" {
    var list = DeclarationList.init(std.testing.allocator);
    defer list.deinit();

    try list.add(Declaration.init("x", .let_));
    const d = list.find("x").?;
    try std.testing.expectEqual(BindingKind.let_, d.kind);
}

test "HoistResult init" {
    const r = HoistResult.init();
    try std.testing.expectEqual(@as(usize, 0), r.total());
}

test "classifyVar" {
    const r1 = classifyVar(.var_);
    try std.testing.expectEqual(@as(usize, 1), r1.var_count);

    const r2 = classifyVar(.let_);
    try std.testing.expectEqual(@as(usize, 1), r2.let_count);

    const r3 = classifyVar(.const_);
    try std.testing.expectEqual(@as(usize, 1), r3.const_count);

    const r4 = classifyVar(.function_decl);
    try std.testing.expectEqual(@as(usize, 1), r4.function_count);
}

test "applyVarHoisting" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    const decls = [_]Declaration{
        Declaration.init("x", .var_),
        Declaration.init("foo", .function_decl),
        Declaration.init("y", .let_),
    };

    const r = try applyVarHoisting(&env, &decls);
    try std.testing.expectEqual(@as(usize, 1), r.var_count);
    try std.testing.expectEqual(@as(usize, 1), r.function_count);
    try std.testing.expect(env.hasOwn("x"));
    try std.testing.expect(env.hasOwn("foo"));
    try std.testing.expect(!env.hasOwn("y"));
}

test "applyLexicalHoisting" {
    var env = Environment.init(std.testing.allocator, .block);
    defer env.deinit();

    const decls = [_]Declaration{
        Declaration.init("x", .let_),
        Declaration.init("y", .const_),
        Declaration.init("z", .var_),
    };

    const r = try applyLexicalHoisting(&env, &decls);
    try std.testing.expectEqual(@as(usize, 1), r.let_count);
    try std.testing.expectEqual(@as(usize, 1), r.const_count);
    try std.testing.expect(env.hasOwn("x"));
    try std.testing.expect(env.hasOwn("y"));
    try std.testing.expect(!env.hasOwn("z"));
}

test "applyLexicalHoisting rejects duplicate" {
    var env = Environment.init(std.testing.allocator, .block);
    defer env.deinit();

    const decls = [_]Declaration{
        Declaration.init("x", .let_),
        Declaration.init("x", .let_),
    };

    try std.testing.expectError(error.AlreadyDeclared, applyLexicalHoisting(&env, &decls));
}

test "applyAllHoisting" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    const decls = [_]Declaration{
        Declaration.init("x", .var_),
        Declaration.init("y", .let_),
        Declaration.init("z", .const_),
        Declaration.init("foo", .function_decl),
    };

    const r = try applyAllHoisting(&env, &decls);
    try std.testing.expectEqual(@as(usize, 4), r.total());
}

test "findConflicts none" {
    const decls = [_]Declaration{
        Declaration.init("a", .var_),
        Declaration.init("b", .let_),
        Declaration.init("c", .const_),
    };
    try std.testing.expectEqual(@as(?[]const u8, null), findConflicts(&decls));
}

test "findConflicts var let" {
    const decls = [_]Declaration{
        Declaration.init("x", .var_),
        Declaration.init("x", .let_),
    };
    try std.testing.expect(findConflicts(&decls) != null);
}

test "findConflicts two vars ok" {
    const decls = [_]Declaration{
        Declaration.init("x", .var_),
        Declaration.init("x", .var_),
    };
    try std.testing.expectEqual(@as(?[]const u8, null), findConflicts(&decls));
}

test "findConflicts var and function ok" {
    const decls = [_]Declaration{
        Declaration.init("x", .var_),
        Declaration.init("x", .function_decl),
    };
    try std.testing.expectEqual(@as(?[]const u8, null), findConflicts(&decls));
}

test "collectFromArray" {
    const decls = [_]Declaration{
        Declaration.init("a", .var_),
        Declaration.init("b", .let_),
    };
    var list = try collectFromArray(std.testing.allocator, &decls);
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 2), list.count());
}
