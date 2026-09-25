const std = @import("std");
const bytecode = @import("bytecode.zig");

pub const LocalIndex = bytecode.LocalIndex;
pub const UpvalueIndex = bytecode.UpvalueIndex;
pub const Local = bytecode.Local;
pub const Upvalue = bytecode.Upvalue;

pub const ScopeKind = enum(u8) {
    global,
    module,
    function,
    block,
    loop,
    catch_clause,
    with_stmt,
    class_body,
    switch_body,

    pub fn toString(self: ScopeKind) []const u8 {
        return @tagName(self);
    }

    pub fn isFunctionBoundary(self: ScopeKind) bool {
        return switch (self) {
            .global, .module, .function => true,
            else => false,
        };
    }

    pub fn isBlockScoped(self: ScopeKind) bool {
        return !self.isFunctionBoundary();
    }

    pub fn isLoop(self: ScopeKind) bool {
        return self == .loop;
    }
};

pub const BindingKind = enum(u8) {
    var_,
    let_,
    const_,
    parameter,
    function_decl,
    class_decl,
    catch_param,
    import_,
    this_,
    arguments_,

    pub fn toString(self: BindingKind) []const u8 {
        return @tagName(self);
    }

    pub fn isMutable(self: BindingKind) bool {
        return switch (self) {
            .var_, .let_, .parameter, .catch_param, .this_, .arguments_ => true,
            .const_, .function_decl, .class_decl, .import_ => false,
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

    pub fn isVariable(self: BindingKind) bool {
        return switch (self) {
            .var_, .let_, .const_ => true,
            else => false,
        };
    }
};

pub const Binding = struct {
    name: []const u8,
    kind: BindingKind,
    register: LocalIndex,
    depth: u32,
    initialized: bool,
    captured: bool,
    is_hoisted: bool,

    pub fn init(name: []const u8, kind: BindingKind, register: LocalIndex, depth: u32) Binding {
        return .{
            .name = name,
            .kind = kind,
            .register = register,
            .depth = depth,
            .initialized = !kind.hasTDZ(),
            .captured = false,
            .is_hoisted = false,
        };
    }

    pub fn initializedBinding(name: []const u8, kind: BindingKind, register: LocalIndex, depth: u32) Binding {
        var b = Binding.init(name, kind, register, depth);
        b.initialized = true;
        return b;
    }

    pub fn hoisted(self: Binding) Binding {
        var b = self;
        b.is_hoisted = true;
        return b;
    }

    pub fn capture(self: Binding) Binding {
        var b = self;
        b.captured = true;
        return b;
    }
};

pub const Scope = struct {
    allocator: std.mem.Allocator,
    parent: ?*Scope,
    kind: ScopeKind,
    bindings: std.ArrayList(Binding),
    depth: u32,
    has_this: bool,
    has_arguments: bool,
    has_direct_eval: bool,

    pub fn init(allocator: std.mem.Allocator, kind: ScopeKind, parent: ?*Scope) Scope {
        return .{
            .allocator = allocator,
            .parent = parent,
            .kind = kind,
            .bindings = .empty,
            .depth = if (parent) |p| p.depth + 1 else 0,
            .has_this = false,
            .has_arguments = false,
            .has_direct_eval = false,
        };
    }

    pub fn deinit(self: *Scope) void {
        self.bindings.deinit(self.allocator);
    }

    pub fn bindingCount(self: Scope) usize {
        return self.bindings.items.len;
    }

    pub fn addBinding(self: *Scope, b: Binding) !void {
        try self.bindings.append(self.allocator, b);
    }

    pub fn addLocal(
        self: *Scope,
        name: []const u8,
        kind: BindingKind,
        register: LocalIndex,
    ) !*Binding {
        const b = Binding.init(name, kind, register, self.depth);
        try self.bindings.append(self.allocator, b);
        return &self.bindings.items[self.bindings.items.len - 1];
    }

    pub fn addHoisted(
        self: *Scope,
        name: []const u8,
        kind: BindingKind,
        register: LocalIndex,
    ) !*Binding {
        const b = Binding.init(name, kind, register, self.depth).hoisted();
        try self.bindings.append(self.allocator, b);
        return &self.bindings.items[self.bindings.items.len - 1];
    }

    pub fn addParameter(
        self: *Scope,
        name: []const u8,
        register: LocalIndex,
    ) !*Binding {
        const b = Binding.initializedBinding(name, .parameter, register, self.depth);
        try self.bindings.append(self.allocator, b);
        return &self.bindings.items[self.bindings.items.len - 1];
    }

    pub fn findOwn(self: *Scope, name: []const u8) ?*Binding {
        var i: usize = self.bindings.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.bindings.items[i].name, name)) {
                return &self.bindings.items[i];
            }
        }
        return null;
    }

    pub fn find(self: *Scope, name: []const u8) ?*Binding {
        if (self.findOwn(name)) |b| return b;
        if (self.parent) |p| return p.find(name);
        return null;
    }

    pub fn hasOwn(self: *Scope, name: []const u8) bool {
        return self.findOwn(name) != null;
    }

    pub fn has(self: *Scope, name: []const u8) bool {
        return self.find(name) != null;
    }

    pub fn markCaptured(self: *Scope, name: []const u8) void {
        if (self.find(name)) |b| {
            b.captured = true;
        }
    }

    pub fn markInitialized(self: *Scope, name: []const u8) void {
        if (self.find(name)) |b| {
            b.initialized = true;
        }
    }

    pub fn markHasThis(self: *Scope) void {
        self.has_this = true;
    }

    pub fn markHasArguments(self: *Scope) void {
        self.has_arguments = true;
    }

    pub fn markHasDirectEval(self: *Scope) void {
        self.has_direct_eval = true;
    }

    pub fn nearestFunctionScope(self: *Scope) *Scope {
        var current: *Scope = self;
        while (!current.kind.isFunctionBoundary()) {
            current = current.parent orelse return current;
        }
        return current;
    }

    pub fn nearestLoopScope(self: *Scope) ?*Scope {
        var current: ?*Scope = self;
        while (current) |s| {
            if (s.kind.isLoop()) return s;
            current = s.parent;
        }
        return null;
    }

    pub fn countBindings(self: *Scope) usize {
        var total: usize = self.bindings.items.len;
        if (self.parent) |p| {
            total += p.countBindings();
        }
        return total;
    }

    pub fn childCount(self: *Scope, kind: ScopeKind) usize {
        var count: usize = 0;
        for (self.bindings.items) |b| {
            if (b.kind == bindingKindFromScopeKind(kind)) count += 1;
        }
        return count;
    }

    fn bindingKindFromScopeKind(kind: ScopeKind) BindingKind {
        return switch (kind) {
            .function, .global, .module => .function_decl,
            .loop => .let_,
            .catch_clause => .catch_param,
            else => .let_,
        };
    }
};

