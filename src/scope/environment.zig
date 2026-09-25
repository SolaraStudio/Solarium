const std = @import("std");
const value_mod = @import("../values/value.zig");
const binding_mod = @import("binding.zig");

pub const Value = value_mod.Value;
pub const Binding = binding_mod.Binding;
pub const BindingKind = binding_mod.BindingKind;

pub const EnvironmentKind = enum(u8) {
    global,
    module,
    function,
    block,
    catch_clause,
    with_stmt,
    class_body,

    pub fn toString(self: EnvironmentKind) []const u8 {
        return @tagName(self);
    }

    pub fn isFunctionBoundary(self: EnvironmentKind) bool {
        return self == .function or self == .module or self == .global;
    }
};

pub const Environment = struct {
    allocator: std.mem.Allocator,
    bindings: std.StringHashMap(*Binding),
    parent: ?*Environment,
    kind: EnvironmentKind,
    with_object: ?Value = null,

    pub fn init(allocator: std.mem.Allocator, kind: EnvironmentKind) Environment {
        return .{
            .allocator = allocator,
            .bindings = std.StringHashMap(*Binding).init(allocator),
            .parent = null,
            .kind = kind,
        };
    }

    pub fn deinit(self: *Environment) void {
        var it = self.bindings.valueIterator();
        while (it.next()) |bp| {
            self.allocator.destroy(bp.*);
        }
        self.bindings.deinit();
    }

    pub fn create(allocator: std.mem.Allocator, kind: EnvironmentKind) !*Environment {
        const env = try allocator.create(Environment);
        env.* = Environment.init(allocator, kind);
        return env;
    }

    pub fn createWithParent(
        allocator: std.mem.Allocator,
        kind: EnvironmentKind,
        parent: ?*Environment,
    ) !*Environment {
        const env = try create(allocator, kind);
        env.parent = parent;
        return env;
    }

    pub fn destroy(self: *Environment) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn getKind(self: Environment) EnvironmentKind {
        return self.kind;
    }

    pub fn getParent(self: Environment) ?*Environment {
        return self.parent;
    }

    pub fn count(self: Environment) usize {
        return self.bindings.count();
    }

    pub fn hasOwn(self: Environment, name: []const u8) bool {
        return self.bindings.contains(name);
    }

    pub fn has(self: Environment, name: []const u8) bool {
        if (self.bindings.contains(name)) return true;
        if (self.parent) |p| return p.has(name);
        return false;
    }

    pub fn declareOwn(
        self: *Environment,
        name: []const u8,
        kind: BindingKind,
    ) !*Binding {
        if (self.bindings.contains(name)) {
            return error.AlreadyDeclared;
        }
        const b = try self.allocator.create(Binding);
        b.* = Binding.init(name, kind);
        try self.bindings.put(name, b);
        return b;
    }

    pub fn declareOwnWithValue(
        self: *Environment,
        name: []const u8,
        kind: BindingKind,
        value: Value,
    ) !*Binding {
        const b = try self.declareOwn(name, kind);
        b.forceSet(value);
        return b;
    }

    pub fn getOwnBinding(self: Environment, name: []const u8) ?*Binding {
        return self.bindings.get(name);
    }

    pub fn findBinding(self: Environment, name: []const u8) ?*Binding {
        if (self.bindings.get(name)) |b| return b;
        if (self.parent) |p| return p.findBinding(name);
        return null;
    }

    pub fn findBindingIn(self: *Environment, name: []const u8) ?*Binding {
        return self.findBinding(name);
    }

    pub fn get(self: Environment, name: []const u8) !Value {
        const b = self.findBinding(name) orelse return error.NotDefined;
        return b.get();
    }

    pub fn set(self: *Environment, name: []const u8, value: Value) !void {
        const b = self.findBinding(name) orelse return error.NotDefined;
        try b.set(value);
    }

    pub fn delete(self: *Environment, name: []const u8) !bool {
        const b = self.bindings.get(name) orelse return true;
        try b.delete();
        _ = self.bindings.remove(name);
        self.allocator.destroy(b);
        return true;
    }

    pub fn nearestFunctionBoundary(self: *Environment) *Environment {
        var current: *Environment = self;
        while (true) {
            if (current.kind.isFunctionBoundary()) return current;
            current = current.parent orelse return current;
        }
    }

    pub fn depth(self: Environment) usize {
        var d: usize = 0;
        var current = self.parent;
        while (current) |p| {
            d += 1;
            current = p.parent;
        }
        return d;
    }
};



test "EnvironmentKind toString" {
    try std.testing.expectEqualStrings("global", EnvironmentKind.global.toString());
    try std.testing.expectEqualStrings("function", EnvironmentKind.function.toString());
}

