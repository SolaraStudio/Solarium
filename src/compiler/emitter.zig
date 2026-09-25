const std = @import("std");
const opcode_mod = @import("opcode.zig");
const bytecode = @import("bytecode.zig");
const scope_mod = @import("scope.zig");

pub const OpCode = opcode_mod.OpCode;
pub const Instruction = bytecode.Instruction;
pub const Function = bytecode.Function;
pub const ConstantPool = bytecode.ConstantPool;
pub const ConstantIndex = bytecode.ConstantIndex;
pub const LocalIndex = bytecode.LocalIndex;
pub const UpvalueIndex = bytecode.UpvalueIndex;
pub const JumpOffset = bytecode.JumpOffset;

pub const EmitError = error{
    OutOfMemory,
    TooManyConstants,
    TooManyLocals,
    TooManyUpvalues,
    InvalidJump,
    NoCurrentFunction,
    InvalidOperand,
};

pub const JumpTarget = struct {
    instruction_index: usize,
    patched: bool,

    pub fn init(index: usize) JumpTarget {
        return .{ .instruction_index = index, .patched = false };
    }
};

pub const LoopContext = struct {
    start_offset: u32,
    break_jumps: std.ArrayList(usize),
    continue_jumps: std.ArrayList(usize),
    label: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, start_offset: u32) LoopContext {
        _ = allocator;
        return .{
            .start_offset = start_offset,
            .break_jumps = std.ArrayList(usize).empty,
            .continue_jumps = std.ArrayList(usize).empty,
            .label = null,
        };
    }

    pub fn deinit(self: *LoopContext, allocator: std.mem.Allocator) void {
        self.break_jumps.deinit(allocator);
        self.continue_jumps.deinit(allocator);
    }
};

pub const TryContext = struct {
    try_start: u32,
    catch_target: ?u32,
    finally_target: ?u32,
    end_target: ?u32,

    pub fn init(try_start: u32) TryContext {
        return .{
            .try_start = try_start,
            .catch_target = null,
            .finally_target = null,
            .end_target = null,
        };
    }
};

