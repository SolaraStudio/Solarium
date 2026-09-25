const std = @import("std");
const value_mod = @import("../values/value.zig");

pub const Value = value_mod.Value;

pub const BindingKind = enum(u8) {
    var_,
    let_,
    const_,
    function_decl,
    class_decl,
    parameter,
    catch_param,
    import_,
    private_name,

    pub fn toString(self: BindingKind) []const u8 {
        return @tagName(self);
    }

    pub fn isMutable(self: BindingKind) bool {
        return switch (self) {
            .var_, .let_, .parameter, .catch_param => true,
            .const_, .function_decl, .class_decl, .import_, .private_name => false,
        };
    }

    pub fn isBlockScoped(self: BindingKind) bool {
        return switch (self) {
            .let_, .const_, .class_decl, .import_ => true,
            else => false,
        };
    }

    pub fn isFunctionScoped(self: BindingKind) bool {
        return switch (self) {
            .var_, .function_decl, .parameter => true,
            else => false,
        };
    }

    pub fn hasTDZ(self: BindingKind) bool {
        return switch (self) {
            .let_, .const_, .class_decl => true,
            else => false,
        };
    }
};

pub const BindingState = enum(u8) {
    uninitialized,
    initialized,
    deleted,

    pub fn toString(self: BindingState) []const u8 {
        return @tagName(self);
    }

    pub fn isUsable(self: BindingState) bool {
        return self == .initialized;
    }
};

pub const Binding = struct {
    name: []const u8,
    kind: BindingKind,
    state: BindingState,
    value: Value,
    strict: bool = false,
    immutable: bool = false,

    pub fn init(name: []const u8, kind: BindingKind) Binding {
        return .{
            .name = name,
            .kind = kind,
            .state = if (kind.hasTDZ()) .uninitialized else .initialized,
            .value = Value.UNDEFINED,
            .strict = false,
            .immutable = !kind.isMutable(),
        };
    }

    pub fn initWithValue(name: []const u8, kind: BindingKind, value: Value) Binding {
        var b = Binding.init(name, kind);
        b.value = value;
        b.state = .initialized;
        return b;
    }

    pub fn getName(self: Binding) []const u8 {
        return self.name;
    }

    pub fn getKind(self: Binding) BindingKind {
        return self.kind;
    }

    pub fn getState(self: Binding) BindingState {
        return self.state;
    }

    pub fn getValue(self: Binding) Value {
        return self.value;
    }

    pub fn isInitialized(self: Binding) bool {
        return self.state == .initialized;
    }

    pub fn isUninitialized(self: Binding) bool {
        return self.state == .uninitialized;
    }

    pub fn isDeleted(self: Binding) bool {
        return self.state == .deleted;
    }

    pub fn isMutable(self: Binding) bool {
        return !self.immutable;
    }

    pub fn isImmutable(self: Binding) bool {
        return self.immutable;
    }

    pub fn isStrict(self: Binding) bool {
        return self.strict;
    }

    pub fn setStrict(self: *Binding, strict: bool) void {
        self.strict = strict;
    }

    pub fn initialize(self: *Binding, value: Value) !void {
        if (self.state == .initialized) {
            return error.AlreadyInitialized;
        }
        self.value = value;
        self.state = .initialized;
    }

    pub fn get(self: Binding) !Value {
        return switch (self.state) {
            .uninitialized => error.TDZViolation,
            .initialized => self.value,
            .deleted => error.BindingDeleted,
        };
    }

    pub fn set(self: *Binding, value: Value) !void {
        if (self.state == .uninitialized) {
            return error.TDZViolation;
        }
        if (self.state == .deleted) {
            return error.BindingDeleted;
        }
        if (self.immutable) {
            return error.AssignmentToConstant;
        }
        self.value = value;
    }

    pub fn forceSet(self: *Binding, value: Value) void {
        self.value = value;
        self.state = .initialized;
    }

    pub fn delete(self: *Binding) !void {
        if (self.immutable) {
            return error.CannotDeleteImmutable;
        }
        self.state = .deleted;
        self.value = Value.UNDEFINED;
    }
};

pub fn create(name: []const u8, kind: BindingKind) Binding {
    return Binding.init(name, kind);
}

pub fn createWithValue(name: []const u8, kind: BindingKind, value: Value) Binding {
    return Binding.initWithValue(name, kind, value);
}

test "BindingKind toString" {
    try std.testing.expectEqualStrings("var_", BindingKind.var_.toString());
    try std.testing.expectEqualStrings("let_", BindingKind.let_.toString());
    try std.testing.expectEqualStrings("const_", BindingKind.const_.toString());
}

test "BindingKind isMutable" {
    try std.testing.expect(BindingKind.var_.isMutable());
    try std.testing.expect(BindingKind.let_.isMutable());
    try std.testing.expect(!BindingKind.const_.isMutable());
    try std.testing.expect(!BindingKind.function_decl.isMutable());
}

