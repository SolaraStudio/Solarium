const std = @import("std");
const value_mod = @import("../values/value.zig");
const key_mod = @import("key.zig");
const prop_mod = @import("property.zig");
const desc_mod = @import("descriptor.zig");
const object_mod = @import("object.zig");

pub const Value = value_mod.Value;
pub const PropertyKey = key_mod.PropertyKey;
pub const Property = prop_mod.Property;
pub const Descriptor = desc_mod.Descriptor;
pub const Object = object_mod.Object;

pub const Trap = enum {
    get_prototype_of,
    set_prototype_of,
    is_extensible,
    prevent_extensions,
    get_own_property_descriptor,
    define_property,
    has,
    get,
    set,
    delete_property,
    own_keys,
    apply,
    construct,

    pub fn toString(self: Trap) []const u8 {
        return @tagName(self);
    }
};

pub const TrapResult = union(enum) {
    value: Value,
    boolean: bool,
    undefined,
    object: ?*Object,
    descriptor: ?Descriptor,
    keys: []PropertyKey,
};

pub const ProxyHandler = struct {
    context: ?*anyopaque = null,

    on_get_prototype_of: ?*const fn (?*anyopaque, *Object) anyerror!?*Object = null,
    on_set_prototype_of: ?*const fn (?*anyopaque, *Object, ?*Object) anyerror!bool = null,
    on_is_extensible: ?*const fn (?*anyopaque, *Object) anyerror!bool = null,
    on_prevent_extensions: ?*const fn (?*anyopaque, *Object) anyerror!bool = null,
    on_get_own_property_descriptor: ?*const fn (?*anyopaque, *Object, PropertyKey) anyerror!?Descriptor = null,
    on_define_property: ?*const fn (?*anyopaque, *Object, PropertyKey, Descriptor) anyerror!bool = null,
    on_has: ?*const fn (?*anyopaque, *Object, PropertyKey) anyerror!bool = null,
    on_get: ?*const fn (?*anyopaque, *Object, PropertyKey, Value) anyerror!Value = null,
    on_set: ?*const fn (?*anyopaque, *Object, PropertyKey, Value, Value) anyerror!bool = null,
    on_delete_property: ?*const fn (?*anyopaque, *Object, PropertyKey) anyerror!bool = null,
    on_own_keys: ?*const fn (?*anyopaque, *Object) anyerror![]PropertyKey = null,
    on_apply: ?*const fn (?*anyopaque, Value, Value, []const Value) anyerror!Value = null,
    on_construct: ?*const fn (?*anyopaque, Value, []const Value, Value) anyerror!Value = null,

    pub fn init() ProxyHandler {
        return .{};
    }

    pub fn supports(self: ProxyHandler, trap: Trap) bool {
        return switch (trap) {
            .get_prototype_of => self.on_get_prototype_of != null,
            .set_prototype_of => self.on_set_prototype_of != null,
            .is_extensible => self.on_is_extensible != null,
            .prevent_extensions => self.on_prevent_extensions != null,
            .get_own_property_descriptor => self.on_get_own_property_descriptor != null,
            .define_property => self.on_define_property != null,
            .has => self.on_has != null,
            .get => self.on_get != null,
            .set => self.on_set != null,
            .delete_property => self.on_delete_property != null,
            .own_keys => self.on_own_keys != null,
            .apply => self.on_apply != null,
            .construct => self.on_construct != null,
        };
    }

    pub fn invokeGet(self: ProxyHandler, target: *Object, key: PropertyKey, receiver: Value) !Value {
        const f = self.on_get orelse return getFallback(target, key);
        return f(self.context, target, key, receiver);
    }

    pub fn invokeSet(self: ProxyHandler, target: *Object, key: PropertyKey, value: Value, receiver: Value) !bool {
        const f = self.on_set orelse return setFallback(target, key, value);
        return f(self.context, target, key, value, receiver);
    }

    pub fn invokeHas(self: ProxyHandler, target: *Object, key: PropertyKey) !bool {
        const f = self.on_has orelse return target.hasOwn(key);
        return f(self.context, target, key);
    }

    pub fn invokeDelete(self: ProxyHandler, target: *Object, key: PropertyKey) !bool {
        const f = self.on_delete_property orelse return target.deleteOwn(key);
        return f(self.context, target, key);
    }

    pub fn invokeOwnKeys(self: ProxyHandler, target: *Object, allocator: std.mem.Allocator) ![]PropertyKey {
        const f = self.on_own_keys orelse return target.allKeys(allocator);
        return f(self.context, target);
    }

    pub fn invokeGetOwnPropertyDescriptor(self: ProxyHandler, target: *Object, key: PropertyKey) !?Descriptor {
        const f = self.on_get_own_property_descriptor orelse {
            const p = target.getOwn(key) orelse return null;
            return Descriptor.fromProperty(p);
        };
        return f(self.context, target, key);
    }

    pub fn invokeDefineProperty(self: ProxyHandler, target: *Object, key: PropertyKey, desc: Descriptor) !bool {
        const f = self.on_define_property orelse {
            const p = desc.toProperty();
            target.defineOwn(key, p) catch return false;
            return true;
        };
        return f(self.context, target, key, desc);
    }

    pub fn invokeGetPrototypeOf(self: ProxyHandler, target: *Object) !?*Object {
        const f = self.on_get_prototype_of orelse return target.getPrototype();
        return f(self.context, target);
    }

    pub fn invokeSetPrototypeOf(self: ProxyHandler, target: *Object, proto: ?*Object) !bool {
        const f = self.on_set_prototype_of orelse {
            target.setPrototype(proto);
            return true;
        };
        return f(self.context, target, proto);
    }

    pub fn invokeIsExtensible(self: ProxyHandler, target: *Object) !bool {
        const f = self.on_is_extensible orelse return target.isExtensible();
        return f(self.context, target);
    }

    pub fn invokePreventExtensions(self: ProxyHandler, target: *Object) !bool {
        const f = self.on_prevent_extensions orelse {
            target.preventExtensions();
            return true;
        };
        return f(self.context, target);
    }
};

