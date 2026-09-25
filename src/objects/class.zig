const std = @import("std");
const value_mod = @import("../values/value.zig");
const key_mod = @import("key.zig");
const prop_mod = @import("property.zig");
const object_mod = @import("object.zig");

pub const Value = value_mod.Value;
pub const PropertyKey = key_mod.PropertyKey;
pub const Property = prop_mod.Property;
pub const Attributes = prop_mod.Attributes;
pub const Object = object_mod.Object;

pub const MethodKind = enum {
    normal,
    getter,
    setter,
    constructor,

    pub fn toString(self: MethodKind) []const u8 {
        return @tagName(self);
    }
};

pub const Method = struct {
    name: PropertyKey,
    function: Value,
    kind: MethodKind = .normal,
    enumerable: bool = false,

    pub fn init(name: PropertyKey, function: Value) Method {
        return .{ .name = name, .function = function };
    }

    pub fn getter(name: PropertyKey, function: Value) Method {
        return .{ .name = name, .function = function, .kind = .getter };
    }

    pub fn setter(name: PropertyKey, function: Value) Method {
        return .{ .name = name, .function = function, .kind = .setter };
    }

    pub fn isNormal(self: Method) bool {
        return self.kind == .normal;
    }

    pub fn isGetter(self: Method) bool {
        return self.kind == .getter;
    }

    pub fn isSetter(self: Method) bool {
        return self.kind == .setter;
    }
};

pub const Field = struct {
    name: PropertyKey,
    initializer: ?Value = null,
    is_static: bool = false,
    is_private: bool = false,

    pub fn init(name: PropertyKey) Field {
        return .{ .name = name };
    }

    pub fn withInitializer(name: PropertyKey, value: Value) Field {
        return .{ .name = name, .initializer = value };
    }

    pub fn static(name: PropertyKey, value: Value) Field {
        return .{ .name = name, .initializer = value, .is_static = true };
    }
};

pub const Class = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    constructor: ?Value,
    prototype: *Object,
    parent: ?*Class,
    methods: std.ArrayList(Method),
    static_methods: std.ArrayList(Method),
    fields: std.ArrayList(Field),
    static_fields: std.ArrayList(Field),

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        prototype: *Object,
    ) Class {
        return .{
            .allocator = allocator,
            .name = name,
            .constructor = null,
            .prototype = prototype,
            .parent = null,
            .methods = .empty,
            .static_methods = .empty,
            .fields = .empty,
            .static_fields = .empty,
        };
    }

    pub fn deinit(self: *Class) void {
        self.methods.deinit(self.allocator);
        self.static_methods.deinit(self.allocator);
        self.fields.deinit(self.allocator);
        self.static_fields.deinit(self.allocator);
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        parent: ?*Class,
    ) !*Class {
        const proto_parent = if (parent) |p| p.prototype else null;
        const prototype = try Object.createWithPrototype(allocator, proto_parent);

        const cls = try allocator.create(Class);
        cls.* = Class.init(allocator, name, prototype);
        cls.parent = parent;
        return cls;
    }

    pub fn destroy(self: *Class) void {
        const allocator = self.allocator;
        self.prototype.destroy();
        self.deinit();
        allocator.destroy(self);
    }

    pub fn setName(self: *Class, name: []const u8) void {
        self.name = name;
    }

    pub fn getName(self: Class) []const u8 {
        return self.name;
    }

    pub fn setConstructor(self: *Class, constructor: Value) void {
        self.constructor = constructor;
    }

    pub fn getConstructor(self: Class) ?Value {
        return self.constructor;
    }

    pub fn getPrototype(self: Class) *Object {
        return self.prototype;
    }

    pub fn getParent(self: Class) ?*Class {
        return self.parent;
    }

    pub fn hasParent(self: Class) bool {
        return self.parent != null;
    }

    pub fn addMethod(self: *Class, m: Method) !void {
        try self.methods.append(self.allocator, m);

        const attr = Attributes{
            .writable = true,
            .enumerable = m.enumerable,
            .configurable = true,
        };

        switch (m.kind) {
            .normal => {
                const prop = Property.initDataWith(m.function, attr);
                try self.prototype.defineOwn(m.name, prop);
            },
            .getter => {
                var acc = prop_mod.AccessorProperty.init();
                acc.getter = m.function;
                acc.attributes = attr;
                try self.prototype.defineOwn(m.name, .{ .accessor = acc });
            },
            .setter => {
                var acc = prop_mod.AccessorProperty.init();
                acc.setter = m.function;
                acc.attributes = attr;
                try self.prototype.defineOwn(m.name, .{ .accessor = acc });
            },
            .constructor => {
                const prop = Property.initDataWith(m.function, attr);
                try self.prototype.defineOwn(m.name, prop);
            },
        }
    }

    pub fn addStaticMethod(self: *Class, m: Method) !void {
        try self.static_methods.append(self.allocator, m);
    }

    pub fn addField(self: *Class, f: Field) !void {
        try self.fields.append(self.allocator, f);
    }

    pub fn addStaticField(self: *Class, f: Field) !void {
        try self.static_fields.append(self.allocator, f);
    }

    pub fn methodCount(self: Class) usize {
        return self.methods.items.len;
    }

    pub fn staticMethodCount(self: Class) usize {
        return self.static_methods.items.len;
    }

    pub fn fieldCount(self: Class) usize {
        return self.fields.items.len;
    }

    pub fn staticFieldCount(self: Class) usize {
        return self.static_fields.items.len;
    }

    pub fn findMethod(self: Class, name: PropertyKey) ?Method {
        for (self.methods.items) |m| {
            if (m.name.eql(name)) return m;
        }
        return null;
    }

    pub fn findStaticMethod(self: Class, name: PropertyKey) ?Method {
        for (self.static_methods.items) |m| {
            if (m.name.eql(name)) return m;
        }
        return null;
    }

    pub fn isSubclassOf(self: Class, other: *Class) bool {
        var current = self.parent;
        while (current) |p| {
            if (p == other) return true;
            current = p.parent;
        }
        return false;
    }

    pub fn depth(self: Class) usize {
        var d: usize = 0;
        var current = self.parent;
        while (current) |p| {
            d += 1;
            current = p.parent;
        }
        return d;
    }

    pub fn instantiate(self: *Class, allocator: std.mem.Allocator) !*Object {
        const instance = try Object.createWithPrototype(allocator, self.prototype);
        instance.setClassName(self.name);

        for (self.fields.items) |f| {
            if (f.is_static) continue;
            const value = f.initializer orelse Value.UNDEFINED;
            try instance.defineOwnData(f.name, value);
        }

        return instance;
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    name: []const u8,
    parent: ?*Class,
) !*Class {
    return Class.create(allocator, name, parent);
}

