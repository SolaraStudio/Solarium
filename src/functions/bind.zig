const std = @import("std");
const value_mod = @import("../values/value.zig");
const string_mod = @import("../values/string.zig");
const function_mod = @import("function.zig");
const object_mod = @import("../objects/object.zig");
const key_mod = @import("../objects/key.zig");
const prop_mod = @import("../objects/property.zig");

pub const Value = value_mod.Value;
pub const Function = function_mod.Function;
pub const Object = object_mod.Object;
pub const PropertyKey = key_mod.PropertyKey;
pub const Attributes = prop_mod.Attributes;

pub const BoundFunction = struct {
    allocator: std.mem.Allocator,
    target: Value,
    bound_this: Value,
    bound_args: []const Value,
    object: *Object,
    name_bytes: ?[]u8,
    name_string: ?*string_mod.String,

    pub fn init(
        allocator: std.mem.Allocator,
        target: Value,
        bound_this: Value,
        bound_args: []const Value,
        object: *Object,
    ) BoundFunction {
        return .{
            .allocator = allocator,
            .target = target,
            .bound_this = bound_this,
            .bound_args = bound_args,
            .object = object,
            .name_bytes = null,
            .name_string = null,
        };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        target: Value,
        bound_this: Value,
        bound_args: []const Value,
        function_proto: ?*Object,
    ) !BoundFunction {
        const obj = try Object.createWithPrototype(allocator, function_proto);
        errdefer obj.destroy();
        obj.setClassName("Function");

        const args_copy = try allocator.alloc(Value, bound_args.len);
        errdefer allocator.free(args_copy);
        @memcpy(args_copy, bound_args);

        var bf = BoundFunction.init(allocator, target, bound_this, args_copy, obj);

        try bf.installProperties();

        return bf;
    }

    fn installProperties(self: *BoundFunction) !void {
        const target_fn = self.target.asObject() orelse {
            try self.installDefaults(0, "");
            return;
        };
        const concrete = @as(*Object, @ptrCast(@alignCast(target_fn)));

        const target_length_v = concrete.getValue(PropertyKey.fromString("length"));
        var target_length: u32 = 0;
        if (target_length_v) |lv| {
            if (lv.isNumber()) {
                const n = lv.asNumber().?;
                if (n > 0) {
                    target_length = @intFromFloat(n);
                }
            }
        }

        var new_length: u32 = 0;
        if (@as(usize, target_length) > self.bound_args.len) {
            new_length = target_length - @as(u32, @intCast(self.bound_args.len));
        }

        var target_name: []const u8 = "";
        if (concrete.getValue(PropertyKey.fromString("name"))) |nv| {
            if (nv.isString()) {
                const tgt_str = string_mod.asConcrete(nv.asString().?);
                target_name = tgt_str.bytes;
            }
        }

        try self.installDefaults(new_length, target_name);
    }

    fn installDefaults(self: *BoundFunction, length: u32, target_name: []const u8) !void {
        try self.object.defineOwnDataWith(
            PropertyKey.fromString("length"),
            Value.fromNumber(@floatFromInt(length)),
            Attributes{
                .writable = false,
                .enumerable = false,
                .configurable = true,
            },
        );

        const name_owned = try std.fmt.allocPrint(
            self.allocator,
            "bound {s}",
            .{target_name},
        );
        errdefer self.allocator.free(name_owned);
        self.name_bytes = name_owned;

        const s = try self.allocator.create(string_mod.String);
        errdefer self.allocator.destroy(s);
        s.* = string_mod.String.init(name_owned);
        self.name_string = s;

        try self.object.defineOwnDataWith(
            PropertyKey.fromString("name"),
            string_mod.toValue(s),
            Attributes{
                .writable = false,
                .enumerable = false,
                .configurable = true,
            },
        );
    }

    pub fn destroy(self: *BoundFunction) void {
        const allocator = self.allocator;

        if (self.name_string) |s| {
            allocator.destroy(s);
        }

        if (self.name_bytes) |b| {
            allocator.free(b);
        }

        if (self.bound_args.len > 0) {
            allocator.free(self.bound_args);
        }

        self.object.destroy();
    }

    pub fn getTarget(self: BoundFunction) Value {
        return self.target;
    }

    pub fn getBoundThis(self: BoundFunction) Value {
        return self.bound_this;
    }

    pub fn getBoundArgs(self: BoundFunction) []const Value {
        return self.bound_args;
    }

    pub fn boundArgCount(self: BoundFunction) usize {
        return self.bound_args.len;
    }

    pub fn toValue(self: BoundFunction) Value {
        return self.object.toValue();
    }
};

