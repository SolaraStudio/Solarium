const std = @import("std");
const opcode_mod = @import("opcode.zig");

pub const OpCode = opcode_mod.OpCode;
pub const Category = opcode_mod.Category;

pub const ConstantIndex = u16;
pub const LocalIndex = u16;
pub const UpvalueIndex = u16;
pub const JumpOffset = i32;
pub const RegisterIndex = u16;

pub const MAX_CONSTANTS: usize = 65535;
pub const MAX_LOCALS: usize = 65535;
pub const MAX_UPVALUES: usize = 255;
pub const MAX_PARAMETERS: usize = 65535;
pub const MAX_STACK_SIZE: usize = 65535;

pub const BytecodeError = error{
    OutOfMemory,
    TooManyConstants,
    TooManyLocals,
    TooManyUpvalues,
    TooManyParameters,
    InvalidJump,
    InvalidOperand,
    NoCurrentFunction,
    DuplicateConstant,
};

pub const Operand = union(enum) {
    none: void,
    int8: i8,
    int16: i16,
    int32: i32,
    uint8: u8,
    uint16: u16,
    uint32: u32,
    constant: ConstantIndex,
    local: LocalIndex,
    upvalue: UpvalueIndex,
    jump: JumpOffset,
};

pub const Instruction = struct {
    op: OpCode,
    operand: Operand,
    offset: u32,

    pub fn init(op: OpCode) Instruction {
        return .{ .op = op, .operand = .{ .none = {} }, .offset = 0 };
    }

    pub fn withInt8(op: OpCode, v: i8) Instruction {
        return .{ .op = op, .operand = .{ .int8 = v }, .offset = 0 };
    }

    pub fn withInt16(op: OpCode, v: i16) Instruction {
        return .{ .op = op, .operand = .{ .int16 = v }, .offset = 0 };
    }

    pub fn withInt32(op: OpCode, v: i32) Instruction {
        return .{ .op = op, .operand = .{ .int32 = v }, .offset = 0 };
    }

    pub fn withConstant(op: OpCode, idx: ConstantIndex) Instruction {
        return .{ .op = op, .operand = .{ .constant = idx }, .offset = 0 };
    }

    pub fn withLocal(op: OpCode, idx: LocalIndex) Instruction {
        return .{ .op = op, .operand = .{ .local = idx }, .offset = 0 };
    }

    pub fn withUpvalue(op: OpCode, idx: UpvalueIndex) Instruction {
        return .{ .op = op, .operand = .{ .upvalue = idx }, .offset = 0 };
    }

    pub fn withJump(op: OpCode, offset: JumpOffset) Instruction {
        return .{ .op = op, .operand = .{ .jump = offset }, .offset = 0 };
    }

    pub fn encodedSize(self: Instruction) u8 {
        return 1 + self.op.operandSize();
    }

    pub fn isJump(self: Instruction) bool {
        return opcode_mod.isJump(self.op);
    }

    pub fn asJumpOffset(self: Instruction) ?JumpOffset {
        return switch (self.operand) {
            .jump => |j| j,
            else => null,
        };
    }

    pub fn asConstant(self: Instruction) ?ConstantIndex {
        return switch (self.operand) {
            .constant => |c| c,
            else => null,
        };
    }

    pub fn asLocal(self: Instruction) ?LocalIndex {
        return switch (self.operand) {
            .local => |l| l,
            else => null,
        };
    }
};

pub const ConstantTag = enum(u8) {
    undefined_,
    null_,
    boolean,
    integer,
    float,
    string,
    bigint,
    symbol,
    regex,

    pub fn toString(self: ConstantTag) []const u8 {
        return @tagName(self);
    }

    pub fn isPrimitive(self: ConstantTag) bool {
        return switch (self) {
            .undefined_, .null_, .boolean, .integer, .float, .string, .bigint => true,
            else => false,
        };
    }
};

pub const Constant = union(enum) {
    undefined_: void,
    null_: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    bigint: []const u8,
    symbol: u32,
    regex: RegexConstant,

    pub const RegexConstant = struct {
        pattern: []const u8,
        flags: []const u8,
    };

    pub fn tag(self: Constant) ConstantTag {
        return switch (self) {
            .undefined_ => .undefined_,
            .null_ => .null_,
            .boolean => .boolean,
            .integer => .integer,
            .float => .float,
            .string => .string,
            .bigint => .bigint,
            .symbol => .symbol,
            .regex => .regex,
        };
    }

    pub fn eql(self: Constant, other: Constant) bool {
        const t1 = self.tag();
        const t2 = other.tag();
        if (t1 != t2) return false;

        return switch (self) {
            .undefined_ => true,
            .null_ => true,
            .boolean => |a| a == other.boolean,
            .integer => |a| a == other.integer,
            .float => |a| a == other.float,
            .string => |a| std.mem.eql(u8, a, other.string),
            .bigint => |a| std.mem.eql(u8, a, other.bigint),
            .symbol => |a| a == other.symbol,
            .regex => |a| std.mem.eql(u8, a.pattern, other.regex.pattern) and
                std.mem.eql(u8, a.flags, other.regex.flags),
        };
    }
};

