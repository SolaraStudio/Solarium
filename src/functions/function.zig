const std = @import("std");
const value_mod = @import("../values/value.zig");
const string_mod = @import("../values/string.zig");
const object_mod = @import("../objects/object.zig");
const key_mod = @import("../objects/key.zig");
const prop_mod = @import("../objects/property.zig");

pub const Value = value_mod.Value;
pub const Object = object_mod.Object;
pub const PropertyKey = key_mod.PropertyKey;
pub const Property = prop_mod.Property;
pub const Attributes = prop_mod.Attributes;

pub const FunctionKind = enum(u8) {
    normal,
    arrow,
    method,
    generator,
    async,
    async_generator,
    class_constructor,
    bound,
    native,

    pub fn toString(self: FunctionKind) []const u8 {
        return @tagName(self);
    }

    pub fn isGenerator(self: FunctionKind) bool {
        return self == .generator or self == .async_generator;
    }

    pub fn isAsync(self: FunctionKind) bool {
        return self == .async or self == .async_generator;
    }

    pub fn isConstructor(self: FunctionKind) bool {
        return self == .normal or self == .method or self == .class_constructor;
    }

    pub fn isArrow(self: FunctionKind) bool {
        return self == .arrow;
    }

    pub fn hasThisBinding(self: FunctionKind) bool {
        return switch (self) {
            .arrow, .async => false,
            else => true,
        };
    }

    pub fn hasOwnPrototype(self: FunctionKind) bool {
        return self.isConstructor();
    }
};

pub const Flag = enum(u8) {
    strict,
    is_class_constructor,
    has_rest_params,
    has_simple_params,
    is_anonymous,
    is_method,
    is_derived,
    home_object_set,

    pub fn toString(self: Flag) []const u8 {
        return @tagName(self);
    }
};

pub const FunctionFlags = std.EnumSet(Flag);