fn getFallback(target: *Object, key: PropertyKey) !Value {
    return target.getValueInChain(key) orelse Value.UNDEFINED;
}

fn setFallback(target: *Object, key: PropertyKey, value: Value) !bool {
    target.setValue(key, value) catch return false;
    return true;
}

pub const Proxy = struct {
    target: *Object,
    handler: ProxyHandler,

    pub fn init(target: *Object, handler: ProxyHandler) Proxy {
        return .{ .target = target, .handler = handler };
    }

    pub fn get(self: Proxy, key: PropertyKey, receiver: Value) !Value {
        return self.handler.invokeGet(self.target, key, receiver);
    }

    pub fn set(self: Proxy, key: PropertyKey, value: Value, receiver: Value) !bool {
        return self.handler.invokeSet(self.target, key, value, receiver);
    }

    pub fn has(self: Proxy, key: PropertyKey) !bool {
        return self.handler.invokeHas(self.target, key);
    }

    pub fn delete(self: Proxy, key: PropertyKey) !bool {
        return self.handler.invokeDelete(self.target, key);
    }

    pub fn ownKeys(self: Proxy, allocator: std.mem.Allocator) ![]PropertyKey {
        return self.handler.invokeOwnKeys(self.target, allocator);
    }

    pub fn getOwnPropertyDescriptor(self: Proxy, key: PropertyKey) !?Descriptor {
        return self.handler.invokeGetOwnPropertyDescriptor(self.target, key);
    }

    pub fn defineProperty(self: Proxy, key: PropertyKey, desc: Descriptor) !bool {
        return self.handler.invokeDefineProperty(self.target, key, desc);
    }

    pub fn getPrototypeOf(self: Proxy) !?*Object {
        return self.handler.invokeGetPrototypeOf(self.target);
    }

    pub fn setPrototypeOf(self: Proxy, proto: ?*Object) !bool {
        return self.handler.invokeSetPrototypeOf(self.target, proto);
    }

    pub fn isExtensible(self: Proxy) !bool {
        return self.handler.invokeIsExtensible(self.target);
    }

    pub fn preventExtensions(self: Proxy) !bool {
        return self.handler.invokePreventExtensions(self.target);
    }
};

pub fn create(target: *Object, handler: ProxyHandler) Proxy {
    return Proxy.init(target, handler);
}

pub fn canRevoke(_: Proxy) bool {
    return true;
}