pub const ConstantPool = struct {
    allocator: std.mem.Allocator,
    constants: std.ArrayList(Constant),

    pub fn init(allocator: std.mem.Allocator) ConstantPool {
        return .{
            .allocator = allocator,
            .constants = .empty,
        };
    }

    pub fn deinit(self: *ConstantPool) void {
        for (self.constants.items) |c| {
            switch (c) {
                .string => |s| self.allocator.free(s),
                .bigint => |s| self.allocator.free(s),
                .regex => |r| {
                    self.allocator.free(r.pattern);
                    self.allocator.free(r.flags);
                },
                else => {},
            }
        }
        self.constants.deinit(self.allocator);
    }

    pub fn count(self: ConstantPool) usize {
        return self.constants.items.len;
    }

    pub fn add(self: *ConstantPool, c: Constant) !ConstantIndex {
        if (self.constants.items.len >= MAX_CONSTANTS) {
            return error.TooManyConstants;
        }
        const idx: ConstantIndex = @intCast(self.constants.items.len);
        try self.constants.append(self.allocator, c);
        return idx;
    }

    pub fn addOrGet(self: *ConstantPool, c: Constant) !ConstantIndex {
        for (self.constants.items, 0..) |existing, i| {
            if (existing.eql(c)) return @intCast(i);
        }
        return try self.add(c);
    }

    pub fn addString(self: *ConstantPool, s: []const u8) !ConstantIndex {
        for (self.constants.items, 0..) |existing, i| {
            if (existing == .string) {
                if (std.mem.eql(u8, existing.string, s)) return @intCast(i);
            }
        }
        const owned = try self.allocator.dupe(u8, s);
        errdefer self.allocator.free(owned);
        return try self.add(.{ .string = owned });
    }

    pub fn addInteger(self: *ConstantPool, v: i64) !ConstantIndex {
        return try self.addOrGet(.{ .integer = v });
    }

    pub fn addFloat(self: *ConstantPool, v: f64) !ConstantIndex {
        for (self.constants.items, 0..) |existing, i| {
            if (existing == .float) {
                if (@as(u64, @bitCast(existing.float)) == @as(u64, @bitCast(v))) {
                    return @intCast(i);
                }
            }
        }
        return try self.add(.{ .float = v });
    }

    pub fn addUndefined(self: *ConstantPool) !ConstantIndex {
        return try self.addOrGet(.{ .undefined_ = {} });
    }

    pub fn addNull(self: *ConstantPool) !ConstantIndex {
        return try self.addOrGet(.{ .null_ = {} });
    }

    pub fn addBoolean(self: *ConstantPool, v: bool) !ConstantIndex {
        return try self.addOrGet(.{ .boolean = v });
    }

    pub fn get(self: ConstantPool, idx: ConstantIndex) ?Constant {
        if (idx >= self.constants.items.len) return null;
        return self.constants.items[idx];
    }

    pub fn clear(self: *ConstantPool) void {
        for (self.constants.items) |c| {
            switch (c) {
                .string => |s| self.allocator.free(s),
                .bigint => |s| self.allocator.free(s),
                .regex => |r| {
                    self.allocator.free(r.pattern);
                    self.allocator.free(r.flags);
                },
                else => {},
            }
        }
        self.constants.clearRetainingCapacity();
    }
};

pub const Local = struct {
    name: []const u8,
    register: RegisterIndex,
    depth: u32,
    initialized: bool,
    is_parameter: bool,
    is_const: bool,

    pub fn init(name: []const u8, register: RegisterIndex, depth: u32) Local {
        return .{
            .name = name,
            .register = register,
            .depth = depth,
            .initialized = false,
            .is_parameter = false,
            .is_const = false,
        };
    }

    pub fn asParameter(self: Local) Local {
        var l = self;
        l.is_parameter = true;
        l.initialized = true;
        return l;
    }

    pub fn asConst(self: Local) Local {
        var l = self;
        l.is_const = true;
        return l;
    }
};