pub const Function = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    kind: FunctionKind,
    length: u32,
    flags: FunctionFlags,
    object: *Object,
    home_object: ?*Object,
    bound_target: ?Value,
    bound_this: Value,
    bound_args: []const Value,
    name_string: ?*string_mod.String,
    proto_obj: ?*Object,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        kind: FunctionKind,
        length: u32,
        object: *Object,
    ) Function {
        return .{
            .allocator = allocator,
            .name = name,
            .kind = kind,
            .length = length,
            .flags = FunctionFlags.initEmpty(),
            .object = object,
            .home_object = null,
            .bound_target = null,
            .bound_this = Value.UNDEFINED,
            .bound_args = &.{},
            .name_string = null,
            .proto_obj = null,
        };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        kind: FunctionKind,
        length: u32,
        function_proto: ?*Object,
    ) !*Function {
        const obj = try Object.createWithPrototype(allocator, function_proto);
        errdefer obj.destroy();
        obj.setClassName("Function");

        const f = try allocator.create(Function);
        errdefer allocator.destroy(f);

        f.* = Function.init(allocator, name, kind, length, obj);

        try f.installOwnProperties();

        return f;
    }

    pub fn destroy(self: *Function) void {
        const allocator = self.allocator;

        if (self.name_string) |s| {
            allocator.destroy(s);
        }

        if (self.proto_obj) |p| {
            p.destroy();
        }

        if (self.bound_args.len > 0) {
            allocator.free(self.bound_args);
        }

        self.object.destroy();
        allocator.destroy(self);
    }

    fn installOwnProperties(self: *Function) !void {
        const attrs = Attributes{
            .writable = false,
            .enumerable = false,
            .configurable = true,
        };

        if (self.name.len > 0) {
            const s = try string_mod.create(self.allocator, self.name);
            self.name_string = s;
            try self.object.defineOwnDataWith(
                PropertyKey.fromString("name"),
                string_mod.toValue(s),
                attrs,
            );
        }

        try self.object.defineOwnDataWith(
            PropertyKey.fromString("length"),
            Value.fromNumber(@floatFromInt(self.length)),
            attrs,
        );
    }

    pub fn getName(self: Function) []const u8 {
        return self.name;
    }

    pub fn setName(self: *Function, name: []const u8) void {
        self.name = name;
    }

    pub fn getKind(self: Function) FunctionKind {
        return self.kind;
    }

    pub fn getLength(self: Function) u32 {
        return self.length;
    }

    pub fn setLength(self: *Function, length: u32) void {
        self.length = length;
    }

    pub fn getObject(self: Function) *Object {
        return self.object;
    }

    pub fn toValue(self: *Function) Value {
        return self.object.toValue();
    }

    pub fn isArrow(self: Function) bool {
        return self.kind.isArrow();
    }

    pub fn isGenerator(self: Function) bool {
        return self.kind.isGenerator();
    }

    pub fn isAsync(self: Function) bool {
        return self.kind.isAsync();
    }

    pub fn isConstructor(self: Function) bool {
        return self.kind.isConstructor();
    }

    pub fn isNative(self: Function) bool {
        return self.kind == .native;
    }

    pub fn isBound(self: Function) bool {
        return self.kind == .bound;
    }

    pub fn isStrict(self: Function) bool {
        return self.flags.contains(.strict);
    }

    pub fn setStrict(self: *Function, strict: bool) void {
        if (strict) {
            self.flags.insert(.strict);
        } else {
            self.flags.remove(.strict);
        }
    }

    pub fn isClassConstructor(self: Function) bool {
        return self.flags.contains(.is_class_constructor);
    }

    pub fn setIsClassConstructor(self: *Function) void {
        self.flags.insert(.is_class_constructor);
    }

    pub fn hasRestParams(self: Function) bool {
        return self.flags.contains(.has_rest_params);
    }

    pub fn setHasRestParams(self: *Function) void {
        self.flags.insert(.has_rest_params);
    }

    pub fn hasSimpleParams(self: Function) bool {
        return self.flags.contains(.has_simple_params);
    }

    pub fn setHasSimpleParams(self: *Function, simple: bool) void {
        if (simple) {
            self.flags.insert(.has_simple_params);
        } else {
            self.flags.remove(.has_simple_params);
        }
    }

    pub fn isAnonymous(self: Function) bool {
        return self.flags.contains(.is_anonymous);
    }

    pub fn setIsAnonymous(self: *Function) void {
        self.flags.insert(.is_anonymous);
    }

    pub fn isMethod(self: Function) bool {
        return self.flags.contains(.is_method);
    }

    pub fn setIsMethod(self: *Function) void {
        self.flags.insert(.is_method);
    }

    pub fn isDerived(self: Function) bool {
        return self.flags.contains(.is_derived);
    }

    pub fn setIsDerived(self: *Function) void {
        self.flags.insert(.is_derived);
    }

    pub fn setHomeObject(self: *Function, obj: *Object) void {
        self.home_object = obj;
        self.flags.insert(.home_object_set);
    }

    pub fn getHomeObject(self: Function) ?*Object {
        return self.home_object;
    }

    pub fn hasHomeObject(self: Function) bool {
        return self.flags.contains(.home_object_set);
    }

    pub fn definePrototypeProperty(self: *Function) !void {
        if (!self.kind.hasOwnPrototype()) return;
        if (self.proto_obj != null) return;

        const proto_obj = try Object.create(self.allocator);
        errdefer proto_obj.destroy();
        proto_obj.setClassName(self.name);
        self.proto_obj = proto_obj;

        try proto_obj.defineOwnDataWith(
            PropertyKey.fromString("constructor"),
            self.toValue(),
            Attributes{
                .writable = true,
                .enumerable = false,
                .configurable = true,
            },
        );

        try self.object.defineOwnDataWith(
            PropertyKey.fromString("prototype"),
            proto_obj.toValue(),
            Attributes{
                .writable = true,
                .enumerable = false,
                .configurable = false,
            },
        );
    }

    pub fn setBound(
        self: *Function,
        target: Value,
        bound_this: Value,
        args: []const Value,
    ) !void {
        const copy = try self.allocator.alloc(Value, args.len);
        @memcpy(copy, args);
        self.bound_target = target;
        self.bound_this = bound_this;
        self.bound_args = copy;
        self.kind = .bound;
    }

    pub fn getBoundTarget(self: Function) ?Value {
        return self.bound_target;
    }

    pub fn getBoundThis(self: Function) Value {
        return self.bound_this;
    }

    pub fn getBoundArgs(self: Function) []const Value {
        return self.bound_args;
    }

    pub fn boundArgCount(self: Function) usize {
        return self.bound_args.len;
    }

    pub fn getProperty(self: Function, key: PropertyKey) ?Property {
        return self.object.getOwn(key);
    }

    pub fn setProperty(self: *Function, key: PropertyKey, value: Value) !void {
        try self.object.setValue(key, value);
    }

    pub fn getPrototype(self: Function) ?*Object {
        const v = self.object.getValue(PropertyKey.fromString("prototype")) orelse return null;
        return switch (v) {
            .object => |o| @ptrCast(@alignCast(o)),
            else => null,
        };
    }

    pub fn hasPrototype(self: Function) bool {
        return self.object.hasOwn(PropertyKey.fromString("prototype"));
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    name: []const u8,
    kind: FunctionKind,
    length: u32,
    function_proto: ?*Object,
) !*Function {
    return Function.create(allocator, name, kind, length, function_proto);
}