pub const Emitter = struct {
    allocator: std.mem.Allocator,
    function: *Function,
    loops: std.ArrayList(LoopContext),
    tries: std.ArrayList(TryContext),
    last_line: u32,

    pub fn init(allocator: std.mem.Allocator, function: *Function) Emitter {
        return .{
            .allocator = allocator,
            .function = function,
            .loops = .empty,
            .tries = .empty,
            .last_line = 0,
        };
    }

    pub fn deinit(self: *Emitter) void {
        for (self.loops.items) |*l| {
            l.deinit(self.allocator);
        }
        self.loops.deinit(self.allocator);
        self.tries.deinit(self.allocator);
    }

    pub fn currentOffset(self: Emitter) u32 {
        return self.function.currentOffset();
    }

    pub fn emit(self: *Emitter, op: OpCode) EmitError!usize {
        return try self.function.addInstruction(Instruction.init(op));
    }

    pub fn emitInt8(self: *Emitter, op: OpCode, v: i8) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt8(op, v));
    }

    pub fn emitInt16(self: *Emitter, op: OpCode, v: i16) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt16(op, v));
    }

    pub fn emitInt32(self: *Emitter, op: OpCode, v: i32) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt32(op, v));
    }

    pub fn emitConstant(self: *Emitter, op: OpCode, idx: ConstantIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withConstant(op, idx));
    }

    pub fn emitLoadLocal(self: *Emitter, idx: LocalIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withLocal(.load_local, idx));
    }

    pub fn emitStoreLocal(self: *Emitter, idx: LocalIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withLocal(.store_local, idx));
    }

    pub fn emitLoadGlobal(self: *Emitter, idx: ConstantIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withConstant(.load_global, idx));
    }

    pub fn emitStoreGlobal(self: *Emitter, idx: ConstantIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withConstant(.store_global, idx));
    }

    pub fn emitLoadUpvalue(self: *Emitter, idx: UpvalueIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withUpvalue(.load_upvalue, idx));
    }

    pub fn emitStoreUpvalue(self: *Emitter, idx: UpvalueIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withUpvalue(.store_upvalue, idx));
    }

    pub fn emitJump(self: *Emitter, op: OpCode) EmitError!usize {
        return try self.function.addInstruction(Instruction.withJump(op, 0));
    }

    pub fn patchJump(self: *Emitter, index: usize) EmitError!void {
        const target = self.function.currentOffset();
        try self.function.patchJump(index, target);
    }

    pub fn patchJumpTo(self: *Emitter, index: usize, target: u32) EmitError!void {
        try self.function.patchJump(index, target);
    }

    pub fn emitJumpBack(self: *Emitter, target: u32) EmitError!usize {
        const current = self.function.currentOffset();
        const offset = @as(i32, @intCast(target)) - @as(i32, @intCast(current));
        return try self.function.addInstruction(Instruction.withJump(.jump_back, offset));
    }

    pub fn addConstant(self: *Emitter, c: bytecode.Constant) EmitError!ConstantIndex {
        return try self.function.constants.add(c);
    }

    pub fn addStringConstant(self: *Emitter, s: []const u8) EmitError!ConstantIndex {
        return try self.function.constants.addString(s);
    }

    pub fn addIntegerConstant(self: *Emitter, v: i64) EmitError!ConstantIndex {
        return try self.function.constants.addInteger(v);
    }

    pub fn addFloatConstant(self: *Emitter, v: f64) EmitError!ConstantIndex {
        return try self.function.constants.addFloat(v);
    }

    pub fn addBooleanConstant(self: *Emitter, v: bool) EmitError!ConstantIndex {
        return try self.function.constants.addBoolean(v);
    }

    pub fn addUndefinedConstant(self: *Emitter) EmitError!ConstantIndex {
        return try self.function.constants.addUndefined();
    }

    pub fn addNullConstant(self: *Emitter) EmitError!ConstantIndex {
        return try self.function.constants.addNull();
    }

    pub fn pushUndefined(self: *Emitter) EmitError!usize {
        return try self.emit(.push_undefined);
    }

    pub fn pushNull(self: *Emitter) EmitError!usize {
        return try self.emit(.push_null);
    }

    pub fn pushTrue(self: *Emitter) EmitError!usize {
        return try self.emit(.push_true);
    }

    pub fn pushFalse(self: *Emitter) EmitError!usize {
        return try self.emit(.push_false);
    }

    pub fn pushZero(self: *Emitter) EmitError!usize {
        return try self.emit(.push_zero);
    }

    pub fn pushOne(self: *Emitter) EmitError!usize {
        return try self.emit(.push_one);
    }

    pub fn pushInt(self: *Emitter, v: i64) EmitError!usize {
        if (v == 0) return try self.pushZero();
        if (v == 1) return try self.pushOne();
        if (v >= -128 and v <= 127) return try self.emitInt8(.push_int8, @intCast(v));
        if (v >= -32768 and v <= 32767) return try self.emitInt16(.push_int16, @intCast(v));
        if (v >= -2147483648 and v <= 2147483647) return try self.emitInt32(.push_int32, @intCast(v));
        const idx = try self.addIntegerConstant(v);
        return try self.emitConstant(.push_const, idx);
    }

    pub fn pushNumber(self: *Emitter, v: f64) EmitError!usize {
        if (v == 0.0) return try self.pushZero();
        if (v == 1.0) return try self.pushOne();
        const idx = try self.addFloatConstant(v);
        return try self.emitConstant(.push_const, idx);
    }

    pub fn pushString(self: *Emitter, s: []const u8) EmitError!usize {
        const idx = try self.addStringConstant(s);
        return try self.emitConstant(.push_string, idx);
    }

    pub fn pushBoolean(self: *Emitter, v: bool) EmitError!usize {
        return if (v) try self.pushTrue() else try self.pushFalse();
    }

    pub fn beginLoop(self: *Emitter, label: ?[]const u8) EmitError!void {
        const start = self.function.currentOffset();
        var ctx = LoopContext.init(self.allocator, start);
        ctx.label = label;
        try self.loops.append(self.allocator, ctx);
    }

    pub fn endLoop(self: *Emitter) EmitError!void {
        if (self.loops.items.len == 0) return;
        const end_target = self.function.currentOffset();
        const ctx = self.loops.pop() orelse return;

        for (ctx.break_jumps.items) |jump_idx| {
            try self.function.patchJump(jump_idx, end_target);
        }
        for (ctx.continue_jumps.items) |jump_idx| {
            try self.function.patchJump(jump_idx, ctx.start_offset);
        }

        var owned = ctx;
        owned.deinit(self.allocator);
    }

    pub fn emitBreak(self: *Emitter) EmitError!void {
        const jump_idx = try self.emitJump(.jump);
        if (self.loops.items.len > 0) {
            const ctx = &self.loops.items[self.loops.items.len - 1];
            try ctx.break_jumps.append(self.allocator, jump_idx);
        }
    }

    pub fn emitContinue(self: *Emitter) EmitError!void {
        const jump_idx = try self.emitJump(.jump);
        if (self.loops.items.len > 0) {
            const ctx = &self.loops.items[self.loops.items.len - 1];
            try ctx.continue_jumps.append(self.allocator, jump_idx);
        }
    }

    pub fn currentLoop(self: *Emitter) ?*LoopContext {
        if (self.loops.items.len == 0) return null;
        return &self.loops.items[self.loops.items.len - 1];
    }

    pub fn pushTry(self: *Emitter) EmitError!void {
        const start = self.function.currentOffset();
        const ctx = TryContext.init(start);
        try self.tries.append(self.allocator, ctx);
        _ = try self.emit(.try_push);
    }

    pub fn popTry(self: *Emitter) EmitError!void {
        _ = try self.emit(.try_pop);
        if (self.tries.items.len > 0) {
            _ = self.tries.pop();
        }
    }

    pub fn emitBinary(self: *Emitter, op: OpCode) EmitError!usize {
        return try self.emit(op);
    }

    pub fn emitUnary(self: *Emitter, op: OpCode) EmitError!usize {
        return try self.emit(op);
    }

    pub fn emitCall(self: *Emitter, arg_count: u8) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt8(.call, @intCast(arg_count)));
    }

    pub fn emitCallMethod(self: *Emitter, arg_count: u8) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt8(.call_method, @intCast(arg_count)));
    }

    pub fn emitNew(self: *Emitter, arg_count: u8) EmitError!usize {
        return try self.function.addInstruction(Instruction.withInt8(.new_, @intCast(arg_count)));
    }

    pub fn emitGetProperty(self: *Emitter, name_idx: ConstantIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withConstant(.get_property, name_idx));
    }

    pub fn emitSetProperty(self: *Emitter, name_idx: ConstantIndex) EmitError!usize {
        return try self.function.addInstruction(Instruction.withConstant(.set_property, name_idx));
    }

    pub fn emitReturn(self: *Emitter) EmitError!usize {
        return try self.emit(.return_);
    }

    pub fn emitReturnUndefined(self: *Emitter) EmitError!usize {
        return try self.emit(.return_undefined);
    }

    pub fn emitHalt(self: *Emitter) EmitError!usize {
        return try self.emit(.halt);
    }

    pub fn setLine(self: *Emitter, line: u32) void {
        self.last_line = line;
    }

    pub fn defineParameter(self: *Emitter, name: []const u8) EmitError!LocalIndex {
        return try self.function.addParameter(name);
    }

    pub fn defineLocal(self: *Emitter, name: []const u8, depth: u32) EmitError!LocalIndex {
        return try self.function.addLocal(name, depth);
    }

    pub fn findLocal(self: *Emitter, name: []const u8) ?LocalIndex {
        return self.function.findLocal(name);
    }

    pub fn addUpvalue(self: *Emitter, name: []const u8, index: u16, from_parent_local: bool) EmitError!UpvalueIndex {
        return try self.function.addUpvalue(name, index, from_parent_local);
    }

    pub fn findUpvalue(self: *Emitter, name: []const u8) ?UpvalueIndex {
        return self.function.findUpvalue(name);
    }
};

