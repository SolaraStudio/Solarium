const std = @import("std");
const value_mod = @import("../values/value.zig");
const property_mod = @import("property.zig");
const Value = value_mod.Value;
const Property = property_mod.Property;
const Attributes = property_mod.Attributes;

pub const Descriptor = struct {
    value: ?Value = null,
    writable: ?bool = null,
    get: ?Value = null,
    set: ?Value = null,
    enumerable: ?bool = null,
    configurable: ?bool = null,

    pub fn empty() Descriptor {
        return .{};
    }

    pub fn fromValue(v: Value) Descriptor {
        return .{ .value = v };
    }

    pub fn fromAttributes(attrs: Attributes) Descriptor {
        return .{
            .writable = attrs.writable,
            .enumerable = attrs.enumerable,
            .configurable = attrs.configurable,
        };
    }

    pub fn data(value: Value, writable: bool, enumerable: bool, configurable: bool) Descriptor {
        return .{
            .value = value,
            .writable = writable,
            .enumerable = enumerable,
            .configurable = configurable,
        };
    }

    pub fn accessor(get: ?Value, set: ?Value, enumerable: bool, configurable: bool) Descriptor {
        return .{
            .get = get,
            .set = set,
            .enumerable = enumerable,
            .configurable = configurable,
        };
    }

    pub fn hasValue(self: Descriptor) bool {
        return self.value != null;
    }

    pub fn hasWritable(self: Descriptor) bool {
        return self.writable != null;
    }

    pub fn hasGet(self: Descriptor) bool {
        return self.get != null;
    }

    pub fn hasSet(self: Descriptor) bool {
        return self.set != null;
    }

    pub fn hasEnumerable(self: Descriptor) bool {
        return self.enumerable != null;
    }

    pub fn hasConfigurable(self: Descriptor) bool {
        return self.configurable != null;
    }

    pub fn isAccessorDescriptor(self: Descriptor) bool {
        return self.get != null or self.set != null;
    }

    pub fn isDataDescriptor(self: Descriptor) bool {
        return self.value != null or self.writable != null;
    }

    pub fn isGenericDescriptor(self: Descriptor) bool {
        return !self.isAccessorDescriptor() and !self.isDataDescriptor();
    }

    pub fn isFullyPopulated(self: Descriptor) bool {
        return self.enumerable != null and self.configurable != null and
            (self.isDataDescriptor() or self.isAccessorDescriptor());
    }

    pub fn toProperty(self: Descriptor) Property {
        if (self.isAccessorDescriptor()) {
            const attrs = Attributes{
                .writable = false,
                .enumerable = self.enumerable orelse false,
                .configurable = self.configurable orelse false,
            };
            var acc = property_mod.AccessorProperty.init();
            acc.getter = self.get;
            acc.setter = self.set;
            acc.attributes = attrs;
            return .{ .accessor = acc };
        }

        const attrs = Attributes{
            .writable = self.writable orelse false,
            .enumerable = self.enumerable orelse false,
            .configurable = self.configurable orelse false,
        };
        return .{ .data = property_mod.DataProperty.initWith(self.value orelse Value.UNDEFINED, attrs) };
    }

    pub fn fromProperty(p: Property) Descriptor {
        return switch (p) {
            .data => |d| .{
                .value = d.value,
                .writable = d.attributes.writable,
                .enumerable = d.attributes.enumerable,
                .configurable = d.attributes.configurable,
            },
            .accessor => |a| .{
                .get = a.getter,
                .set = a.setter,
                .enumerable = a.attributes.enumerable,
                .configurable = a.attributes.configurable,
            },
        };
    }

    pub fn complete(self: Descriptor, current: Property) Descriptor {
        var result = self;

        if (result.enumerable == null) {
            result.enumerable = current.isEnumerable();
        }
        if (result.configurable == null) {
            result.configurable = current.isConfigurable();
        }

        if (current.isData()) {
            if (result.value == null) {
                result.value = current.getValue();
            }
            if (result.writable == null) {
                result.writable = current.isWritable();
            }
        } else {
            if (result.get == null) {
                result.get = current.getGetter();
            }
            if (result.set == null) {
                result.set = current.getSetter();
            }
        }

        return result;
    }
};

pub fn isCompatible(current: Property, desc: Descriptor) bool {
    if (!current.isConfigurable()) {
        if (desc.hasConfigurable() and desc.configurable.?) return false;
        if (desc.hasEnumerable() and desc.enumerable.? != current.isEnumerable()) return false;

        if (current.isData()) {
            if (desc.hasWritable() and !current.isWritable() and desc.writable.?) return false;
            if (!current.isWritable()) {
                if (desc.hasValue()) {
                    const cv = current.getValue().?;
                    const dv = desc.value.?;
                    if (!cv.isSameValue(dv)) return false;
                }
            }
            if (desc.isAccessorDescriptor()) return false;
        } else {
            if (desc.isDataDescriptor()) return false;
            if (desc.hasGet()) {
                const cg = current.getGetter();
                const dg = desc.get;
                if (cg == null and dg != null) return false;
                if (cg != null and dg == null) return false;
                if (cg != null and dg != null) {
                    if (!cg.?.isSameValue(dg.?)) return false;
                }
            }
            if (desc.hasSet()) {
                const cs = current.getSetter();
                const ds = desc.set;
                if (cs == null and ds != null) return false;
                if (cs != null and ds == null) return false;
                if (cs != null and ds != null) {
                    if (!cs.?.isSameValue(ds.?)) return false;
                }
            }
        }
    }
    return true;
}

