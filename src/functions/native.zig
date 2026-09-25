const std = @import("std");
const value_mod = @import("../values/value.zig");
const function_mod = @import("function.zig");
const object_mod = @import("../objects/object.zig");

pub const Value = value_mod.Value;
pub const Function = function_mod.Function;
pub const FunctionKind = function_mod.FunctionKind;
pub const Object = object_mod.Object;

pub const NativeContext = struct {
    user_data: ?*anyopaque = null,
};

pub const NativeFn = *const fn (NativeContext, []const Value) anyerror!Value;

pub const NativeFunction = struct {
    name: []const u8,
    arity: u32,
    callback: NativeFn,
    user_data: ?*anyopaque = null,

    pub fn init(name: []const u8, arity: u32, callback: NativeFn) NativeFunction {
        return .{ .name = name, .arity = arity, .callback = callback };
    }

    pub fn withData(name: []const u8, arity: u32, callback: NativeFn, data: ?*anyopaque) NativeFunction {
        return .{ .name = name, .arity = arity, .callback = callback, .user_data = data };
    }

    pub fn invoke(self: NativeFunction, args: []const Value) !Value {
        const ctx = NativeContext{ .user_data = self.user_data };
        return self.callback(ctx, args);
    }
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    functions: std.StringHashMap(NativeFunction),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .allocator = allocator,
            .functions = std.StringHashMap(NativeFunction).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        self.functions.deinit();
    }

    pub fn register(self: *Registry, f: NativeFunction) !void {
        try self.functions.put(f.name, f);
    }

    pub fn lookup(self: Registry, name: []const u8) ?NativeFunction {
        return self.functions.get(name);
    }

    pub fn count(self: Registry) usize {
        return self.functions.count();
    }

    pub fn has(self: Registry, name: []const u8) bool {
        return self.functions.contains(name);
    }

    pub fn invoke(self: Registry, name: []const u8, args: []const Value) !?Value {
        const f = self.lookup(name) orelse return null;
        return try f.invoke(args);
    }
};

pub fn createNativeFunction(
    allocator: std.mem.Allocator,
    name: []const u8,
    arity: u32,
    callback: NativeFn,
    function_proto: ?*Object,
) !*Function {
    const f = try Function.create(allocator, name, .native, arity, function_proto);
    _ = callback;
    return f;
}

fn addImpl(_: NativeContext, args: []const Value) anyerror!Value {
    var sum: f64 = 0;
    for (args) |a| {
        if (a.isNumber()) sum += a.asNumber().?;
    }
    return Value.fromNumber(sum);
}

test "NativeFunction init" {
    const nf = NativeFunction.init("add", 2, addImpl);
    try std.testing.expectEqualStrings("add", nf.name);
    try std.testing.expectEqual(@as(u32, 2), nf.arity);
}

test "NativeFunction invoke" {
    const nf = NativeFunction.init("add", 2, addImpl);
    const args = [_]Value{ Value.fromNumber(1.0), Value.fromNumber(2.0) };
    const result = try nf.invoke(&args);
    try std.testing.expectEqual(@as(f64, 3.0), result.asNumber().?);
}

test "Registry init" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();
    try std.testing.expectEqual(@as(usize, 0), reg.count());
}

test "Registry register and lookup" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();

    try reg.register(NativeFunction.init("add", 2, addImpl));
    try std.testing.expect(reg.has("add"));
    try std.testing.expect(reg.lookup("add") != null);
}

test "Registry invoke" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();

    try reg.register(NativeFunction.init("add", 2, addImpl));
    const args = [_]Value{ Value.fromNumber(10.0), Value.fromNumber(20.0) };
    const result = try reg.invoke("add", &args);
    try std.testing.expectEqual(@as(f64, 30.0), result.?.asNumber().?);
}

test "Registry invoke missing" {
    var reg = Registry.init(std.testing.allocator);
    defer reg.deinit();

    const args = [_]Value{};
    const result = try reg.invoke("missing", &args);
    try std.testing.expect(result == null);
}

test "NativeFunction withData" {
    var dummy: u8 = 0;
    const nf = NativeFunction.withData("test", 0, addImpl, @ptrCast(&dummy));
    try std.testing.expect(nf.user_data != null);
}

test "createNativeFunction" {
    const f = try createNativeFunction(std.testing.allocator, "add", 2, addImpl, null);
    defer f.destroy();

    try std.testing.expectEqualStrings("add", f.getName());
    try std.testing.expect(f.isNative());
    try std.testing.expectEqual(@as(u32, 2), f.getLength());
}
