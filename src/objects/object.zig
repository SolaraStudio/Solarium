const std = @import("std");
const value_mod = @import("../values/value.zig");
const key_mod = @import("key.zig");
const prop_mod = @import("property.zig");
const desc_mod = @import("descriptor.zig");
const slot_mod = @import("slot.zig");

pub const Value = value_mod.Value;
pub const PropertyKey = key_mod.PropertyKey;
pub const Property = prop_mod.Property;
pub const Attributes = prop_mod.Attributes;
pub const Descriptor = desc_mod.Descriptor;

pub const Entry = struct {
    key: PropertyKey,
    prop: Property,
};

pub const Object = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry),
    prototype: ?*Object,
    extensible: bool,
    class_name: []const u8,
    slots: slot_mod.SlotStore,

    pub fn init(allocator: std.mem.Allocator) Object {
        return .{
            .allocator = allocator,
            .entries = .empty,
            .prototype = null,
            .extensible = true,
            .class_name = "Object",
            .slots = slot_mod.SlotStore.init(allocator),
        };
    }

    pub fn initWithPrototype(allocator: std.mem.Allocator, proto: ?*Object) Object {
        var o = Object.init(allocator);
        o.prototype = proto;
        return o;
    }

    pub fn initWithClass(allocator: std.mem.Allocator, proto: ?*Object, name: []const u8) Object {
        var o = Object.init(allocator);
        o.prototype = proto;
        o.class_name = name;
        return o;
    }

    pub fn deinit(self: *Object) void {
        self.entries.deinit(self.allocator);
        self.slots.deinit();
    }

    pub fn create(allocator: std.mem.Allocator) !*Object {
        const o = try allocator.create(Object);
        o.* = Object.init(allocator);
        return o;
    }

    pub fn createWithPrototype(allocator: std.mem.Allocator, proto: ?*Object) !*Object {
        const o = try allocator.create(Object);
        o.* = Object.initWithPrototype(allocator, proto);
        return o;
    }

    pub fn destroy(self: *Object) void {
        const allocator = self.allocator;
        self.deinit();
        allocator.destroy(self);
    }

    pub fn propertyCount(self: Object) usize {
        return self.entries.items.len;
    }

    pub fn isExtensible(self: Object) bool {
        return self.extensible;
    }

    pub fn preventExtensions(self: *Object) void {
        self.extensible = false;
    }

    pub fn className(self: Object) []const u8 {
        return self.class_name;
    }

    pub fn setClassName(self: *Object, name: []const u8) void {
        self.class_name = name;
    }

    pub fn getPrototype(self: Object) ?*Object {
        return self.prototype;
    }

    pub fn setPrototype(self: *Object, proto: ?*Object) void {
        self.prototype = proto;
    }

    fn findEntry(self: Object, key: PropertyKey) ?usize {
        for (self.entries.items, 0..) |entry, i| {
            if (entry.key.eql(key)) return i;
        }
        return null;
    }

    pub fn hasOwn(self: Object, key: PropertyKey) bool {
        return self.findEntry(key) != null;
    }

    pub fn getOwn(self: Object, key: PropertyKey) ?Property {
        const idx = self.findEntry(key) orelse return null;
        return self.entries.items[idx].prop;
    }

    pub fn get(self: Object, key: PropertyKey) ?Property {
        var current: ?*Object = self.prototype;
        _ = &current;
        if (self.getOwn(key)) |p| return p;

        var proto = self.prototype;
        while (proto) |p| {
            if (p.getOwn(key)) |prop| return prop;
            proto = p.prototype;
        }
        return null;
    }

    pub fn getValue(self: Object, key: PropertyKey) ?Value {
        const p = self.getOwn(key) orelse return null;
        return switch (p) {
            .data => |d| d.value,
            .accessor => null,
        };
    }

    pub fn getValueInChain(self: Object, key: PropertyKey) ?Value {
        const p = self.get(key) orelse return null;
        return switch (p) {
            .data => |d| d.value,
            .accessor => null,
        };
    }

    pub fn defineOwn(self: *Object, key: PropertyKey, prop: Property) !void {
        if (self.findEntry(key)) |idx| {
            self.entries.items[idx].prop = prop;
            return;
        }
        if (!self.extensible) return error.NotExtensible;
        try self.entries.append(self.allocator, .{ .key = key, .prop = prop });
    }

    pub fn setValue(self: *Object, key: PropertyKey, value: Value) !void {
        if (self.findEntry(key)) |idx| {
            const existing = &self.entries.items[idx].prop;
            switch (existing.*) {
                .data => |*d| {
                    if (!d.attributes.writable) return error.NotWritable;
                    d.value = value;
                },
                .accessor => return error.NoSetter,
            }
            return;
        }
        if (!self.extensible) return error.NotExtensible;
        try self.entries.append(self.allocator, .{
            .key = key,
            .prop = Property.initData(value),
        });
    }

    pub fn setValueInChain(self: *Object, key: PropertyKey, value: Value) !void {
        try self.setValue(key, value);
    }

    pub fn deleteOwn(self: *Object, key: PropertyKey) bool {
        var i: usize = 0;
        while (i < self.entries.items.len) : (i += 1) {
            if (self.entries.items[i].key.eql(key)) {
                if (!self.entries.items[i].prop.isConfigurable()) return false;
                _ = self.entries.swapRemove(i);
                return true;
            }
        }
        return true;
    }

    pub fn defineOwnData(self: *Object, key: PropertyKey, value: Value) !void {
        try self.defineOwn(key, Property.initData(value));
    }

    pub fn defineOwnDataWith(self: *Object, key: PropertyKey, value: Value, attrs: Attributes) !void {
        try self.defineOwn(key, Property.initDataWith(value, attrs));
    }

    pub fn defineOwnAccessor(self: *Object, key: PropertyKey, getter: ?Value, setter: ?Value) !void {
        var acc = prop_mod.AccessorProperty.init();
        acc.getter = getter;
        acc.setter = setter;
        try self.defineOwn(key, .{ .accessor = acc });
    }

    pub fn keys(self: Object, allocator: std.mem.Allocator) ![]PropertyKey {
        var out: std.ArrayList(PropertyKey) = .empty;
        errdefer out.deinit(allocator);
        for (self.entries.items) |entry| {
            if (entry.prop.isEnumerable()) {
                try out.append(allocator, entry.key);
            }
        }
        return out.toOwnedSlice(allocator);
    }

    pub fn allKeys(self: Object, allocator: std.mem.Allocator) ![]PropertyKey {
        const out = try allocator.alloc(PropertyKey, self.entries.items.len);
        for (self.entries.items, 0..) |entry, i| {
            out[i] = entry.key;
        }
        return out;
    }

    pub fn length(self: Object) usize {
        return self.entries.items.len;
    }

    pub fn isEmpty(self: Object) bool {
        return self.entries.items.len == 0;
    }

    pub fn clear(self: *Object) void {
        self.entries.clearRetainingCapacity();
    }

    pub fn isPrototypeOf(self: *const Object, other: *Object) bool {
        var current = other.prototype;
        while (current) |p| {
            if (p == self) return true;
            current = p.prototype;
        }
        return false;
    }

    pub fn toValue(self: *Object) Value {
        return Value.fromObject(@ptrCast(self));
    }
};