pub fn create(allocator: std.mem.Allocator, function: *Function) Emitter {
    return Emitter.init(allocator, function);
}

test "Emitter init" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try std.testing.expectEqual(@as(usize, 0), f.instructionCount());
}

test "Emitter emit" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.emit(.nop);
    try std.testing.expectEqual(@as(usize, 1), f.instructionCount());
}

test "Emitter emitInt8" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.emitInt8(.push_int8, 42);
    try std.testing.expectEqual(@as(i8, 42), f.instructions.items[0].operand.int8);
}

test "Emitter pushInt zero" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushInt(0);
    try std.testing.expectEqual(OpCode.push_zero, f.instructions.items[0].op);
}

test "Emitter pushInt one" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushInt(1);
    try std.testing.expectEqual(OpCode.push_one, f.instructions.items[0].op);
}

test "Emitter pushInt int8" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushInt(42);
    try std.testing.expectEqual(OpCode.push_int8, f.instructions.items[0].op);
}

test "Emitter pushInt int16" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushInt(5000);
    try std.testing.expectEqual(OpCode.push_int16, f.instructions.items[0].op);
}

test "Emitter pushInt int32" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushInt(1000000);
    try std.testing.expectEqual(OpCode.push_int32, f.instructions.items[0].op);
}