pub const Upvalue = struct {
    name: []const u8,
    index: u16,
    from_parent_local: bool,

    pub fn init(name: []const u8, index: u16, from_parent_local: bool) Upvalue {
        return .{
            .name = name,
            .index = index,
            .from_parent_local = from_parent_local,
        };
    }
};

pub const FunctionKind = enum(u8) {
    normal,
    arrow,
    method,
    getter,
    setter,
    constructor,
    generator,
    async,
    async_generator,

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
        return self == .normal or self == .constructor or self == .method;
    }
};

pub const Function = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    kind: FunctionKind,
    arity: u8,
    local_count: u16,
    register_count: u16,
    instructions: std.ArrayList(Instruction),
    constants: ConstantPool,
    locals: std.ArrayList(Local),
    upvalues: std.ArrayList(Upvalue),
    strict: bool,
    has_rest_params: bool,
    has_simple_params: bool,
    source_start: u32,
    source_end: u32,
    line_number: u32,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Function {
        return .{
            .allocator = allocator,
            .name = name,
            .kind = .normal,
            .arity = 0,
            .local_count = 0,
            .register_count = 0,
            .instructions = .empty,
            .constants = ConstantPool.init(allocator),
            .locals = .empty,
            .upvalues = .empty,
            .strict = false,
            .has_rest_params = false,
            .has_simple_params = true,
            .source_start = 0,
            .source_end = 0,
            .line_number = 0,
        };
    }

    pub fn deinit(self: *Function) void {
        self.instructions.deinit(self.allocator);
        self.constants.deinit();
        self.locals.deinit(self.allocator);
        self.upvalues.deinit(self.allocator);
    }

    pub fn instructionCount(self: Function) usize {
        return self.instructions.items.len;
    }

    pub fn localCount(self: Function) usize {
        return self.locals.items.len;
    }

    pub fn upvalueCount(self: Function) usize {
        return self.upvalues.items.len;
    }

    pub fn constantCount(self: Function) usize {
        return self.constants.count();
    }

    pub fn addInstruction(self: *Function, inst: Instruction) !usize {
        const offset: u32 = @intCast(self.instructions.items.len);
        var i = inst;
        i.offset = offset;
        try self.instructions.append(self.allocator, i);
        return self.instructions.items.len - 1;
    }

    pub fn currentOffset(self: Function) u32 {
        return @intCast(self.instructions.items.len);
    }

    pub fn patchJump(self: *Function, index: usize, target: u32) !void {
        if (index >= self.instructions.items.len) return error.InvalidJump;
        const inst = &self.instructions.items[index];
        if (!inst.isJump()) return error.InvalidJump;
        const offset = @as(i32, @intCast(target)) - @as(i32, @intCast(inst.offset));
        inst.operand = .{ .jump = offset };
    }

    pub fn addLocal(self: *Function, name: []const u8, depth: u32) !LocalIndex {
        if (self.locals.items.len >= MAX_LOCALS) {
            return error.TooManyLocals;
        }
        const register: RegisterIndex = @intCast(self.locals.items.len);
        const l = Local.init(name, register, depth);
        try self.locals.append(self.allocator, l);
        if (self.locals.items.len > self.register_count) {
            self.register_count = @intCast(self.locals.items.len);
        }
        return register;
    }

    pub fn addParameter(self: *Function, name: []const u8) !LocalIndex {
        const idx = try self.addLocal(name, 0);
        self.locals.items[idx] = self.locals.items[idx].asParameter();
        self.arity += 1;
        return idx;
    }

    pub fn findLocal(self: Function, name: []const u8) ?LocalIndex {
        var i: usize = self.locals.items.len;
        while (i > 0) {
            i -= 1;
            const l = self.locals.items[i];
            if (std.mem.eql(u8, l.name, name)) return l.register;
        }
        return null;
    }

    pub fn addUpvalue(self: *Function, name: []const u8, index: u16, from_parent_local: bool) !UpvalueIndex {
        if (self.upvalues.items.len >= MAX_UPVALUES) {
            return error.TooManyUpvalues;
        }
        const u = Upvalue.init(name, index, from_parent_local);
        try self.upvalues.append(self.allocator, u);
        return @intCast(self.upvalues.items.len - 1);
    }

    pub fn findUpvalue(self: Function, name: []const u8) ?UpvalueIndex {
        for (self.upvalues.items, 0..) |u, i| {
            if (std.mem.eql(u8, u.name, name)) return @intCast(i);
        }
        return null;
    }

    pub fn encodedSize(self: Function) usize {
        var total: usize = 0;
        for (self.instructions.items) |inst| {
            total += inst.encodedSize();
        }
        return total;
    }
};