pub fn create(allocator: std.mem.Allocator) !*Object {
    return Object.create(allocator);
}

pub fn createWithPrototype(allocator: std.mem.Allocator, proto: ?*Object) !*Object {
    return Object.createWithPrototype(allocator, proto);
}

pub fn isObject(v: Value) bool {
    return v.isObject();
}

pub fn asObject(v: Value) ?*Object {
    return switch (v) {
        .object => |o| @ptrCast(@alignCast(o)),
        else => null,
    };
}

test "init" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();
    try std.testing.expectEqual(@as(usize, 0), o.propertyCount());
    try std.testing.expect(o.isExtensible());
    try std.testing.expect(o.getPrototype() == null);
    try std.testing.expectEqualStrings("Object", o.className());
}

test "initWithPrototype" {
    var parent = Object.init(std.testing.allocator);
    defer parent.deinit();

    var child = Object.initWithPrototype(std.testing.allocator, &parent);
    defer child.deinit();
    try std.testing.expectEqual(&parent, child.getPrototype().?);
}

test "initWithClass" {
    var o = Object.initWithClass(std.testing.allocator, null, "Array");
    defer o.deinit();
    try std.testing.expectEqualStrings("Array", o.className());
}

test "create and destroy" {
    const o = try Object.create(std.testing.allocator);
    o.destroy();
}

test "preventExtensions" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();
    try std.testing.expect(o.isExtensible());
    o.preventExtensions();
    try std.testing.expect(!o.isExtensible());
}

test "hasOwn empty" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();
    try std.testing.expect(!o.hasOwn(PropertyKey.fromString("x")));
}

test "defineOwnData and getOwn" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(42.0));
    try std.testing.expect(o.hasOwn(PropertyKey.fromString("x")));

    const p = o.getOwn(PropertyKey.fromString("x")).?;
    try std.testing.expectEqual(@as(f64, 42.0), p.getValue().?.asNumber().?);
}

test "getValue" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), o.getValue(PropertyKey.fromString("x")).?.asNumber().?);
}

test "defineOwn overrides" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(1.0));
    try o.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), o.getValue(PropertyKey.fromString("x")).?.asNumber().?);
    try std.testing.expectEqual(@as(usize, 1), o.propertyCount());
}

test "setValue new property" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.setValue(PropertyKey.fromString("x"), Value.TRUE);
    try std.testing.expect(o.getValue(PropertyKey.fromString("x")).?.asBool().?);
}

test "setValue existing writable" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(1.0));
    try o.setValue(PropertyKey.fromString("x"), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), o.getValue(PropertyKey.fromString("x")).?.asNumber().?);
}