pub const ScopeStack = struct {
    allocator: std.mem.Allocator,
    scopes: std.ArrayList(*Scope),
    current: ?*Scope,

    pub fn init(allocator: std.mem.Allocator) ScopeStack {
        return .{
            .allocator = allocator,
            .scopes = .empty,
            .current = null,
        };
    }

    pub fn deinit(self: *ScopeStack) void {
        for (self.scopes.items) |scope| {
            scope.deinit();
            self.allocator.destroy(scope);
        }
        self.scopes.deinit(self.allocator);
    }

    pub fn push(self: *ScopeStack, kind: ScopeKind) !*Scope {
        const scope = try self.allocator.create(Scope);
        scope.* = Scope.init(self.allocator, kind, self.current);
        try self.scopes.append(self.allocator, scope);
        self.current = scope;
        return scope;
    }

    pub fn pop(self: *ScopeStack) ?*Scope {
        const scope = self.current orelse return null;
        self.current = scope.parent;
        return scope;
    }

    pub fn currentScope(self: ScopeStack) ?*Scope {
        return self.current;
    }

    pub fn depth(self: ScopeStack) usize {
        return self.scopes.items.len;
    }

    pub fn inFunction(self: ScopeStack) bool {
        var current = self.current;
        while (current) |s| {
            if (s.kind.isFunctionBoundary()) return true;
            current = s.parent;
        }
        return false;
    }

    pub fn inLoop(self: ScopeStack) bool {
        var current = self.current;
        while (current) |s| {
            if (s.kind.isLoop()) return true;
            current = s.parent;
        }
        return false;
    }

    pub fn resolve(self: ScopeStack, name: []const u8) ?*Binding {
        const scope = self.current orelse return null;
        return scope.find(name);
    }

    pub fn ownScope(self: ScopeStack) ?*Scope {
        return self.current;
    }
};