test "EnvironmentKind isFunctionBoundary" {
    try std.testing.expect(EnvironmentKind.function.isFunctionBoundary());
    try std.testing.expect(EnvironmentKind.module.isFunctionBoundary());
    try std.testing.expect(EnvironmentKind.global.isFunctionBoundary());
    try std.testing.expect(!EnvironmentKind.block.isFunctionBoundary());
}

test "Environment init" {
    var env = Environment.init(std.testing.allocator, .global);
    defer env.deinit();

    try std.testing.expectEqual(EnvironmentKind.global, env.getKind());
    try std.testing.expectEqual(@as(usize, 0), env.count());
    try std.testing.expect(env.getParent() == null);
}

test "Environment declareOwn and getOwnBinding" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    const b = try env.declareOwn("x", .let_);
    try std.testing.expect(env.hasOwn("x"));
    try std.testing.expectEqual(b, env.getOwnBinding("x").?);
}

test "Environment declareOwn twice fails" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    _ = try env.declareOwn("x", .let_);
    try std.testing.expectError(error.AlreadyDeclared, env.declareOwn("x", .let_));
}

test "Environment declareOwnWithValue" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    _ = try env.declareOwnWithValue("x", .const_, Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), (try env.get("x")).asNumber().?);
}

test "Environment has walks parent" {
    var parent = Environment.init(std.testing.allocator, .function);
    defer parent.deinit();
    _ = try parent.declareOwn("x", .let_);

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;

    try std.testing.expect(child.has("x"));
    try std.testing.expect(!child.hasOwn("x"));
}

test "Environment findBinding walks parent" {
    var parent = Environment.init(std.testing.allocator, .function);
    defer parent.deinit();
    _ = try parent.declareOwnWithValue("x", .let_, Value.fromNumber(42.0));

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;

    const b = child.findBinding("x").?;
    try std.testing.expectEqual(@as(f64, 42.0), b.getValue().asNumber().?);
}

test "Environment get missing fails" {
    var env = Environment.init(std.testing.allocator, .global);
    defer env.deinit();
    try std.testing.expectError(error.NotDefined, env.get("missing"));
}

test "Environment set updates binding" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    _ = try env.declareOwnWithValue("x", .let_, Value.fromNumber(1.0));

    try env.set("x", Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), (try env.get("x")).asNumber().?);
}

test "Environment set in parent" {
    var parent = Environment.init(std.testing.allocator, .function);
    defer parent.deinit();
    _ = try parent.declareOwnWithValue("x", .var_, Value.fromNumber(1.0));

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;

    try child.set("x", Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), (try parent.get("x")).asNumber().?);
}

test "Environment delete own" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    _ = try env.declareOwnWithValue("x", .let_, Value.TRUE);

    try std.testing.expect(try env.delete("x"));
    try std.testing.expect(!env.hasOwn("x"));
}

test "Environment delete missing" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    try std.testing.expect(try env.delete("missing"));
}

test "Environment nearestFunctionBoundary" {
    var global_env = Environment.init(std.testing.allocator, .global);
    defer global_env.deinit();

    var fn_env = Environment.init(std.testing.allocator, .function);
    defer fn_env.deinit();
    fn_env.parent = &global_env;

    var block_env = Environment.init(std.testing.allocator, .block);
    defer block_env.deinit();
    block_env.parent = &fn_env;

    try std.testing.expectEqual(&fn_env, block_env.nearestFunctionBoundary());
    try std.testing.expectEqual(&fn_env, fn_env.nearestFunctionBoundary());
}

test "Environment depth" {
    var a = Environment.init(std.testing.allocator, .global);
    defer a.deinit();

    var b = Environment.init(std.testing.allocator, .function);
    defer b.deinit();
    b.parent = &a;

    var c = Environment.init(std.testing.allocator, .block);
    defer c.deinit();
    c.parent = &b;

    try std.testing.expectEqual(@as(usize, 0), a.depth());
    try std.testing.expectEqual(@as(usize, 1), b.depth());
    try std.testing.expectEqual(@as(usize, 2), c.depth());
}

test "create helper" {
    const env = try Environment.create(std.testing.allocator, .global);
    defer env.destroy();
    try std.testing.expectEqual(EnvironmentKind.global, env.getKind());
}

test "createWithParent helper" {
    const parent = try Environment.create(std.testing.allocator, .function);
    defer parent.destroy();

    const child = try Environment.createWithParent(std.testing.allocator, .block, parent);
    defer child.destroy();

    try std.testing.expectEqual(parent, child.getParent().?);
}