pub fn isFunction(v: Value) bool {
    if (!v.isObject()) return false;
    const obj = v.asObject().?;
    const concrete = @as(*Object, @ptrCast(@alignCast(obj)));
    return std.mem.eql(u8, concrete.className(), "Function");
}

test "FunctionKind toString" {
    try std.testing.expectEqualStrings("normal", FunctionKind.normal.toString());
    try std.testing.expectEqualStrings("arrow", FunctionKind.arrow.toString());
}

test "FunctionKind isGenerator" {
    try std.testing.expect(FunctionKind.generator.isGenerator());
    try std.testing.expect(FunctionKind.async_generator.isGenerator());
    try std.testing.expect(!FunctionKind.normal.isGenerator());
}

test "FunctionKind isAsync" {
    try std.testing.expect(FunctionKind.async.isAsync());
    try std.testing.expect(FunctionKind.async_generator.isAsync());
    try std.testing.expect(!FunctionKind.normal.isAsync());
}

test "FunctionKind isConstructor" {
    try std.testing.expect(FunctionKind.normal.isConstructor());
    try std.testing.expect(FunctionKind.method.isConstructor());
    try std.testing.expect(FunctionKind.class_constructor.isConstructor());
    try std.testing.expect(!FunctionKind.arrow.isConstructor());
    try std.testing.expect(!FunctionKind.generator.isConstructor());
    try std.testing.expect(!FunctionKind.native.isConstructor());
}

test "FunctionKind isArrow" {
    try std.testing.expect(FunctionKind.arrow.isArrow());
    try std.testing.expect(!FunctionKind.normal.isArrow());
}

test "FunctionKind hasThisBinding" {
    try std.testing.expect(FunctionKind.normal.hasThisBinding());
    try std.testing.expect(!FunctionKind.arrow.hasThisBinding());
    try std.testing.expect(!FunctionKind.async.hasThisBinding());
}

test "FunctionKind hasOwnPrototype" {
    try std.testing.expect(FunctionKind.normal.hasOwnPrototype());
    try std.testing.expect(!FunctionKind.arrow.hasOwnPrototype());
    try std.testing.expect(!FunctionKind.native.hasOwnPrototype());
}

test "Flag toString" {
    try std.testing.expectEqualStrings("strict", Flag.strict.toString());
    try std.testing.expectEqualStrings("is_derived", Flag.is_derived.toString());
}

test "Function create" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 2, null);
    defer f.destroy();

    try std.testing.expectEqualStrings("foo", f.getName());
    try std.testing.expectEqual(FunctionKind.normal, f.getKind());
    try std.testing.expectEqual(@as(u32, 2), f.getLength());
}

test "Function installOwnProperties name" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const name_prop = f.getObject().getOwn(PropertyKey.fromString("name"));
    try std.testing.expect(name_prop != null);
    try std.testing.expect(!name_prop.?.isWritable());
    try std.testing.expect(name_prop.?.isConfigurable());
}

test "Function installOwnProperties length" {
    const f = try Function.create(std.testing.allocator, "bar", .normal, 3, null);
    defer f.destroy();

    const len_prop = f.getObject().getOwn(PropertyKey.fromString("length"));
    try std.testing.expect(len_prop != null);
    try std.testing.expectEqual(@as(f64, 3.0), len_prop.?.getValue().?.asNumber().?);
}

test "Function setName" {
    const f = try Function.create(std.testing.allocator, "old", .normal, 0, null);
    defer f.destroy();

    f.setName("new");
    try std.testing.expectEqualStrings("new", f.getName());
}

test "Function setLength" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 1, null);
    defer f.destroy();

    f.setLength(5);
    try std.testing.expectEqual(@as(u32, 5), f.getLength());
}