test "Trap toString" {
    try std.testing.expectEqualStrings("get", Trap.get.toString());
    try std.testing.expectEqualStrings("set", Trap.set.toString());
    try std.testing.expectEqualStrings("has", Trap.has.toString());
}

test "ProxyHandler init has no traps" {
    const h = ProxyHandler.init();
    try std.testing.expect(!h.supports(.get));
    try std.testing.expect(!h.supports(.set));
    try std.testing.expect(!h.supports(.has));
}

test "ProxyHandler supports fallback" {
    const h = ProxyHandler.init();
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const v = try h.invokeGet(&target, PropertyKey.fromString("missing"), Value.UNDEFINED);
    try std.testing.expect(v.isUndefined());
}

test "Proxy get fallback returns undefined" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const v = try p.get(PropertyKey.fromString("missing"), Value.UNDEFINED);
    try std.testing.expect(v.isUndefined());
}

test "Proxy get fallback finds existing" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();
    try target.defineOwnData(PropertyKey.fromString("x"), Value.fromNumber(42.0));

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const v = try p.get(PropertyKey.fromString("x"), Value.UNDEFINED);
    try std.testing.expectEqual(@as(f64, 42.0), v.asNumber().?);
}

test "Proxy set fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const ok = try p.set(PropertyKey.fromString("x"), Value.TRUE, Value.UNDEFINED);
    try std.testing.expect(ok);
    try std.testing.expect(target.getValue(PropertyKey.fromString("x")).?.asBool().?);
}

test "Proxy has fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();
    try target.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    try std.testing.expect(try p.has(PropertyKey.fromString("x")));
    try std.testing.expect(!try p.has(PropertyKey.fromString("y")));
}

test "Proxy delete fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();
    try target.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    try std.testing.expect(try p.delete(PropertyKey.fromString("x")));
    try std.testing.expect(!target.hasOwn(PropertyKey.fromString("x")));
}

test "Proxy ownKeys fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();
    try target.defineOwnData(PropertyKey.fromString("a"), Value.TRUE);
    try target.defineOwnData(PropertyKey.fromString("b"), Value.TRUE);

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const keys = try p.ownKeys(std.testing.allocator);
    defer std.testing.allocator.free(keys);
    try std.testing.expectEqual(@as(usize, 2), keys.len);
}

test "Proxy getPrototypeOf fallback" {
    var parent = Object.init(std.testing.allocator);
    defer parent.deinit();

    var target = Object.initWithPrototype(std.testing.allocator, &parent);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    try std.testing.expectEqual(&parent, (try p.getPrototypeOf()).?);
}

test "Proxy isExtensible fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    try std.testing.expect(try p.isExtensible());
}

test "Proxy preventExtensions fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    try std.testing.expect(try p.preventExtensions());
    try std.testing.expect(!target.isExtensible());
}

test "Proxy getOwnPropertyDescriptor fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();
    try target.defineOwnData(PropertyKey.fromString("x"), Value.TRUE);

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const d = try p.getOwnPropertyDescriptor(PropertyKey.fromString("x"));
    try std.testing.expect(d != null);
}

test "Proxy defineProperty fallback" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const h = ProxyHandler.init();
    const p = Proxy.init(&target, h);
    const desc = Descriptor.fromValue(Value.fromNumber(42.0));
    try std.testing.expect(try p.defineProperty(PropertyKey.fromString("x"), desc));
    try std.testing.expectEqual(@as(f64, 42.0), target.getValue(PropertyKey.fromString("x")).?.asNumber().?);
}

test "create helper" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const p = create(&target, ProxyHandler.init());
    try std.testing.expectEqual(&target, p.target);
}

test "canRevoke" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    const p = Proxy.init(&target, ProxyHandler.init());
    try std.testing.expect(canRevoke(p));
}

fn customGet(
    _: ?*anyopaque,
    _: *Object,
    _: PropertyKey,
    _: Value,
) anyerror!Value {
    return Value.fromNumber(999.0);
}

test "Proxy custom get trap" {
    var target = Object.init(std.testing.allocator);
    defer target.deinit();

    var h = ProxyHandler.init();
    h.on_get = customGet;
    try std.testing.expect(h.supports(.get));

    const p = Proxy.init(&target, h);
    const v = try p.get(PropertyKey.fromString("x"), Value.UNDEFINED);
    try std.testing.expectEqual(@as(f64, 999.0), v.asNumber().?);
}