pub const Module = struct {
    allocator: std.mem.Allocator,
    functions: std.ArrayList(*Function),
    main_function_index: u16,
    strict: bool,
    is_module: bool,

    pub fn init(allocator: std.mem.Allocator) Module {
        return .{
            .allocator = allocator,
            .functions = .empty,
            .main_function_index = 0,
            .strict = false,
            .is_module = false,
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.functions.items) |f| {
            f.deinit();
            self.allocator.destroy(f);
        }
        self.functions.deinit(self.allocator);
    }

    pub fn addFunction(self: *Module, f: *Function) !u16 {
        const idx: u16 = @intCast(self.functions.items.len);
        try self.functions.append(self.allocator, f);
        return idx;
    }

    pub fn functionCount(self: Module) usize {
        return self.functions.items.len;
    }

    pub fn getFunction(self: Module, idx: u16) ?*Function {
        if (idx >= self.functions.items.len) return null;
        return self.functions.items[idx];
    }

    pub fn mainFunction(self: Module) ?*Function {
        return self.getFunction(self.main_function_index);
    }
};

pub fn createFunction(allocator: std.mem.Allocator, name: []const u8) !*Function {
    const f = try allocator.create(Function);
    f.* = Function.init(allocator, name);
    return f;
}

pub fn createModule(allocator: std.mem.Allocator) !*Module {
    const m = try allocator.create(Module);
    m.* = Module.init(allocator);
    return m;
}

pub fn destroyModule(m: *Module) void {
    const allocator = m.allocator;
    m.deinit();
    allocator.destroy(m);
}

test "Operand init" {
    const o: Operand = .{ .none = {} };
    try std.testing.expect(o == .none);
}

test "Instruction init" {
    const i = Instruction.init(.add);
    try std.testing.expectEqual(OpCode.add, i.op);
    try std.testing.expectEqual(@as(u8, 1), i.encodedSize());
}

test "Instruction withInt8" {
    const i = Instruction.withInt8(.push_int8, 42);
    try std.testing.expectEqual(@as(i8, 42), i.operand.int8);
    try std.testing.expectEqual(@as(u8, 2), i.encodedSize());
}

test "Instruction withConstant" {
    const i = Instruction.withConstant(.push_const, 10);
    try std.testing.expectEqual(@as(ConstantIndex, 10), i.asConstant().?);
}

test "Instruction withJump" {
    const i = Instruction.withJump(.jump, 100);
    try std.testing.expectEqual(@as(JumpOffset, 100), i.asJumpOffset().?);
    try std.testing.expect(i.isJump());
}

test "ConstantTag toString" {
    try std.testing.expectEqualStrings("integer", ConstantTag.integer.toString());
    try std.testing.expectEqualStrings("string", ConstantTag.string.toString());
}

test "ConstantTag isPrimitive" {
    try std.testing.expect(ConstantTag.integer.isPrimitive());
    try std.testing.expect(ConstantTag.string.isPrimitive());
    try std.testing.expect(!ConstantTag.regex.isPrimitive());
}

test "Constant tag" {
    const c = Constant{ .integer = 42 };
    try std.testing.expectEqual(ConstantTag.integer, c.tag());
}

test "Constant eql" {
    const a = Constant{ .integer = 42 };
    const b = Constant{ .integer = 42 };
    const c = Constant{ .integer = 43 };
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
}

test "ConstantPool init" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();
    try std.testing.expectEqual(@as(usize, 0), cp.count());
}

test "ConstantPool addInteger" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const idx = try cp.addInteger(42);
    const c = cp.get(idx).?;
    try std.testing.expectEqual(@as(i64, 42), c.integer);
}

test "ConstantPool dedupes integers" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const idx1 = try cp.addInteger(42);
    const idx2 = try cp.addInteger(42);
    try std.testing.expectEqual(idx1, idx2);
    try std.testing.expectEqual(@as(usize, 1), cp.count());
}

test "ConstantPool addString deduplicates" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const s1 = try cp.addString("hello");
    const s2 = try cp.addString("hello");
    try std.testing.expectEqual(s1, s2);
}

test "ConstantPool addFloat" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const f1 = try cp.addFloat(3.14);
    const f2 = try cp.addFloat(3.14);
    try std.testing.expectEqual(f1, f2);
}