test "Function isStrict" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    try std.testing.expect(!f.isStrict());
    f.setStrict(true);
    try std.testing.expect(f.isStrict());
    f.setStrict(false);
    try std.testing.expect(!f.isStrict());
}

test "Function setIsClassConstructor" {
    const f = try Function.create(std.testing.allocator, "Foo", .class_constructor, 0, null);
    defer f.destroy();

    try std.testing.expect(!f.isClassConstructor());
    f.setIsClassConstructor();
    try std.testing.expect(f.isClassConstructor());
}

test "Function hasRestParams" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    try std.testing.expect(!f.hasRestParams());
    f.setHasRestParams();
    try std.testing.expect(f.hasRestParams());
}

test "Function setHasSimpleParams" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    f.setHasSimpleParams(true);
    try std.testing.expect(f.hasSimpleParams());
    f.setHasSimpleParams(false);
    try std.testing.expect(!f.hasSimpleParams());
}

test "Function setIsAnonymous" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    f.setIsAnonymous();
    try std.testing.expect(f.isAnonymous());
}

test "Function setIsMethod" {
    const f = try Function.create(std.testing.allocator, "foo", .method, 0, null);
    defer f.destroy();

    f.setIsMethod();
    try std.testing.expect(f.isMethod());
}

test "Function setIsDerived" {
    const f = try Function.create(std.testing.allocator, "Foo", .class_constructor, 0, null);
    defer f.destroy();

    try std.testing.expect(!f.isDerived());
    f.setIsDerived();
    try std.testing.expect(f.isDerived());
}

test "Function setHomeObject" {
    const f = try Function.create(std.testing.allocator, "foo", .method, 0, null);
    defer f.destroy();

    var home = Object.init(std.testing.allocator);
    defer home.deinit();

    try std.testing.expect(!f.hasHomeObject());
    f.setHomeObject(&home);
    try std.testing.expect(f.hasHomeObject());
    try std.testing.expectEqual(&home, f.getHomeObject().?);
}

test "Function definePrototypeProperty for constructor" {
    const f = try Function.create(std.testing.allocator, "Foo", .normal, 0, null);
    defer f.destroy();

    try f.definePrototypeProperty();
    try std.testing.expect(f.hasPrototype());

    const proto = f.getPrototype().?;
    try std.testing.expect(proto.hasOwn(PropertyKey.fromString("constructor")));
}

test "Function definePrototypeProperty for arrow does nothing" {
    const f = try Function.create(std.testing.allocator, "foo", .arrow, 0, null);
    defer f.destroy();

    try f.definePrototypeProperty();
    try std.testing.expect(!f.hasPrototype());
}

test "Function definePrototypeProperty idempotent" {
    const f = try Function.create(std.testing.allocator, "Foo", .normal, 0, null);
    defer f.destroy();

    try f.definePrototypeProperty();
    const p1 = f.getPrototype().?;
    try f.definePrototypeProperty();
    const p2 = f.getPrototype().?;
    try std.testing.expectEqual(p1, p2);
}

test "Function setBound" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const args = [_]Value{Value.fromNumber(1.0)};
    try f.setBound(Value.TRUE, Value.FALSE, &args);

    try std.testing.expect(f.isBound());
    try std.testing.expect(f.getBoundTarget().?.asBool().?);
    try std.testing.expect(!f.getBoundThis().asBool().?);
    try std.testing.expectEqual(@as(usize, 1), f.boundArgCount());
}

test "Function toValue" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    const v = f.toValue();
    try std.testing.expect(v.isObject());
}

test "Function getProperty" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    try std.testing.expect(f.getProperty(PropertyKey.fromString("name")) != null);
    try std.testing.expect(f.getProperty(PropertyKey.fromString("missing")) == null);
}

test "Function setProperty" {
    const f = try Function.create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();

    try f.setProperty(PropertyKey.fromString("custom"), Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), f.getProperty(PropertyKey.fromString("custom")).?.getValue().?.asNumber().?);
}

test "create helper" {
    const f = try create(std.testing.allocator, "foo", .normal, 0, null);
    defer f.destroy();
    try std.testing.expectEqualStrings("foo", f.getName());
}

test "isFunction returns false for non-object" {
    try std.testing.expect(!isFunction(Value.TRUE));
    try std.testing.expect(!isFunction(Value.UNDEFINED));
}