pub fn method(name: []const u8, function: Value) Method {
    return Method.init(PropertyKey.fromString(name), function);
}

pub fn getter(name: []const u8, function: Value) Method {
    return Method.getter(PropertyKey.fromString(name), function);
}

pub fn setter(name: []const u8, function: Value) Method {
    return Method.setter(PropertyKey.fromString(name), function);
}

pub fn field(name: []const u8, value: Value) Field {
    return Field.withInitializer(PropertyKey.fromString(name), value);
}

test "MethodKind toString" {
    try std.testing.expectEqualStrings("normal", MethodKind.normal.toString());
    try std.testing.expectEqualStrings("getter", MethodKind.getter.toString());
    try std.testing.expectEqualStrings("setter", MethodKind.setter.toString());
}

test "Method init" {
    const m = Method.init(PropertyKey.fromString("foo"), Value.TRUE);
    try std.testing.expect(m.isNormal());
    try std.testing.expect(!m.isGetter());
    try std.testing.expect(!m.isSetter());
}

test "Method getter and setter" {
    const g = Method.getter(PropertyKey.fromString("x"), Value.TRUE);
    const s = Method.setter(PropertyKey.fromString("x"), Value.FALSE);
    try std.testing.expect(g.isGetter());
    try std.testing.expect(s.isSetter());
}

test "Field init" {
    const f = Field.init(PropertyKey.fromString("x"));
    try std.testing.expect(f.initializer == null);
    try std.testing.expect(!f.is_static);
}

test "Field withInitializer" {
    const f = Field.withInitializer(PropertyKey.fromString("x"), Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), f.initializer.?.asNumber().?);
}

test "Field static" {
    const f = Field.static(PropertyKey.fromString("x"), Value.TRUE);
    try std.testing.expect(f.is_static);
}

test "Class create" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();
    try std.testing.expectEqualStrings("Test", cls.getName());
    try std.testing.expect(!cls.hasParent());
}

