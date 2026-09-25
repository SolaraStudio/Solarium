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

pub const ArrowFunction = struct {
    function: *Function,
    lexical_this: Value,
    environment: ?*Environment,

    pub fn init(function: *Function, lexical_this: Value, env: ?*Environment) ArrowFunction {
        return .{
            .function = function,
            .lexical_this = lexical_this,
            .environment = env,
        };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        arity: u32,
        lexical_this: Value,
        env: ?*Environment,
        function_proto: ?*Object,
    ) !ArrowFunction {
        const f = try Function.create(allocator, name, .arrow, arity, function_proto);
        errdefer f.destroy();

        if (name.len == 0) {
            f.setIsAnonymous();
        }

        return ArrowFunction.init(f, lexical_this, env);
    }

    pub fn getFunction(self: ArrowFunction) *Function {
        return self.function;
    }

    pub fn getLexicalThis(self: ArrowFunction) Value {
        return self.lexical_this;
    }

    pub fn getEnvironment(self: ArrowFunction) ?*Environment {
        return self.environment;
    }

    pub fn toValue(self: ArrowFunction) Value {
        return self.function.toValue();
    }

    pub fn destroy(self: ArrowFunction) void {
        self.function.destroy();
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    name: []const u8,
    arity: u32,
    lexical_this: Value,
    env: ?*Environment,
    function_proto: ?*Object,
) !ArrowFunction {
    return ArrowFunction.create(allocator, name, arity, lexical_this, env, function_proto);
}

test "ArrowFunction create" {
    const af = try ArrowFunction.create(std.testing.allocator, "foo", 0, Value.TRUE, null, null);
    defer af.destroy();

    try std.testing.expectEqualStrings("foo", af.getFunction().getName());
    try std.testing.expect(af.getFunction().isArrow());
    try std.testing.expect(!af.getFunction().isConstructor());
}

test "ArrowFunction has no prototype property" {
    const af = try ArrowFunction.create(std.testing.allocator, "foo", 0, Value.TRUE, null, null);
    defer af.destroy();

    try af.getFunction().definePrototypeProperty();
    try std.testing.expect(!af.getFunction().hasPrototype());
}

test "ArrowFunction lexical this" {
    const af = try ArrowFunction.create(std.testing.allocator, "foo", 0, Value.fromNumber(42.0), null, null);
    defer af.destroy();

    try std.testing.expectEqual(@as(f64, 42.0), af.getLexicalThis().asNumber().?);
}

test "ArrowFunction anonymous" {
    const af = try ArrowFunction.create(std.testing.allocator, "", 0, Value.UNDEFINED, null, null);
    defer af.destroy();

    try std.testing.expect(af.getFunction().isAnonymous());
}

test "ArrowFunction with environment" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    const af = try ArrowFunction.create(std.testing.allocator, "foo", 0, Value.UNDEFINED, &env, null);
    defer af.destroy();

    try std.testing.expectEqual(&env, af.getEnvironment().?);
}

test "ArrowFunction toValue" {
    const af = try ArrowFunction.create(std.testing.allocator, "foo", 0, Value.UNDEFINED, null, null);
    defer af.destroy();

    try std.testing.expect(af.toValue().isObject());
}

test "create helper" {
    const af = try create(std.testing.allocator, "foo", 0, Value.UNDEFINED, null, null);
    defer af.destroy();
    try std.testing.expect(af.getFunction().isArrow());
}
