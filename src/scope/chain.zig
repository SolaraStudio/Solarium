const std = @import("std");
const value_mod = @import("../values/value.zig");
const binding_mod = @import("binding.zig");
const env_mod = @import("environment.zig");

pub const Value = value_mod.Value;
pub const Binding = binding_mod.Binding;
pub const Environment = env_mod.Environment;
pub const EnvironmentKind = env_mod.EnvironmentKind;

pub const Resolution = struct {
    binding: *Binding,
    depth: usize,

    pub fn init(binding: *Binding, depth: usize) Resolution {
        return .{ .binding = binding, .depth = depth };
    }

    pub fn get(self: Resolution) !Value {
        return self.binding.get();
    }

    pub fn set(self: Resolution, value: Value) !void {
        return self.binding.set(value);
    }
};

pub const Chain = struct {
    inner: ?*Environment,

    pub fn init(env: ?*Environment) Chain {
        return .{ .inner = env };
    }

    pub fn lookup(self: Chain, name: []const u8) ?Resolution {
        var depth: usize = 0;
        var current = self.inner;
        while (current) |env| {
            if (env.getOwnBinding(name)) |b| {
                return Resolution.init(b, depth);
            }
            current = env.getParent();
            depth += 1;
        }
        return null;
    }

    pub fn exists(self: Chain, name: []const u8) bool {
        return self.lookup(name) != null;
    }

    pub fn depthOf(self: Chain, name: []const u8) ?usize {
        const r = self.lookup(name) orelse return null;
        return r.depth;
    }

    pub fn hasOwn(self: Chain, name: []const u8) bool {
        const env = self.inner orelse return false;
        return env.hasOwn(name);
    }

    pub fn envCount(self: Chain) usize {
        var count: usize = 0;
        var current = self.inner;
        while (current) |env| {
            count += 1;
            current = env.getParent();
        }
        return count;
    }

    pub fn innermostFunction(self: Chain) ?*Environment {
        var current = self.inner;
        while (current) |env| {
            if (env.kind.isFunctionBoundary()) return env;
            current = env.getParent();
        }
        return null;
    }

    pub fn innermostFunctionDepth(self: Chain) ?usize {
        var depth: usize = 0;
        var current = self.inner;
        while (current) |env| {
            if (env.kind.isFunctionBoundary()) return depth;
            current = env.getParent();
            depth += 1;
        }
        return null;
    }
};

pub fn init(env: ?*Environment) Chain {
    return Chain.init(env);
}

test "Resolution init" {
    var b = Binding.init("x", .let_);
    const r = Resolution.init(&b, 3);
    try std.testing.expectEqual(@as(usize, 3), r.depth);
}

test "Resolution get and set" {
    var b = Binding.initWithValue("x", .let_, Value.fromNumber(1.0));
    const r = Resolution.init(&b, 0);

    try std.testing.expectEqual(@as(f64, 1.0), (try r.get()).asNumber().?);
    try r.set(Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), (try r.get()).asNumber().?);
}

test "Chain lookup in own env" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    _ = try env.declareOwnWithValue("x", .let_, Value.fromNumber(42.0));

    const chain = Chain.init(&env);
    const r = chain.lookup("x").?;
    try std.testing.expectEqual(@as(usize, 0), r.depth);
    try std.testing.expectEqual(@as(f64, 42.0), (try r.get()).asNumber().?);
}

test "Chain lookup in parent" {
    var parent = Environment.init(std.testing.allocator, .function);
    defer parent.deinit();
    _ = try parent.declareOwnWithValue("x", .let_, Value.fromNumber(42.0));

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;

    const chain = Chain.init(&child);
    const r = chain.lookup("x").?;
    try std.testing.expectEqual(@as(usize, 1), r.depth);
}

test "Chain lookup deep" {
    var grandparent = Environment.init(std.testing.allocator, .function);
    defer grandparent.deinit();
    _ = try grandparent.declareOwnWithValue("x", .let_, Value.fromNumber(42.0));

    var parent = Environment.init(std.testing.allocator, .block);
    defer parent.deinit();
    parent.parent = &grandparent;

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;

    const chain = Chain.init(&child);
    const r = chain.lookup("x").?;
    try std.testing.expectEqual(@as(usize, 2), r.depth);
}

test "Chain lookup missing" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    const chain = Chain.init(&env);
    try std.testing.expectEqual(@as(?Resolution, null), chain.lookup("missing"));
}

test "Chain exists" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    _ = try env.declareOwn("x", .let_);

    const chain = Chain.init(&env);
    try std.testing.expect(chain.exists("x"));
    try std.testing.expect(!chain.exists("y"));
}

test "Chain depthOf" {
    var parent = Environment.init(std.testing.allocator, .function);
    defer parent.deinit();
    _ = try parent.declareOwn("x", .let_);

    var child = Environment.init(std.testing.allocator, .block);
    defer child.deinit();
    child.parent = &parent;
    _ = try child.declareOwn("y", .let_);

    const chain = Chain.init(&child);
    try std.testing.expectEqual(@as(usize, 0), chain.depthOf("y").?);
    try std.testing.expectEqual(@as(usize, 1), chain.depthOf("x").?);
}

test "Chain hasOwn" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();
    _ = try env.declareOwn("x", .let_);

    const chain = Chain.init(&env);
    try std.testing.expect(chain.hasOwn("x"));
    try std.testing.expect(!chain.hasOwn("y"));
}

test "Chain envCount" {
    var a = Environment.init(std.testing.allocator, .global);
    defer a.deinit();

    var b = Environment.init(std.testing.allocator, .function);
    defer b.deinit();
    b.parent = &a;

    var c = Environment.init(std.testing.allocator, .block);
    defer c.deinit();
    c.parent = &b;

    const chain = Chain.init(&c);
    try std.testing.expectEqual(@as(usize, 3), chain.envCount());
}

test "Chain innermostFunction" {
    var global_env = Environment.init(std.testing.allocator, .global);
    defer global_env.deinit();

    var fn_env = Environment.init(std.testing.allocator, .function);
    defer fn_env.deinit();
    fn_env.parent = &global_env;

    var block_env = Environment.init(std.testing.allocator, .block);
    defer block_env.deinit();
    block_env.parent = &fn_env;

    const chain = Chain.init(&block_env);
    try std.testing.expectEqual(&fn_env, chain.innermostFunction().?);
}

test "Chain innermostFunctionDepth" {
    var global_env = Environment.init(std.testing.allocator, .global);
    defer global_env.deinit();

    var fn_env = Environment.init(std.testing.allocator, .function);
    defer fn_env.deinit();
    fn_env.parent = &global_env;

    var block_env = Environment.init(std.testing.allocator, .block);
    defer block_env.deinit();
    block_env.parent = &fn_env;

    const chain = Chain.init(&block_env);
    try std.testing.expectEqual(@as(usize, 1), chain.innermostFunctionDepth().?);
}

test "init helper" {
    var env = Environment.init(std.testing.allocator, .function);
    defer env.deinit();

    const chain = init(&env);
    try std.testing.expectEqual(&env, chain.inner.?);
}
