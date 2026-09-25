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

pub const GeneratorState = enum(u8) {
    suspended_start,
    suspended_yield,
    executing,
    completed,

    pub fn toString(self: GeneratorState) []const u8 {
        return @tagName(self);
    }

    pub fn isSuspended(self: GeneratorState) bool {
        return self == .suspended_start or self == .suspended_yield;
    }

    pub fn isRunning(self: GeneratorState) bool {
        return self == .executing;
    }

    pub fn isDone(self: GeneratorState) bool {
        return self == .completed;
    }
};

pub const GeneratorResult = struct {
    value: Value,
    done: bool,

    pub fn init(value: Value, done: bool) GeneratorResult {
        return .{ .value = value, .done = done };
    }

    pub fn yield_(value: Value) GeneratorResult {
        return .{ .value = value, .done = false };
    }

    pub fn return_(value: Value) GeneratorResult {
        return .{ .value = value, .done = true };
    }
};

pub const GeneratorFunction = struct {
    function: *Function,
    environment: ?*Environment,
    strict: bool,

    pub fn init(function: *Function, env: ?*Environment, strict: bool) GeneratorFunction {
        return .{ .function = function, .environment = env, .strict = strict };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        arity: u32,
        env: ?*Environment,
        function_proto: ?*Object,
        generator_proto: ?*Object,
    ) !GeneratorFunction {
        const f = try Function.create(allocator, name, .generator, arity, function_proto);
        errdefer f.destroy();

        f.setStrict(false);

        if (generator_proto) |gp| {
            _ = gp;
        }

        return GeneratorFunction.init(f, env, false);
    }

    pub fn getFunction(self: GeneratorFunction) *Function {
        return self.function;
    }

    pub fn getEnvironment(self: GeneratorFunction) ?*Environment {
        return self.environment;
    }

    pub fn isStrict(self: GeneratorFunction) bool {
        return self.strict;
    }

    pub fn toValue(self: GeneratorFunction) Value {
        return self.function.toValue();
    }

    pub fn destroy(self: GeneratorFunction) void {
        self.function.destroy();
    }
};

pub const GeneratorObject = struct {
    allocator: std.mem.Allocator,
    state: GeneratorState,
    environment: ?*Environment,
    yielded_values: std.ArrayList(Value),
    return_value: Value,

    pub fn init(allocator: std.mem.Allocator, env: ?*Environment) GeneratorObject {
        return .{
            .allocator = allocator,
            .state = .suspended_start,
            .environment = env,
            .yielded_values = .empty,
            .return_value = Value.UNDEFINED,
        };
    }

    pub fn deinit(self: *GeneratorObject) void {
        self.yielded_values.deinit(self.allocator);
    }

    pub fn getState(self: GeneratorObject) GeneratorState {
        return self.state;
    }

    pub fn setState(self: *GeneratorObject, state: GeneratorState) void {
        self.state = state;
    }

    pub fn isDone(self: GeneratorObject) bool {
        return self.state.isDone();
    }

    pub fn canResume(self: GeneratorObject) bool {
        return self.state.isSuspended();
    }

    pub fn pushYield(self: *GeneratorObject, value: Value) !void {
        try self.yielded_values.append(self.allocator, value);
    }

    pub fn setReturn(self: *GeneratorObject, value: Value) void {
        self.return_value = value;
        self.state = .completed;
    }

    pub fn getReturn(self: GeneratorObject) Value {
        return self.return_value;
    }

    pub fn yieldCount(self: GeneratorObject) usize {
        return self.yielded_values.items.len;
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    name: []const u8,
    arity: u32,
    env: ?*Environment,
    function_proto: ?*Object,
    generator_proto: ?*Object,
) !GeneratorFunction {
    return GeneratorFunction.create(allocator, name, arity, env, function_proto, generator_proto);
}

test "GeneratorState toString" {
    try std.testing.expectEqualStrings("suspended_start", GeneratorState.suspended_start.toString());
    try std.testing.expectEqualStrings("completed", GeneratorState.completed.toString());
}

test "GeneratorState isSuspended" {
    try std.testing.expect(GeneratorState.suspended_start.isSuspended());
    try std.testing.expect(GeneratorState.suspended_yield.isSuspended());
    try std.testing.expect(!GeneratorState.executing.isSuspended());
}

test "GeneratorState isRunning" {
    try std.testing.expect(GeneratorState.executing.isRunning());
    try std.testing.expect(!GeneratorState.suspended_start.isRunning());
}

test "GeneratorState isDone" {
    try std.testing.expect(GeneratorState.completed.isDone());
    try std.testing.expect(!GeneratorState.suspended_yield.isDone());
}

test "GeneratorResult yield" {
    const r = GeneratorResult.yield_(Value.fromNumber(1.0));
    try std.testing.expectEqual(@as(f64, 1.0), r.value.asNumber().?);
    try std.testing.expect(!r.done);
}

test "GeneratorResult return" {
    const r = GeneratorResult.return_(Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), r.value.asNumber().?);
    try std.testing.expect(r.done);
}

test "GeneratorFunction create" {
    const gf = try GeneratorFunction.create(std.testing.allocator, "gen", 0, null, null, null);
    defer gf.destroy();

    try std.testing.expectEqualStrings("gen", gf.getFunction().getName());
    try std.testing.expect(gf.getFunction().isGenerator());
    try std.testing.expect(!gf.getFunction().isAsync());
}

test "GeneratorFunction isConstructor false" {
    const gf = try GeneratorFunction.create(std.testing.allocator, "gen", 0, null, null, null);
    defer gf.destroy();

    try std.testing.expect(!gf.getFunction().isConstructor());
}

test "GeneratorFunction toValue" {
    const gf = try GeneratorFunction.create(std.testing.allocator, "gen", 0, null, null, null);
    defer gf.destroy();

    try std.testing.expect(gf.toValue().isObject());
}

test "GeneratorObject init" {
    var go = GeneratorObject.init(std.testing.allocator, null);
    defer go.deinit();

    try std.testing.expectEqual(GeneratorState.suspended_start, go.getState());
    try std.testing.expect(!go.isDone());
    try std.testing.expect(go.canResume());
}

test "GeneratorObject state transitions" {
    var go = GeneratorObject.init(std.testing.allocator, null);
    defer go.deinit();

    go.setState(.executing);
    try std.testing.expect(!go.canResume());

    go.setState(.suspended_yield);
    try std.testing.expect(go.canResume());

    go.setState(.completed);
    try std.testing.expect(go.isDone());
}

test "GeneratorObject pushYield" {
    var go = GeneratorObject.init(std.testing.allocator, null);
    defer go.deinit();

    try go.pushYield(Value.fromNumber(1.0));
    try go.pushYield(Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(usize, 2), go.yieldCount());
}

test "GeneratorObject setReturn" {
    var go = GeneratorObject.init(std.testing.allocator, null);
    defer go.deinit();

    go.setReturn(Value.fromNumber(42.0));
    try std.testing.expect(go.isDone());
    try std.testing.expectEqual(@as(f64, 42.0), go.getReturn().asNumber().?);
}

test "create helper" {
    const gf = try create(std.testing.allocator, "gen", 0, null, null, null);
    defer gf.destroy();
    try std.testing.expect(gf.getFunction().isGenerator());
}
