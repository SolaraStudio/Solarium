const std = @import("std");
const value_mod = @import("../values/value.zig");
const Value = value_mod.Value;

pub const Attributes = struct {
    writable: bool = false,
    enumerable: bool = false,
    configurable: bool = false,

    pub fn all() Attributes {
        return .{ .writable = true, .enumerable = true, .configurable = true };
    }

    pub fn none() Attributes {
        return .{};
    }

    pub fn writableOnly() Attributes {
        return .{ .writable = true };
    }

    pub fn enumerableOnly() Attributes {
        return .{ .enumerable = true };
    }

    pub fn configurableOnly() Attributes {
        return .{ .configurable = true };
    }
};

pub const DataProperty = struct {
    value: Value,
    attributes: Attributes = Attributes.all(),

    pub fn init(value: Value) DataProperty {
        return .{ .value = value };
    }

    pub fn initWith(value: Value, attrs: Attributes) DataProperty {
        return .{ .value = value, .attributes = attrs };
    }

    pub fn isWritable(self: DataProperty) bool {
        return self.attributes.writable;
    }

    pub fn isEnumerable(self: DataProperty) bool {
        return self.attributes.enumerable;
    }

    pub fn isConfigurable(self: DataProperty) bool {
        return self.attributes.configurable;
    }
};

pub const AccessorProperty = struct {
    getter: ?Value = null,
    setter: ?Value = null,
    attributes: Attributes = Attributes.all(),

    pub fn init() AccessorProperty {
        return .{};
    }

    pub fn initGet(get: Value) AccessorProperty {
        return .{ .getter = get };
    }

    pub fn initSet(set: Value) AccessorProperty {
        return .{ .setter = set };
    }

    pub fn initGetSet(get: Value, set: Value) AccessorProperty {
        return .{ .getter = get, .setter = set };
    }

    pub fn hasGetter(self: AccessorProperty) bool {
        return self.getter != null;
    }

    pub fn hasSetter(self: AccessorProperty) bool {
        return self.setter != null;
    }

    pub fn isEnumerable(self: AccessorProperty) bool {
        return self.attributes.enumerable;
    }

    pub fn isConfigurable(self: AccessorProperty) bool {
        return self.attributes.configurable;
    }
};

pub const Property = union(enum) {
    data: DataProperty,
    accessor: AccessorProperty,

    pub fn initData(value: Value) Property {
        return .{ .data = DataProperty.init(value) };
    }

    pub fn initDataWith(value: Value, attrs: Attributes) Property {
        return .{ .data = DataProperty.initWith(value, attrs) };
    }

    pub fn initAccessor() Property {
        return .{ .accessor = AccessorProperty.init() };
    }

    pub fn initGetSet(get: Value, set: Value) Property {
        return .{ .accessor = AccessorProperty.initGetSet(get, set) };
    }

    pub fn isData(self: Property) bool {
        return std.meta.activeTag(self) == .data;
    }

    pub fn isAccessor(self: Property) bool {
        return std.meta.activeTag(self) == .accessor;
    }

    pub fn getValue(self: Property) ?Value {
        return switch (self) {
            .data => |d| d.value,
            else => null,
        };
    }

    pub fn getGetter(self: Property) ?Value {
        return switch (self) {
            .accessor => |a| a.getter,
            else => null,
        };
    }

    pub fn getSetter(self: Property) ?Value {
        return switch (self) {
            .accessor => |a| a.setter,
            else => null,
        };
    }

    pub fn isWritable(self: Property) bool {
        return switch (self) {
            .data => |d| d.attributes.writable,
            .accessor => false,
        };
    }

    pub fn isEnumerable(self: Property) bool {
        return switch (self) {
            .data => |d| d.attributes.enumerable,
            .accessor => |a| a.attributes.enumerable,
        };
    }

    pub fn isConfigurable(self: Property) bool {
        return switch (self) {
            .data => |d| d.attributes.configurable,
            .accessor => |a| a.attributes.configurable,
        };
    }

    pub fn isAccessorProperty(self: Property) bool {
        return self.isAccessor();
    }
};

pub fn data(value: Value) Property {
    return Property.initData(value);
}

pub fn accessor() Property {
    return Property.initAccessor();
}

test "Attributes all" {
    const a = Attributes.all();
    try std.testing.expect(a.writable);
    try std.testing.expect(a.enumerable);
    try std.testing.expect(a.configurable);
}

test "Attributes none" {
    const a = Attributes.none();
    try std.testing.expect(!a.writable);
    try std.testing.expect(!a.enumerable);
    try std.testing.expect(!a.configurable);
}

test "DataProperty init" {
    const p = DataProperty.init(Value.TRUE);
    try std.testing.expect(p.isWritable());
    try std.testing.expect(p.isEnumerable());
    try std.testing.expect(p.isConfigurable());
}

test "DataProperty initWith" {
    const p = DataProperty.initWith(Value.TRUE, Attributes.none());
    try std.testing.expect(!p.isWritable());
    try std.testing.expect(!p.isEnumerable());
}

test "AccessorProperty init" {
    const p = AccessorProperty.init();
    try std.testing.expect(!p.hasGetter());
    try std.testing.expect(!p.hasSetter());
}

test "AccessorProperty initGet" {
    const p = AccessorProperty.initGet(Value.TRUE);
    try std.testing.expect(p.hasGetter());
    try std.testing.expect(!p.hasSetter());
}

test "AccessorProperty initSet" {
    const p = AccessorProperty.initSet(Value.TRUE);
    try std.testing.expect(!p.hasGetter());
    try std.testing.expect(p.hasSetter());
}

test "AccessorProperty initGetSet" {
    const p = AccessorProperty.initGetSet(Value.TRUE, Value.FALSE);
    try std.testing.expect(p.hasGetter());
    try std.testing.expect(p.hasSetter());
}

test "Property initData" {
    const p = Property.initData(Value.TRUE);
    try std.testing.expect(p.isData());
    try std.testing.expect(!p.isAccessor());
}

test "Property initAccessor" {
    const p = Property.initAccessor();
    try std.testing.expect(p.isAccessor());
    try std.testing.expect(!p.isData());
}

test "Property getValue" {
    const p = Property.initData(Value.TRUE);
    try std.testing.expect(p.getValue().?.asBool().?);
}

test "Property getValue null for accessor" {
    const p = Property.initAccessor();
    try std.testing.expectEqual(@as(?Value, null), p.getValue());
}

test "Property isWritable data" {
    const p = Property.initData(Value.TRUE);
    try std.testing.expect(p.isWritable());
}

test "Property isWritable accessor false" {
    const p = Property.initAccessor();
    try std.testing.expect(!p.isWritable());
}

test "Property isEnumerable" {
    const p = Property.initDataWith(Value.TRUE, Attributes.none());
    try std.testing.expect(!p.isEnumerable());
}

test "Property isConfigurable" {
    const p = Property.initDataWith(Value.TRUE, Attributes.configurableOnly());
    try std.testing.expect(p.isConfigurable());
    try std.testing.expect(!p.isEnumerable());
}

test "data helper" {
    const p = data(Value.TRUE);
    try std.testing.expect(p.isData());
}

test "accessor helper" {
    const p = accessor();
    try std.testing.expect(p.isAccessor());
}