pub fn bind(
    allocator: std.mem.Allocator,
    target: Value,
    bound_this: Value,
    bound_args: []const Value,
    function_proto: ?*Object,
) !BoundFunction {
    return BoundFunction.create(allocator, target, bound_this, bound_args, function_proto);
}

test "BoundFunction create" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 2, null);
    defer target_fn.destroy();

    var bf = try BoundFunction.create(
        std.testing.allocator,
        target_fn.toValue(),
        Value.fromNumber(42.0),
        &.{},
        null,
    );
    defer bf.destroy();

    try std.testing.expectEqual(@as(f64, 42.0), bf.getBoundThis().asNumber().?);
    try std.testing.expectEqual(@as(usize, 0), bf.boundArgCount());
}

test "BoundFunction with args" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 3, null);
    defer target_fn.destroy();

    const args = [_]Value{ Value.fromNumber(1.0), Value.fromNumber(2.0) };
    var bf = try BoundFunction.create(
        std.testing.allocator,
        target_fn.toValue(),
        Value.UNDEFINED,
        &args,
        null,
    );
    defer bf.destroy();

    try std.testing.expectEqual(@as(usize, 2), bf.boundArgCount());
}

test "BoundFunction length adjusted" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 3, null);
    defer target_fn.destroy();

    const args = [_]Value{ Value.fromNumber(1.0) };
    var bf = try BoundFunction.create(
        std.testing.allocator,
        target_fn.toValue(),
        Value.UNDEFINED,
        &args,
        null,
    );
    defer bf.destroy();

    const len_v = bf.object.getValue(PropertyKey.fromString("length")).?;
    try std.testing.expectEqual(@as(f64, 2.0), len_v.asNumber().?);
}

test "BoundFunction name prefixed" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer target_fn.destroy();

    var bf = try BoundFunction.create(
        std.testing.allocator,
        target_fn.toValue(),
        Value.UNDEFINED,
        &.{},
        null,
    );
    defer bf.destroy();

    const name_v = bf.object.getValue(PropertyKey.fromString("name")).?;
    const s = string_mod.asConcrete(name_v.asString().?);
    try std.testing.expectEqualStrings("bound foo", s.bytes);
}

test "BoundFunction no target still works" {
    var bf = try BoundFunction.create(
        std.testing.allocator,
        Value.UNDEFINED,
        Value.UNDEFINED,
        &.{},
        null,
    );
    defer bf.destroy();

    const len_v = bf.object.getValue(PropertyKey.fromString("length")).?;
    try std.testing.expectEqual(@as(f64, 0.0), len_v.asNumber().?);
}

test "BoundFunction toValue" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer target_fn.destroy();

    var bf = try BoundFunction.create(
        std.testing.allocator,
        target_fn.toValue(),
        Value.UNDEFINED,
        &.{},
        null,
    );
    defer bf.destroy();

    try std.testing.expect(bf.toValue().isObject());
}

test "bind helper" {
    const target_fn = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer target_fn.destroy();

    var bf = try bind(
        std.testing.allocator,
        target_fn.toValue(),
        Value.UNDEFINED,
        &.{},
        null,
    );
    defer bf.destroy();

    try std.testing.expect(bf.object.className().len > 0);
}