pub const CaptureInfo = struct {
    name: []const u8,
    source_scope_depth: u32,
    from_parent_local: bool,

    pub fn init(name: []const u8, source_scope_depth: u32, from_parent_local: bool) CaptureInfo {
        return .{
            .name = name,
            .source_scope_depth = source_scope_depth,
            .from_parent_local = from_parent_local,
        };
    }
};

pub fn findCapturePath(inner: *Scope, name: []const u8) ?[]CaptureInfo {
    _ = inner;
    _ = name;
    return null;
}

test "ScopeKind toString" {
    try std.testing.expectEqualStrings("global", ScopeKind.global.toString());
    try std.testing.expectEqualStrings("function", ScopeKind.function.toString());
    try std.testing.expectEqualStrings("loop", ScopeKind.loop.toString());
}

test "ScopeKind isFunctionBoundary" {
    try std.testing.expect(ScopeKind.global.isFunctionBoundary());
    try std.testing.expect(ScopeKind.function.isFunctionBoundary());
    try std.testing.expect(ScopeKind.module.isFunctionBoundary());
    try std.testing.expect(!ScopeKind.block.isFunctionBoundary());
}

test "ScopeKind isBlockScoped" {
    try std.testing.expect(ScopeKind.block.isBlockScoped());
    try std.testing.expect(!ScopeKind.global.isBlockScoped());
}

test "ScopeKind isLoop" {
    try std.testing.expect(ScopeKind.loop.isLoop());
    try std.testing.expect(!ScopeKind.block.isLoop());
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
    try std.testing.expect(!BindingKind.var_.hasTDZ());
}

test "BindingKind isVariable" {
    try std.testing.expect(BindingKind.var_.isVariable());
    try std.testing.expect(BindingKind.let_.isVariable());
    try std.testing.expect(BindingKind.const_.isVariable());
    try std.testing.expect(!BindingKind.parameter.isVariable());
}

test "Binding init var" {
    const b = Binding.init("x", .var_, 0, 0);
    try std.testing.expect(b.initialized);
    try std.testing.expect(!b.captured);
}

test "Binding init let has TDZ" {
    const b = Binding.init("x", .let_, 0, 0);
    try std.testing.expect(!b.initialized);
}

test "Binding initializedBinding" {
    const b = Binding.initializedBinding("x", .let_, 0, 0);
    try std.testing.expect(b.initialized);
}

test "Binding hoisted" {
    const b = Binding.init("x", .var_, 0, 0).hoisted();
    try std.testing.expect(b.is_hoisted);
}

test "Binding capture" {
    const b = Binding.init("x", .var_, 0, 0).capture();
    try std.testing.expect(b.captured);
}

test "Scope init" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.bindingCount());
    try std.testing.expectEqual(@as(u32, 0), s.depth);
    try std.testing.expect(s.parent == null);
}

test "Scope depth increments" {
    var parent = Scope.init(std.testing.allocator, .function, null);
    defer parent.deinit();

    var child = Scope.init(std.testing.allocator, .block, &parent);
    defer child.deinit();

    try std.testing.expectEqual(@as(u32, 1), child.depth);
}

test "Scope addLocal" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    _ = try s.addLocal("x", .let_, 0);
    try std.testing.expectEqual(@as(usize, 1), s.bindingCount());
    try std.testing.expect(s.hasOwn("x"));
}

test "Scope addHoisted" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    const b = try s.addHoisted("x", .var_, 0);
    try std.testing.expect(b.is_hoisted);
}

