const std = @import("std");
const value_mod = @import("../values/value.zig");
const Value = value_mod.Value;

pub const SlotId = enum(u8) {
    prototype,
    extensible,
    class_name,
    primitive_value,

    bound_target_function,
    bound_this,
    bound_arguments,

    proxy_target,
    proxy_handler,

    regexp_matcher,
    regexp_flags,

    date_value,

    array_length,

    error_data,

    promise_state,
    promise_result,
    promise_reactions,
    promise_is_handled,

    map_data,
    set_data,

    weakmap_data,
    weakset_data,

    array_buffer_data,
    typed_array_buffer,
    typed_array_length,
    typed_array_byte_offset,

    function_environment,
    function_strict,
    function_this_mode,
    function_home_object,

    module_namespace,
    module_status,

    string_wrapper_primitive,
    number_wrapper_primitive,
    boolean_wrapper_primitive,
    symbol_wrapper_primitive,
    bigint_wrapper_primitive,

    host_defined,

    pub fn toString(self: SlotId) []const u8 {
        return @tagName(self);
    }

    pub fn isOrdinary(self: SlotId) bool {
        return self == .prototype or self == .extensible;
    }

    pub fn isExotic(self: SlotId) bool {
        return !self.isOrdinary();
    }
};

pub const Slot = struct {
    id: SlotId,
    value: Value,

    pub fn init(id: SlotId, value: Value) Slot {
        return .{ .id = id, .value = value };
    }

    pub fn matches(self: Slot, id: SlotId) bool {
        return self.id == id;
    }
};

pub const SlotStore = struct {
    allocator: std.mem.Allocator,
    slots: std.ArrayList(Slot),

    pub fn init(allocator: std.mem.Allocator) SlotStore {
        return .{
            .allocator = allocator,
            .slots = .empty,
        };
    }

    pub fn deinit(self: *SlotStore) void {
        self.slots.deinit(self.allocator);
    }

    pub fn count(self: SlotStore) usize {
        return self.slots.items.len;
    }

    pub fn get(self: SlotStore, id: SlotId) ?Value {
        for (self.slots.items) |slot| {
            if (slot.id == id) return slot.value;
        }
        return null;
    }

    pub fn set(self: *SlotStore, id: SlotId, value: Value) !void {
        for (self.slots.items) |*slot| {
            if (slot.id == id) {
                slot.value = value;
                return;
            }
        }
        try self.slots.append(self.allocator, Slot.init(id, value));
    }

    pub fn has(self: SlotStore, id: SlotId) bool {
        for (self.slots.items) |slot| {
            if (slot.id == id) return true;
        }
        return false;
    }

    pub fn remove(self: *SlotStore, id: SlotId) bool {
        var i: usize = 0;
        while (i < self.slots.items.len) : (i += 1) {
            if (self.slots.items[i].id == id) {
                _ = self.slots.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn clear(self: *SlotStore) void {
        self.slots.clearRetainingCapacity();
    }

    pub fn listIds(self: SlotStore, allocator: std.mem.Allocator) ![]SlotId {
        const out = try allocator.alloc(SlotId, self.slots.items.len);
        for (self.slots.items, 0..) |slot, i| {
            out[i] = slot.id;
        }
        return out;
    }
};

pub fn create(allocator: std.mem.Allocator) SlotStore {
    return SlotStore.init(allocator);
}

test "SlotId toString" {
    try std.testing.expectEqualStrings("prototype", SlotId.prototype.toString());
    try std.testing.expectEqualStrings("array_length", SlotId.array_length.toString());
}

test "SlotId isOrdinary" {
    try std.testing.expect(SlotId.prototype.isOrdinary());
    try std.testing.expect(SlotId.extensible.isOrdinary());
    try std.testing.expect(!SlotId.array_length.isOrdinary());
}

test "SlotId isExotic" {
    try std.testing.expect(SlotId.array_length.isExotic());
    try std.testing.expect(!SlotId.prototype.isExotic());
}

test "Slot init" {
    const s = Slot.init(.prototype, Value.TRUE);
    try std.testing.expect(s.matches(.prototype));
    try std.testing.expect(!s.matches(.extensible));
}

test "SlotStore init" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();
    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "SlotStore set and get" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try store.set(.prototype, Value.TRUE);
    try std.testing.expect(store.get(.prototype).?.asBool().?);
}

test "SlotStore set overrides" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try store.set(.extensible, Value.TRUE);
    try store.set(.extensible, Value.FALSE);
    try std.testing.expect(!store.get(.extensible).?.asBool().?);
    try std.testing.expectEqual(@as(usize, 1), store.count());
}

test "SlotStore has" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expect(!store.has(.prototype));
    try store.set(.prototype, Value.TRUE);
    try std.testing.expect(store.has(.prototype));
}

test "SlotStore remove" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try store.set(.prototype, Value.TRUE);
    try std.testing.expect(store.remove(.prototype));
    try std.testing.expect(!store.has(.prototype));
    try std.testing.expect(!store.remove(.prototype));
}

test "SlotStore clear" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try store.set(.prototype, Value.TRUE);
    try store.set(.extensible, Value.TRUE);
    store.clear();
    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "SlotStore listIds" {
    var store = SlotStore.init(std.testing.allocator);
    defer store.deinit();

    try store.set(.prototype, Value.TRUE);
    try store.set(.extensible, Value.FALSE);

    const ids = try store.listIds(std.testing.allocator);
    defer std.testing.allocator.free(ids);
    try std.testing.expectEqual(@as(usize, 2), ids.len);
}

test "create helper" {
    var store = create(std.testing.allocator);
    defer store.deinit();
    try std.testing.expectEqual(@as(usize, 0), store.count());
}