test "Emitter pushNumber float" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushNumber(3.14);
    try std.testing.expectEqual(OpCode.push_const, f.instructions.items[0].op);
}

test "Emitter pushString" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushString("hello");
    try std.testing.expectEqual(OpCode.push_string, f.instructions.items[0].op);
    try std.testing.expectEqual(@as(usize, 1), f.constants.count());
}

test "Emitter pushBoolean" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.pushBoolean(true);
    try std.testing.expectEqual(OpCode.push_true, f.instructions.items[0].op);
    _ = try e.pushBoolean(false);
    try std.testing.expectEqual(OpCode.push_false, f.instructions.items[1].op);
}

test "Emitter emitCall" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.emitCall(3);
    try std.testing.expectEqual(OpCode.call, f.instructions.items[0].op);
}

test "Emitter jump and patch" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    const jump_idx = try e.emitJump(.jump);
    _ = try e.emit(.nop);
    _ = try e.emit(.nop);
    try e.patchJump(jump_idx);

    const inst = f.instructions.items[jump_idx];
    try std.testing.expectEqual(@as(JumpOffset, 3), inst.asJumpOffset().?);
}

test "Emitter beginLoop and endLoop" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try e.beginLoop(null);
    _ = try e.emit(.nop);
    try e.endLoop();
}

test "Emitter emitBreak" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try e.beginLoop(null);
    try e.emitBreak();
    try std.testing.expectEqual(@as(usize, 1), e.loops.items[0].break_jumps.items.len);
}

test "Emitter emitContinue" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try e.beginLoop(null);
    try e.emitContinue();
    try std.testing.expectEqual(@as(usize, 1), e.loops.items[0].continue_jumps.items.len);
}

test "Emitter currentLoop" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try std.testing.expect(e.currentLoop() == null);
    try e.beginLoop(null);
    try std.testing.expect(e.currentLoop() != null);
}

test "Emitter pushTry and popTry" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    try e.pushTry();
    try std.testing.expectEqual(@as(usize, 1), e.tries.items.len);
    try e.popTry();
    try std.testing.expectEqual(@as(usize, 0), e.tries.items.len);
}

test "Emitter defineParameter" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.defineParameter("x");
    try std.testing.expectEqual(@as(u8, 1), f.arity);
}

test "Emitter defineLocal and findLocal" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.defineLocal("x", 0);
    try std.testing.expect(e.findLocal("x") != null);
    try std.testing.expect(e.findLocal("y") == null);
}

test "Emitter emitReturn" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    _ = try e.emitReturn();
    try std.testing.expectEqual(OpCode.return_, f.instructions.items[0].op);
}

test "Emitter setLine" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = Emitter.init(std.testing.allocator, &f);
    defer e.deinit();

    e.setLine(42);
    try std.testing.expectEqual(@as(u32, 42), e.last_line);
}

test "create helper" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var e = create(std.testing.allocator, &f);
    defer e.deinit();

    try std.testing.expectEqual(@as(usize, 0), f.instructionCount());
}