test "Scope addParameter" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    const b = try s.addParameter("x", 0);
    try std.testing.expectEqual(BindingKind.parameter, b.kind);
    try std.testing.expect(b.initialized);
}

test "Scope findOwn" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    _ = try s.addLocal("x", .let_, 0);
    try std.testing.expect(s.findOwn("x") != null);
    try std.testing.expect(s.findOwn("y") == null);
}

test "Scope find walks parents" {
    var parent = Scope.init(std.testing.allocator, .function, null);
    defer parent.deinit();
    _ = try parent.addLocal("x", .var_, 0);

    var child = Scope.init(std.testing.allocator, .block, &parent);
    defer child.deinit();

    try std.testing.expect(child.find("x") != null);
    try std.testing.expect(!child.hasOwn("x"));
}

test "Scope markCaptured" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    _ = try s.addLocal("x", .var_, 0);
    s.markCaptured("x");
    try std.testing.expect(s.findOwn("x").?.captured);
}

test "Scope markInitialized" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    _ = try s.addLocal("x", .let_, 0);
    try std.testing.expect(!s.findOwn("x").?.initialized);
    s.markInitialized("x");
    try std.testing.expect(s.findOwn("x").?.initialized);
}

test "Scope markHasThis" {
    var s = Scope.init(std.testing.allocator, .function, null);
    defer s.deinit();

    try std.testing.expect(!s.has_this);
    s.markHasThis();
    try std.testing.expect(s.has_this);
}

test "Scope nearestFunctionScope" {
    var global_scope = Scope.init(std.testing.allocator, .global, null);
    defer global_scope.deinit();

    var fn_scope = Scope.init(std.testing.allocator, .function, &global_scope);
    defer fn_scope.deinit();

    var block_scope = Scope.init(std.testing.allocator, .block, &fn_scope);
    defer block_scope.deinit();

    try std.testing.expectEqual(&fn_scope, block_scope.nearestFunctionScope());
}

test "Scope nearestLoopScope" {
    var fn_scope = Scope.init(std.testing.allocator, .function, null);
    defer fn_scope.deinit();

    var loop_scope = Scope.init(std.testing.allocator, .loop, &fn_scope);
    defer loop_scope.deinit();

    var block_scope = Scope.init(std.testing.allocator, .block, &loop_scope);
    defer block_scope.deinit();

    try std.testing.expectEqual(&loop_scope, block_scope.nearestLoopScope().?);
}

test "ScopeStack init" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();
    try std.testing.expectEqual(@as(usize, 0), stack.depth());
}

test "ScopeStack push" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    _ = try stack.push(.function);
    try std.testing.expectEqual(@as(usize, 1), stack.depth());
}

test "ScopeStack pop" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    _ = try stack.push(.function);
    const popped = stack.pop();
    try std.testing.expect(popped != null);
    try std.testing.expectEqual(@as(usize, 1), stack.depth());
    try std.testing.expect(stack.current == null);
}

test "ScopeStack nested" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    _ = try stack.push(.function);
    _ = try stack.push(.block);
    _ = try stack.push(.loop);
    try std.testing.expectEqual(@as(usize, 3), stack.depth());
}

test "ScopeStack inFunction" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    _ = try stack.push(.function);
    _ = try stack.push(.block);
    try std.testing.expect(stack.inFunction());
}

test "ScopeStack inLoop" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    _ = try stack.push(.function);
    _ = try stack.push(.loop);
    try std.testing.expect(stack.inLoop());

    _ = stack.pop();
    try std.testing.expect(!stack.inLoop());
}

test "ScopeStack resolve" {
    var stack = ScopeStack.init(std.testing.allocator);
    defer stack.deinit();

    const fn_scope = try stack.push(.function);
    _ = try fn_scope.addLocal("x", .var_, 0);

    const b = stack.resolve("x");
    try std.testing.expect(b != null);
}

test "CaptureInfo init" {
    const c = CaptureInfo.init("x", 1, true);
    try std.testing.expectEqualStrings("x", c.name);
    try std.testing.expectEqual(@as(u32, 1), c.source_scope_depth);
    try std.testing.expect(c.from_parent_local);
}