test "setValue non-writable fails" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnDataWith(
        PropertyKey.fromString("x"),
        Value.fromNumber(1.0),
        Attributes.none(),
    );
    try std.testing.expectError(error.NotWritable, o.setValue(PropertyKey.fromString("x"), Value.fromNumber(2.0)));
}

test "defineOwn on non-extensible fails for new key" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    o.preventExtensions();
    try std.testing.expectError(error.NotExtensible, o.defineOwnData(PropertyKey.fromString("x"), Value.TRUE));
}

test "deleteOwn configurable" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);
    try std.testing.expect(o.deleteOwn(PropertyKey.fromString("x")));
    try std.testing.expect(!o.hasOwn(PropertyKey.fromString("x")));
}

test "deleteOwn non-configurable fails" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnDataWith(
        PropertyKey.fromString("x"),
        Value.TRUE,
        Attributes.none(),
    );
    try std.testing.expect(!o.deleteOwn(PropertyKey.fromString("x")));
    try std.testing.expect(o.hasOwn(PropertyKey.fromString("x")));
}

test "deleteOwn missing key" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();
    try std.testing.expect(o.deleteOwn(PropertyKey.fromString("missing")));
}

test "defineOwnAccessor" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnAccessor(PropertyKey.fromString("x"), Value.TRUE, Value.FALSE);
    const p = o.getOwn(PropertyKey.fromString("x")).?;
    try std.testing.expect(p.isAccessor());
}

test "get walks prototype chain" {
    var parent = Object.init(std.testing.allocator);
    defer parent.deinit();
    try parent.defineOwnData(PropertyKey.fromString("inherited"), Value.fromNumber(99.0));

    var child = Object.initWithPrototype(std.testing.allocator, &parent);
    defer child.deinit();

    try std.testing.expect(!child.hasOwn(PropertyKey.fromString("inherited")));
    try std.testing.expect(child.getValueInChain(PropertyKey.fromString("inherited")).?.asNumber().? == 99.0);
}

test "own overrides inherited" {
    var parent = Object.init(std.testing.allocator);
    defer parent.deinit();
    try parent.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(1.0));

    var child = Object.initWithPrototype(std.testing.allocator, &parent);
    defer child.deinit();
    try child.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(2.0));

    try std.testing.expectEqual(@as(f64, 2.0), child.getValue(PropertyKey.fromString("x")).?.asNumber().?);
}

test "keys returns enumerable" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("a"), Value.TRUE);
    try o.defineOwnDataWith(PropertyKey.fromString("b"), Value.TRUE, Attributes.writableOnly());

    const ks = try o.keys(std.testing.allocator);
    defer std.testing.allocator.free(ks);
    try std.testing.expectEqual(@as(usize, 1), ks.len);
}

test "allKeys returns all" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("a"), Value.TRUE);
    try o.defineOwnDataWith(PropertyKey.fromString("b"), Value.TRUE, Attributes.writableOnly());

    const ks = try o.allKeys(std.testing.allocator);
    defer std.testing.allocator.free(ks);
    try std.testing.expectEqual(@as(usize, 2), ks.len);
}

test "length and isEmpty" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try std.testing.expect(o.isEmpty());
    try o.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);
    try std.testing.expect(!o.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), o.length());
}

test "clear" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);
    o.clear();
    try std.testing.expectEqual(@as(usize, 0), o.propertyCount());
}

test "isPrototypeOf" {
    var grandparent = Object.init(std.testing.allocator);
    defer grandparent.deinit();

    var parent = Object.initWithPrototype(std.testing.allocator, &grandparent);
    defer parent.deinit();

    var child = Object.initWithPrototype(std.testing.allocator, &parent);
    defer child.deinit();

    try std.testing.expect(grandparent.isPrototypeOf(&child));
    try std.testing.expect(parent.isPrototypeOf(&child));
    try std.testing.expect(!child.isPrototypeOf(&grandparent));
}

test "toValue and asObject" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    const v = o.toValue();
    try std.testing.expect(v.isObject());
    try std.testing.expectEqual(&o, asObject(v).?);
}

test "asObject returns null for non-object" {
    try std.testing.expectEqual(@as(?*Object, null), asObject(Value.TRUE));
}

test "index key" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromIndex(0), Value.fromNumber(1.0));
    try o.defineOwnData(PropertyKey.fromIndex(1), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), o.getValue(PropertyKey.fromIndex(1)).?.asNumber().?);
}

test "index and string keys distinct" {
    var o = Object.init(std.testing.allocator);
    defer o.deinit();

    try o.defineOwnData(PropertyKey.fromIndex(0), Value.fromNumber(1.0));
    try o.defineOwnData(PropertyKey.fromString("0"), Value.fromNumber(2.0));

    try std.testing.expectEqual(@as(f64, 1.0), o.getValue(PropertyKey.fromIndex(0)).?.asNumber().?);
    try std.testing.expectEqual(@as(f64, 2.0), o.getValue(PropertyKey.fromString("0")).?.asNumber().?);
}