test "empty descriptor" {
    const d = Descriptor.empty();
    try std.testing.expect(!d.hasValue());
    try std.testing.expect(!d.hasWritable());
    try std.testing.expect(!d.hasEnumerable());
    try std.testing.expect(!d.hasConfigurable());
}

test "fromValue" {
    const d = Descriptor.fromValue(Value.TRUE);
    try std.testing.expect(d.hasValue());
    try std.testing.expect(d.value.?.asBool().?);
}

test "fromAttributes" {
    const attrs = Attributes.all();
    const d = Descriptor.fromAttributes(attrs);
    try std.testing.expect(d.writable.?);
    try std.testing.expect(d.enumerable.?);
    try std.testing.expect(d.configurable.?);
}

test "data descriptor" {
    const d = Descriptor.data(Value.fromNumber(42.0), true, false, true);
    try std.testing.expect(d.hasValue());
    try std.testing.expect(d.writable.?);
    try std.testing.expect(!d.enumerable.?);
    try std.testing.expect(d.configurable.?);
}

test "accessor descriptor" {
    const d = Descriptor.accessor(Value.TRUE, Value.FALSE, true, true);
    try std.testing.expect(d.hasGet());
    try std.testing.expect(d.hasSet());
    try std.testing.expect(d.enumerable.?);
    try std.testing.expect(d.configurable.?);
}

test "isAccessorDescriptor" {
    const d = Descriptor.accessor(Value.TRUE, null, true, false);
    try std.testing.expect(d.isAccessorDescriptor());
    try std.testing.expect(!d.isDataDescriptor());
    try std.testing.expect(!d.isGenericDescriptor());
}

test "isDataDescriptor" {
    const d = Descriptor.data(Value.TRUE, true, true, true);
    try std.testing.expect(d.isDataDescriptor());
    try std.testing.expect(!d.isAccessorDescriptor());
    try std.testing.expect(!d.isGenericDescriptor());
}

test "isGenericDescriptor" {
    const d = Descriptor{ .enumerable = true };
    try std.testing.expect(d.isGenericDescriptor());
    try std.testing.expect(!d.isDataDescriptor());
    try std.testing.expect(!d.isAccessorDescriptor());
}

test "fromProperty data" {
    const p = Property.initDataWith(Value.TRUE, Attributes.all());
    const d = Descriptor.fromProperty(p);
    try std.testing.expect(d.hasValue());
    try std.testing.expect(d.writable.?);
    try std.testing.expect(d.enumerable.?);
    try std.testing.expect(d.configurable.?);
    try std.testing.expect(!d.hasGet());
}

test "fromProperty accessor" {
    const p = Property.initGetSet(Value.TRUE, Value.FALSE);
    const d = Descriptor.fromProperty(p);
    try std.testing.expect(d.hasGet());
    try std.testing.expect(d.hasSet());
    try std.testing.expect(!d.hasValue());
}

test "toProperty data" {
    const d = Descriptor.data(Value.TRUE, true, false, true);
    const p = d.toProperty();
    try std.testing.expect(p.isData());
    try std.testing.expect(p.getValue().?.asBool().?);
    try std.testing.expect(p.isWritable());
    try std.testing.expect(!p.isEnumerable());
    try std.testing.expect(p.isConfigurable());
}

test "toProperty accessor" {
    const d = Descriptor.accessor(Value.TRUE, Value.FALSE, true, true);
    const p = d.toProperty();
    try std.testing.expect(p.isAccessor());
}

test "complete fills missing fields" {
    const current = Property.initData(Value.fromNumber(10.0));
    const desc = Descriptor.fromValue(Value.fromNumber(20.0));
    const completed = desc.complete(current);
    try std.testing.expectEqual(@as(f64, 20.0), completed.value.?.asNumber().?);
    try std.testing.expect(completed.writable.?);
    try std.testing.expect(completed.enumerable.?);
    try std.testing.expect(completed.configurable.?);
}

test "isCompatible configurable allows all" {
    const current = Property.initData(Value.TRUE);
    const desc = Descriptor.data(Value.FALSE, false, false, false);
    try std.testing.expect(isCompatible(current, desc));
}

test "isCompatible non-configurable rejects writable true" {
    const current = Property.initDataWith(Value.TRUE, Attributes.none());
    const desc = Descriptor{ .writable = true };
    try std.testing.expect(!isCompatible(current, desc));
}

test "isCompatible non-configurable rejects enumerable change" {
    const current = Property.initDataWith(Value.TRUE, Attributes.none());
    const desc = Descriptor{ .enumerable = true };
    try std.testing.expect(!isCompatible(current, desc));
}