test "Class create with parent" {
    const parent = try Class.create(std.testing.allocator, "Parent", null);
    defer parent.destroy();

    const child = try Class.create(std.testing.allocator, "Child", parent);
    defer child.destroy();

    try std.testing.expect(child.hasParent());
    try std.testing.expectEqual(parent, child.getParent().?);
}

test "Class prototype inherits from parent" {
    const parent = try Class.create(std.testing.allocator, "Parent", null);
    defer parent.destroy();

    const child = try Class.create(std.testing.allocator, "Child", parent);
    defer child.destroy();

    try std.testing.expectEqual(parent.getPrototype(), child.getPrototype().getPrototype().?);
}

test "Class setConstructor and getConstructor" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    cls.setConstructor(Value.TRUE);
    try std.testing.expect(cls.getConstructor().?.asBool().?);
}

test "Class addMethod" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addMethod(method("foo", Value.TRUE));
    try std.testing.expectEqual(@as(usize, 1), cls.methodCount());
    try std.testing.expect(cls.findMethod(PropertyKey.fromString("foo")) != null);
}

test "Class addMethod defines on prototype" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addMethod(method("foo", Value.TRUE));
    try std.testing.expect(cls.getPrototype().hasOwn(PropertyKey.fromString("foo")));
}

test "Class addGetter" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addMethod(getter("x", Value.TRUE));
    const p = cls.getPrototype().getOwn(PropertyKey.fromString("x")).?;
    try std.testing.expect(p.isAccessor());
    try std.testing.expect(p.getGetter() != null);
}

test "Class addSetter" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addMethod(setter("x", Value.TRUE));
    const p = cls.getPrototype().getOwn(PropertyKey.fromString("x")).?;
    try std.testing.expect(p.isAccessor());
    try std.testing.expect(p.getSetter() != null);
}

test "Class addStaticMethod" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addStaticMethod(method("create", Value.TRUE));
    try std.testing.expectEqual(@as(usize, 1), cls.staticMethodCount());
    try std.testing.expect(cls.findStaticMethod(PropertyKey.fromString("create")) != null);
}

test "Class addField" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addField(field("x", Value.fromNumber(42.0)));
    try std.testing.expectEqual(@as(usize, 1), cls.fieldCount());
}

test "Class addStaticField" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addStaticField(Field.static(PropertyKey.fromString("count"), Value.fromNumber(0.0)));
    try std.testing.expectEqual(@as(usize, 1), cls.staticFieldCount());
}

test "Class findMethod missing" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();
    try std.testing.expect(cls.findMethod(PropertyKey.fromString("missing")) == null);
}

test "Class isSubclassOf" {
    const grandparent = try Class.create(std.testing.allocator, "A", null);
    defer grandparent.destroy();

    const parent = try Class.create(std.testing.allocator, "B", grandparent);
    defer parent.destroy();

    const child = try Class.create(std.testing.allocator, "C", parent);
    defer child.destroy();

    try std.testing.expect(child.isSubclassOf(parent));
    try std.testing.expect(child.isSubclassOf(grandparent));
    try std.testing.expect(!grandparent.isSubclassOf(child));
}

test "Class depth" {
    const a = try Class.create(std.testing.allocator, "A", null);
    defer a.destroy();

    const b = try Class.create(std.testing.allocator, "B", a);
    defer b.destroy();

    const c = try Class.create(std.testing.allocator, "C", b);
    defer c.destroy();

    try std.testing.expectEqual(@as(usize, 0), a.depth());
    try std.testing.expectEqual(@as(usize, 1), b.depth());
    try std.testing.expectEqual(@as(usize, 2), c.depth());
}

test "Class instantiate" {
    const cls = try Class.create(std.testing.allocator, "Test", null);
    defer cls.destroy();

    try cls.addField(field("x", Value.fromNumber(42.0)));

    const instance = try cls.instantiate(std.testing.allocator);
    defer instance.destroy();

    try std.testing.expectEqualStrings("Test", instance.className());
    try std.testing.expectEqual(@as(f64, 42.0), instance.getValue(PropertyKey.fromString("x")).?.asNumber().?);
}

test "create helper" {
    const cls = try create(std.testing.allocator, "Test", null);
    defer cls.destroy();
    try std.testing.expectEqualStrings("Test", cls.getName());
}

test "method helper" {
    const m = method("foo", Value.TRUE);
    try std.testing.expect(m.isNormal());
}

test "field helper" {
    const f = field("x", Value.fromNumber(1.0));
    try std.testing.expectEqual(@as(f64, 1.0), f.initializer.?.asNumber().?);
}