test "ConstantPool addUndefined dedupes" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const undef1 = try cp.addUndefined();
    const undef2 = try cp.addUndefined();
    try std.testing.expectEqual(undef1, undef2);
}

test "ConstantPool addBoolean" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();

    const t = try cp.addBoolean(true);
    const f = try cp.addBoolean(false);
    try std.testing.expect(t != f);
}

test "ConstantPool get out of range" {
    var cp = ConstantPool.init(std.testing.allocator);
    defer cp.deinit();
    try std.testing.expect(cp.get(0) == null);
}

test "Local init" {
    const l = Local.init("x", 0, 1);
    try std.testing.expectEqualStrings("x", l.name);
    try std.testing.expect(!l.initialized);
}

test "Local asParameter" {
    const l = Local.init("x", 0, 0).asParameter();
    try std.testing.expect(l.is_parameter);
    try std.testing.expect(l.initialized);
}

test "Local asConst" {
    const l = Local.init("x", 0, 0).asConst();
    try std.testing.expect(l.is_const);
}

test "Upvalue init" {
    const u = Upvalue.init("x", 5, true);
    try std.testing.expectEqualStrings("x", u.name);
    try std.testing.expectEqual(@as(u16, 5), u.index);
    try std.testing.expect(u.from_parent_local);
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

test "Function init" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    try std.testing.expectEqualStrings("foo", f.name);
    try std.testing.expectEqual(@as(usize, 0), f.instructionCount());
    try std.testing.expectEqual(@as(usize, 0), f.localCount());
}

test "Function addInstruction" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    _ = try f.addInstruction(Instruction.init(.add));
    try std.testing.expectEqual(@as(usize, 1), f.instructionCount());
}

test "Function addLocal" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const r = try f.addLocal("x", 0);
    try std.testing.expectEqual(@as(LocalIndex, 0), r);
    try std.testing.expectEqual(@as(usize, 1), f.localCount());
}

test "Function addParameter" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    _ = try f.addParameter("a");
    _ = try f.addParameter("b");
    try std.testing.expectEqual(@as(u8, 2), f.arity);
}

test "Function findLocal" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    _ = try f.addLocal("x", 0);
    _ = try f.addLocal("y", 0);
    try std.testing.expectEqual(@as(?LocalIndex, 1), f.findLocal("y"));
    try std.testing.expect(f.findLocal("z") == null);
}

test "Function addUpvalue" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const u = try f.addUpvalue("x", 0, true);
    try std.testing.expectEqual(@as(UpvalueIndex, 0), u);
    try std.testing.expectEqual(@as(usize, 1), f.upvalueCount());
}

test "Function findUpvalue" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    _ = try f.addUpvalue("x", 0, true);
    try std.testing.expectEqual(@as(?UpvalueIndex, 0), f.findUpvalue("x"));
}

test "Function patchJump" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const idx = try f.addInstruction(Instruction.withJump(.jump, 0));
    try f.patchJump(idx, 10);
    const inst = f.instructions.items[idx];
    try std.testing.expectEqual(@as(JumpOffset, 10), inst.asJumpOffset().?);
}

test "Function patchJump invalid" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const idx = try f.addInstruction(Instruction.init(.add));
    try std.testing.expectError(error.InvalidJump, f.patchJump(idx, 10));
}

test "Function encodedSize" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    _ = try f.addInstruction(Instruction.init(.add));
    _ = try f.addInstruction(Instruction.withConstant(.push_const, 0));
    try std.testing.expect(f.encodedSize() >= 4);
}

test "Module init" {
    var m = Module.init(std.testing.allocator);
    defer m.deinit();
    try std.testing.expectEqual(@as(usize, 0), m.functionCount());
}

test "Module addFunction" {
    var m = Module.init(std.testing.allocator);
    defer m.deinit();

    const f = try createFunction(std.testing.allocator, "main");
    _ = try m.addFunction(f);
    try std.testing.expectEqual(@as(usize, 1), m.functionCount());
}

test "Module getFunction" {
    var m = Module.init(std.testing.allocator);
    defer m.deinit();

    const f = try createFunction(std.testing.allocator, "main");
    const idx = try m.addFunction(f);
    try std.testing.expectEqual(f, m.getFunction(idx).?);
}

test "createFunction helper" {
    const f = try createFunction(std.testing.allocator, "foo");
    defer {
        f.deinit();
        std.testing.allocator.destroy(f);
    }
    try std.testing.expectEqualStrings("foo", f.name);
}

test "createModule and destroyModule" {
    const m = try createModule(std.testing.allocator);
    destroyModule(m);
}
