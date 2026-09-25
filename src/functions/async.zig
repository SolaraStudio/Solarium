const std = @import("std");
const value_mod = @import("../values/value.zig");
const function_mod = @import("function.zig");
const object_mod = @import("../objects/object.zig");
const closure_mod = @import("closure.zig");

pub const Value = value_mod.Value;
pub const Function = function_mod.Function;
pub const FunctionKind = function_mod.FunctionKind;
pub const Object = object_mod.Object;
pub const Environment = closure_mod.Environment;

pub const PromiseState = enum(u8) {
    pending,
    fulfilled,
    rejected,

    pub fn toString(self: PromiseState) []const u8 {
        return @tagName(self);
    }

    pub fn isPending(self: PromiseState) bool {
        return self == .pending;
    }

    pub fn isSettled(self: PromiseState) bool {
        return self == .fulfilled or self == .rejected;
    }

    pub fn isFulfilled(self: PromiseState) bool {
        return self == .fulfilled;
    }

    pub fn isRejected(self: PromiseState) bool {
        return self == .rejected;
    }
};

pub const PromiseReaction = struct {
    on_fulfilled: ?Value = null,
    on_rejected: ?Value = null,
    capability: ?*PromiseCapability = null,
};

pub const PromiseCapability = struct {
    promise: Value,
    resolve: Value,
    reject: Value,
};

pub const AsyncFunction = struct {
    function: *Function,
    environment: ?*Environment,

    pub fn init(function: *Function, env: ?*Environment) AsyncFunction {
        return .{ .function = function, .environment = env };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        arity: u32,
        env: ?*Environment,
        function_proto: ?*Object,
    ) !AsyncFunction {
        const f = try Function.create(allocator, name, .async, arity, function_proto);
        errdefer f.destroy();

        return AsyncFunction.init(f, env);
    }

    pub fn getFunction(self: AsyncFunction) *Function {
        return self.function;
    }

    pub fn getEnvironment(self: AsyncFunction) ?*Environment {
        return self.environment;
    }

    pub fn toValue(self: AsyncFunction) Value {
        return self.function.toValue();
    }

    pub fn destroy(self: AsyncFunction) void {
        self.function.destroy();
    }
};

pub const AsyncGeneratorFunction = struct {
    function: *Function,
    environment: ?*Environment,

    pub fn init(function: *Function, env: ?*Environment) AsyncGeneratorFunction {
        return .{ .function = function, .environment = env };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        arity: u32,
        env: ?*Environment,
        function_proto: ?*Object,
    ) !AsyncGeneratorFunction {
        const f = try Function.create(allocator, name, .async_generator, arity, function_proto);
        errdefer f.destroy();

        return AsyncGeneratorFunction.init(f, env);
    }

    pub fn getFunction(self: AsyncGeneratorFunction) *Function {
        return self.function;
    }

    pub fn getEnvironment(self: AsyncGeneratorFunction) ?*Environment {
        return self.environment;
    }

    pub fn toValue(self: AsyncGeneratorFunction) Value {
        return self.function.toValue();
    }

    pub fn destroy(self: AsyncGeneratorFunction) void {
        self.function.destroy();
    }
};

pub fn createAsync(
    allocator: std.mem.Allocator,
    name: []const u8,
    arity: u32,
    env: ?*Environment,
    function_proto: ?*Object,
) !AsyncFunction {
    return AsyncFunction.create(allocator, name, arity, env, function_proto);
}

pub fn createAsyncGenerator(
    allocator: std.mem.Allocator,
    name: []const u8,
    arity: u32,
    env: ?*Environment,
    function_proto: ?*Object,
) !AsyncGeneratorFunction {
    return AsyncGeneratorFunction.create(allocator, name, arity, env, function_proto);
}

test "PromiseState toString" {
    try std.testing.expectEqualStrings("pending", PromiseState.pending.toString());
    try std.testing.expectEqualStrings("fulfilled", PromiseState.fulfilled.toString());
    try std.testing.expectEqualStrings("rejected", PromiseState.rejected.toString());
}

test "PromiseState isPending" {
    try std.testing.expect(PromiseState.pending.isPending());
    try std.testing.expect(!PromiseState.fulfilled.isPending());
}

test "PromiseState isSettled" {
    try std.testing.expect(PromiseState.fulfilled.isSettled());
    try std.testing.expect(PromiseState.rejected.isSettled());
    try std.testing.expect(!PromiseState.pending.isSettled());
}

test "PromiseState isFulfilled" {
    try std.testing.expect(PromiseState.fulfilled.isFulfilled());
    try std.testing.expect(!PromiseState.rejected.isFulfilled());
}

test "PromiseState isRejected" {
    try std.testing.expect(PromiseState.rejected.isRejected());
    try std.testing.expect(!PromiseState.fulfilled.isRejected());
}

test "AsyncFunction create" {
    const af = try AsyncFunction.create(std.testing.allocator, "fetch", 1, null, null);
    defer af.destroy();

    try std.testing.expectEqualStrings("fetch", af.getFunction().getName());
    try std.testing.expect(af.getFunction().isAsync());
    try std.testing.expect(!af.getFunction().isGenerator());
}

test "AsyncFunction not constructor" {
    const af = try AsyncFunction.create(std.testing.allocator, "fetch", 1, null, null);
    defer af.destroy();

    try std.testing.expect(!af.getFunction().isConstructor());
}

test "AsyncFunction toValue" {
    const af = try AsyncFunction.create(std.testing.allocator, "fetch", 1, null, null);
    defer af.destroy();

    try std.testing.expect(af.toValue().isObject());
}

test "AsyncGeneratorFunction create" {
    const agf = try AsyncGeneratorFunction.create(std.testing.allocator, "stream", 1, null, null);
    defer agf.destroy();

    try std.testing.expect(agf.getFunction().isAsync());
    try std.testing.expect(agf.getFunction().isGenerator());
}

test "AsyncGeneratorFunction toValue" {
    const agf = try AsyncGeneratorFunction.create(std.testing.allocator, "stream", 1, null, null);
    defer agf.destroy();

    try std.testing.expect(agf.toValue().isObject());
}

test "createAsync helper" {
    const af = try createAsync(std.testing.allocator, "fetch", 1, null, null);
    defer af.destroy();
    try std.testing.expect(af.getFunction().isAsync());
}

test "createAsyncGenerator helper" {
    const agf = try createAsyncGenerator(std.testing.allocator, "stream", 1, null, null);
    defer agf.destroy();
    try std.testing.expect(agf.getFunction().isGenerator());
}
