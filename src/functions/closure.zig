const std = @import("std");
const value_mod = @import("../values/value.zig");
const function_mod = @import("function.zig");

pub const Value = value_mod.Value;
pub const Function = function_mod.Function;
pub const FunctionKind = function_mod.FunctionKind;

pub const Environment = struct {
    allocator: std.mem.Allocator,
    bindings: std.StringHashMap(Value),
    parent: ?*Environment,

    pub fn init(allocator: std.mem.Allocator) Environment {
        return .{
            .allocator = allocator,
            .bindings = std.StringHashMap(Value).init(allocator),
            .parent = null,
        };
    }

    pub fn deinit(self: *Environment) void {
        self.bindings.deinit();
    }

    pub fn create(allocator: std.mem.Allocator) !*Environment {
        const env = try allocator.create(Environment);
        env.* = Environment.init(allocator);
        return env;
    }

    pub fn createWithParent(allocator: std.mem.Allocator, parent: ?*Environment) !*Environment {
        const env = try create(allocator);
        env.parent = parent;
        return env;
    }

    pub fn destroy(self: *Environment) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn define(self: *Environment, name: []const u8, value: Value) !void {
        try self.bindings.put(name, value);
    }

    pub fn has(self: Environment, name: []const u8) bool {
        return self.bindings.contains(name);
    }

    pub fn getOwn(self: Environment, name: []const u8) ?Value {
        return self.bindings.get(name);
    }

    pub fn get(self: Environment, name: []const u8) ?Value {
        if (self.bindings.get(name)) |v| return v;
        if (self.parent) |p| return p.get(name);
        return null;
    }

    pub fn set(self: *Environment, name: []const u8, value: Value) bool {
        if (self.bindings.contains(name)) {
            self.bindings.put(name, value) catch return false;
            return true;
        }
        if (self.parent) |p| return p.set(name, value);
        return false;
    }

    pub fn delete(self: *Environment, name: []const u8) bool {
        return self.bindings.remove(name);
    }

    pub fn count(self: Environment) usize {
        return self.bindings.count();
    }
};

pub const Closure = struct {
    allocator: std.mem.Allocator,
    function: *Function,
    environment: ?*Environment,

    pub fn init(function: *Function, environment: ?*Environment) Closure {
        return .{
            .allocator = function.allocator,
            .function = function,
            .environment = environment,
        };
    }

    pub fn getFunction(self: Closure) *Function {
        return self.function;
    }

    pub fn getEnvironment(self: Closure) ?*Environment {
        return self.environment;
    }

    pub fn hasEnvironment(self: Closure) bool {
        return self.environment != null;
    }

    pub fn lookup(self: Closure, name: []const u8) ?Value {
        const env = self.environment orelse return null;
        return env.get(name);
    }

    pub fn toValue(self: Closure) Value {
        return self.function.toValue();
    }
};



test "Environment init" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();
    try std.testing.expectEqual(@as(usize, 0), env.count());
    try std.testing.expect(env.parent == null);
}

test "Environment define and get" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.define("x", Value.fromNumber(42.0));
    try std.testing.expect(env.has("x"));
    try std.testing.expectEqual(@as(f64, 42.0), env.get("x").?.asNumber().?);
}

test "Environment get missing" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();
    try std.testing.expect(env.get("missing") == null);
}

test "Environment chain get" {
    var parent = Environment.init(std.testing.allocator);
    defer parent.deinit();
    try parent.define("x", Value.fromNumber(1.0));

    var child = Environment.init(std.testing.allocator);
    defer child.deinit();
    child.parent = &parent;

    try std.testing.expectEqual(@as(f64, 1.0), child.get("x").?.asNumber().?);
}

test "Environment set existing own" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.define("x", Value.fromNumber(1.0));
    try std.testing.expect(env.set("x", Value.fromNumber(2.0)));
    try std.testing.expectEqual(@as(f64, 2.0), env.get("x").?.asNumber().?);
}

test "Environment set parent" {
    var parent = Environment.init(std.testing.allocator);
    defer parent.deinit();
    try parent.define("x", Value.fromNumber(1.0));

    var child = Environment.init(std.testing.allocator);
    defer child.deinit();
    child.parent = &parent;

    try std.testing.expect(child.set("x", Value.fromNumber(2.0)));
    try std.testing.expectEqual(@as(f64, 2.0), parent.get("x").?.asNumber().?);
}

test "Environment set missing" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();
    try std.testing.expect(!env.set("missing", Value.TRUE));
}

test "Environment delete" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.define("x", Value.TRUE);
    try std.testing.expect(env.delete("x"));
    try std.testing.expect(!env.has("x"));
}

test "Environment getOwn" {
    var parent = Environment.init(std.testing.allocator);
    defer parent.deinit();
    try parent.define("x", Value.TRUE);

    var child = Environment.init(std.testing.allocator);
    defer child.deinit();
    child.parent = &parent;

    try std.testing.expect(child.getOwn("x") == null);
    try std.testing.expect(child.get("x") != null);
}

test "Closure init" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const c = Closure.init(f, null);
    try std.testing.expect(!c.hasEnvironment());
    try std.testing.expectEqual(f, c.getFunction());
}

test "Closure with environment" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    var env = Environment.init(std.testing.allocator);
    defer env.deinit();
    try env.define("captured", Value.fromNumber(42.0));

    const c = Closure.init(f, &env);
    try std.testing.expect(c.hasEnvironment());
    try std.testing.expectEqual(@as(f64, 42.0), c.lookup("captured").?.asNumber().?);
}

test "Closure lookup missing" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const c = Closure.init(f, null);
    try std.testing.expect(c.lookup("x") == null);
}

test "Closure toValue" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const c = Closure.init(f, null);
    try std.testing.expect(c.toValue().isObject());
}