test "BindingKind isBlockScoped" {
    try std.testing.expect(BindingKind.let_.isBlockScoped());
    try std.testing.expect(BindingKind.const_.isBlockScoped());
    try std.testing.expect(BindingKind.class_decl.isBlockScoped());
    try std.testing.expect(!BindingKind.var_.isBlockScoped());
}

test "BindingKind isFunctionScoped" {
    try std.testing.expect(BindingKind.var_.isFunctionScoped());
    try std.testing.expect(BindingKind.function_decl.isFunctionScoped());
    try std.testing.expect(!BindingKind.let_.isFunctionScoped());
}

test "BindingKind hasTDZ" {
    try std.testing.expect(BindingKind.let_.hasTDZ());
    try std.testing.expect(BindingKind.const_.hasTDZ());
    try std.testing.expect(BindingKind.class_decl.hasTDZ());
    try std.testing.expect(!BindingKind.var_.hasTDZ());
    try std.testing.expect(!BindingKind.function_decl.hasTDZ());
}

test "BindingState toString" {
    try std.testing.expectEqualStrings("uninitialized", BindingState.uninitialized.toString());
    try std.testing.expectEqualStrings("initialized", BindingState.initialized.toString());
}

test "BindingState isUsable" {
    try std.testing.expect(BindingState.initialized.isUsable());
    try std.testing.expect(!BindingState.uninitialized.isUsable());
}

test "Binding init var" {
    const b = Binding.init("x", .var_);
    try std.testing.expectEqual(BindingState.initialized, b.getState());
    try std.testing.expect(b.isInitialized());
    try std.testing.expect(!b.isUninitialized());
}

test "Binding init let" {
    const b = Binding.init("x", .let_);
    try std.testing.expectEqual(BindingState.uninitialized, b.getState());
    try std.testing.expect(b.isUninitialized());
}

test "Binding init const" {
    const b = Binding.init("x", .const_);
    try std.testing.expect(b.isUninitialized());
    try std.testing.expect(b.isImmutable());
    try std.testing.expect(!b.isMutable());
}

test "Binding initWithValue" {
    const b = Binding.initWithValue("x", .const_, Value.fromNumber(42.0));
    try std.testing.expect(b.isInitialized());
    try std.testing.expectEqual(@as(f64, 42.0), b.getValue().asNumber().?);
}

test "Binding initialize" {
    var b = Binding.init("x", .let_);
    try b.initialize(Value.fromNumber(42.0));
    try std.testing.expect(b.isInitialized());
    try std.testing.expectEqual(@as(f64, 42.0), (try b.get()).asNumber().?);
}

test "Binding double initialize fails" {
    var b = Binding.init("x", .const_);
    try b.initialize(Value.TRUE);
    try std.testing.expectError(error.AlreadyInitialized, b.initialize(Value.FALSE));
}

test "Binding get uninitialized fails" {
    const b = Binding.init("x", .let_);
    try std.testing.expectError(error.TDZViolation, b.get());
}

test "Binding set immutable fails" {
    var b = Binding.initWithValue("x", .const_, Value.fromNumber(1.0));
    try std.testing.expectError(error.AssignmentToConstant, b.set(Value.fromNumber(2.0)));
}

test "Binding set mutable" {
    var b = Binding.initWithValue("x", .let_, Value.fromNumber(1.0));
    try b.set(Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 2.0), (try b.get()).asNumber().?);
}

test "Binding set before init fails" {
    var b = Binding.init("x", .let_);
    try std.testing.expectError(error.TDZViolation, b.set(Value.TRUE));
}

test "Binding forceSet" {
    var b = Binding.init("x", .let_);
    b.forceSet(Value.fromNumber(99.0));
    try std.testing.expectEqual(@as(f64, 99.0), (try b.get()).asNumber().?);
}

test "Binding delete mutable" {
    var b = Binding.initWithValue("x", .let_, Value.TRUE);
    try b.delete();
    try std.testing.expect(b.isDeleted());
    try std.testing.expectError(error.BindingDeleted, b.get());
}

test "Binding delete immutable fails" {
    var b = Binding.initWithValue("x", .const_, Value.TRUE);
    try std.testing.expectError(error.CannotDeleteImmutable, b.delete());
}

test "Binding strict flag" {
    var b = Binding.init("x", .let_);
    try std.testing.expect(!b.isStrict());
    b.setStrict(true);
    try std.testing.expect(b.isStrict());
}

test "create helper" {
    const b = create("x", .var_);
    try std.testing.expectEqualStrings("x", b.getName());
}

test "createWithValue helper" {
    const b = createWithValue("x", .const_, Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), b.getValue().asNumber().?);
}
