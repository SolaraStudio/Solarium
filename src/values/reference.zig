const std = @import("std");
const Value = @import("value.zig").Value;

pub const Reference = struct {
    base: Value,
    kind: Kind,
    name: ?[]const u8 = null,
    strict: bool = false,

    pub const Kind = enum {
        unresolvable,
        property,
        variable,
        environment,
    };

    pub fn unresolvable(base: Value) Reference {
        return .{ .base = base, .kind = .unresolvable };
    }

    pub fn property(base: Value, name: []const u8) Reference {
        return .{ .base = base, .kind = .property, .name = name };
    }

    pub fn variable(base: Value, name: []const u8) Reference {
        return .{ .base = base, .kind = .variable, .name = name };
    }

    pub fn environment(base: Value, name: []const u8) Reference {
        return .{ .base = base, .kind = .environment, .name = name };
    }

    pub fn isUnresolvable(self: Reference) bool {
        return self.kind == .unresolvable;
    }

    pub fn isPropertyReference(self: Reference) bool {
        if (self.kind == .property) return true;
        if (self.kind == .environment) return self.base.isObject();
        return false;
    }

    pub fn isEnvironmentReference(self: Reference) bool {
        return self.kind == .environment or self.kind == .variable;
    }

    pub fn baseIsObject(self: Reference) bool {
        return self.base.isObject();
    }

    pub fn baseIsEnvironment(self: Reference) bool {
        return self.kind == .environment or self.kind == .variable;
    }

    pub fn hasName(self: Reference) bool {
        return self.name != null;
    }

    pub fn referencedName(self: Reference) []const u8 {
        return self.name orelse "";
    }

    pub fn withStrict(self: Reference, strict: bool) Reference {
        var r = self;
        r.strict = strict;
        return r;
    }

    pub fn hasPrimitiveBase(self: Reference) bool {
        return self.base.isPrimitive();
    }
};

pub const PropertyKey = union(enum) {
    string: []const u8,
    symbol: *@import("value.zig").Symbol,
    index: u32,

    pub fn fromString(s: []const u8) PropertyKey {
        return .{ .string = s };
    }

    pub fn fromSymbol(s: *@import("value.zig").Symbol) PropertyKey {
        return .{ .symbol = s };
    }

    pub fn fromIndex(i: u32) PropertyKey {
        return .{ .index = i };
    }

    pub fn isString(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .string;
    }

    pub fn isSymbol(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .symbol;
    }

    pub fn isIndex(self: PropertyKey) bool {
        return std.meta.activeTag(self) == .index;
    }

    pub fn asString(self: PropertyKey) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn asSymbol(self: PropertyKey) ?*@import("value.zig").Symbol {
        return switch (self) {
            .symbol => |s| s,
            else => null,
        };
    }

    pub fn asIndex(self: PropertyKey) ?u32 {
        return switch (self) {
            .index => |i| i,
            else => null,
        };
    }

    pub fn eql(self: PropertyKey, other: PropertyKey) bool {
        const t1 = std.meta.activeTag(self);
        const t2 = std.meta.activeTag(other);
        if (t1 != t2) return false;

        return switch (self) {
            .string => |a| std.mem.eql(u8, a, other.string),
            .symbol => |a| a == other.symbol,
            .index => |a| a == other.index,
        };
    }
};

pub fn fromValue(v: Value) Reference {
    return Reference.unresolvable(v);
}

test "unresolvable reference" {
    const r = Reference.unresolvable(Value.UNDEFINED);
    try std.testing.expect(r.isUnresolvable());
    try std.testing.expect(!r.isPropertyReference());
    try std.testing.expect(!r.hasName());
}

test "property reference" {
    const r = Reference.property(Value.UNDEFINED, "foo");
    try std.testing.expect(!r.isUnresolvable());
    try std.testing.expect(r.isPropertyReference());
    try std.testing.expect(r.hasName());
    try std.testing.expectEqualStrings("foo", r.referencedName());
}

test "variable reference" {
    const r = Reference.variable(Value.UNDEFINED, "bar");
    try std.testing.expect(r.isEnvironmentReference());
    try std.testing.expect(!r.isUnresolvable());
}

test "environment reference" {
    const r = Reference.environment(Value.UNDEFINED, "baz");
    try std.testing.expect(r.isEnvironmentReference());
    try std.testing.expect(r.hasName());
}

test "withStrict" {
    const r = Reference.property(Value.UNDEFINED, "x");
    const s = r.withStrict(true);
    try std.testing.expect(s.strict);
    try std.testing.expect(!r.strict);
}

test "hasPrimitiveBase" {
    const r = Reference.property(Value.fromNumber(1.0), "toString");
    try std.testing.expect(r.hasPrimitiveBase());

    var dummy: u8 = 0;
    const obj: *@import("value.zig").Object = @ptrCast(&dummy);
    const r2 = Reference.property(Value.fromObject(obj), "toString");
    try std.testing.expect(!r2.hasPrimitiveBase());
}

test "PropertyKey fromString" {
    const k = PropertyKey.fromString("foo");
    try std.testing.expect(k.isString());
    try std.testing.expectEqualStrings("foo", k.asString().?);
}

test "PropertyKey fromIndex" {
    const k = PropertyKey.fromIndex(42);
    try std.testing.expect(k.isIndex());
    try std.testing.expectEqual(@as(u32, 42), k.asIndex().?);
}

test "PropertyKey fromSymbol" {
    var dummy: u8 = 0;
    const sym: *@import("value.zig").Symbol = @ptrCast(&dummy);
    const k = PropertyKey.fromSymbol(sym);
    try std.testing.expect(k.isSymbol());
    try std.testing.expectEqual(sym, k.asSymbol().?);
}

test "PropertyKey eql same string" {
    const a = PropertyKey.fromString("foo");
    const b = PropertyKey.fromString("foo");
    try std.testing.expect(a.eql(b));
}

test "PropertyKey eql different string" {
    const a = PropertyKey.fromString("foo");
    const b = PropertyKey.fromString("bar");
    try std.testing.expect(!a.eql(b));
}

test "PropertyKey eql different kinds" {
    const a = PropertyKey.fromString("42");
    const b = PropertyKey.fromIndex(42);
    try std.testing.expect(!a.eql(b));
}

test "PropertyKey eql same index" {
    try std.testing.expect(PropertyKey.fromIndex(42).eql(PropertyKey.fromIndex(42)));
    try std.testing.expect(!PropertyKey.fromIndex(42).eql(PropertyKey.fromIndex(43)));
}

test "fromValue returns unresolvable" {
    const r = fromValue(Value.TRUE);
    try std.testing.expect(r.isUnresolvable());
}
