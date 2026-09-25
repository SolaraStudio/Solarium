const std = @import("std");
const value_mod = @import("../values/value.zig");
const string_mod = @import("../values/string.zig");
const coercion = @import("../values/coercion.zig");
const bytecode = @import("../compiler/bytecode.zig");
const opcode_mod = @import("../compiler/opcode.zig");
const stack_mod = @import("stack.zig");
const frame_mod = @import("frame.zig");
const call_mod = @import("call.zig");
const return_mod = @import("return.zig");
const exception_mod = @import("exception.zig");
const dispatch_mod = @import("dispatch.zig");

pub const Value = value_mod.Value;
pub const OpCode = opcode_mod.OpCode;
pub const Instruction = bytecode.Instruction;
pub const Function = bytecode.Function;
pub const Module = bytecode.Module;
pub const Constant = bytecode.Constant;
pub const ConstantIndex = bytecode.ConstantIndex;
pub const LocalIndex = bytecode.LocalIndex;
pub const UpvalueIndex = bytecode.UpvalueIndex;
pub const JumpOffset = bytecode.JumpOffset;

pub const Stack = stack_mod.Stack;
pub const Frame = frame_mod.Frame;
pub const FrameStack = frame_mod.FrameStack;
pub const Caller = call_mod.Caller;
pub const Returner = return_mod.Returner;
pub const ExceptionHandler = exception_mod.ExceptionHandler;
pub const HandlerStack = exception_mod.HandlerStack;

pub const VmError = error{
    OutOfMemory,
    StackOverflow,
    StackUnderflow,
    TypeError,
    ReferenceError,
    InternalError,
    UnsupportedOpcode,
    InvalidOperand,
    NotCallable,
    NoFrame,
    NoModule,
    UncaughtException,
};

pub const RunResult = union(enum) {
    completed: Value,
    yielded: Value,
    threw: Value,

    pub fn isCompleted(self: RunResult) bool {
        return std.meta.activeTag(self) == .completed;
    }

    pub fn isThrew(self: RunResult) bool {
        return std.meta.activeTag(self) == .threw;
    }
};

pub const Options = struct {
    max_frames: u32 = 1024,
    max_stack: usize = 4096,
    trace: bool = false,

    pub fn default() Options {
        return .{};
    }
};

pub const Vm = struct {
    allocator: std.mem.Allocator,
    stack: Stack,
    frames: FrameStack,
    handlers: HandlerStack,
    caller: Caller,
    returner: Returner,
    exceptions: ExceptionHandler,
    module: ?*Module,
    options: Options,
    steps: u64,

    pub fn init(allocator: std.mem.Allocator) !Vm {
        return try initWithOptions(allocator, Options.default());
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) !Vm {
        var stack = try Stack.initCapacity(allocator, options.max_stack);
        errdefer stack.deinit();

        var frames = FrameStack.initWithDepth(allocator, options.max_frames);
        errdefer frames.deinit();

        var handlers = HandlerStack.init(allocator);
        errdefer handlers.deinit();

        return .{
            .allocator = allocator,
            .stack = stack,
            .frames = frames,
            .handlers = handlers,
            .caller = undefined,
            .returner = undefined,
            .exceptions = undefined,
            .module = null,
            .options = options,
            .steps = 0,
        };
    }

    pub fn deinit(self: *Vm) void {
        self.stack.deinit();
        self.frames.deinit();
        self.handlers.deinit();
    }

    pub fn setup(self: *Vm) void {
        self.caller = Caller.init(self.allocator, &self.stack, &self.frames);
        self.returner = Returner.init(self.allocator, &self.stack, &self.frames);
        self.exceptions = ExceptionHandler.init(
            self.allocator,
            &self.handlers,
            &self.stack,
            &self.frames,
        );
    }

    pub fn loadModule(self: *Vm, module: *Module) void {
        self.module = module;
    }

    pub fn run(self: *Vm) VmError!RunResult {
        const module = self.module orelse return VmError.NoModule;
        const main_fn = module.mainFunction() orelse return VmError.NoFrame;

        self.setup();

        const setup_call = call_mod.CallFrameSetup.init(main_fn);
        _ = self.caller.setupCall(setup_call) catch return VmError.InternalError;

       return try self.executeLoop();
    }

    pub fn runFunction(self: *Vm, function: *Function) VmError!RunResult {
        self.setup();

        const setup_call = call_mod.CallFrameSetup.init(function);
        _ = self.caller.setupCall(setup_call) catch return VmError.InternalError;

        return try self.executeLoop();
   }

    fn executeLoop(self: *Vm) VmError!RunResult {
        while (self.frames.depth() > 0) {
            const frame = self.frames.current() orelse break;
            const inst_opt = frame.currentInstruction();

            if (inst_opt == null) {
                _ = try self.doReturnUndefined();
                continue;
            }

            const inst = inst_opt.?;

            if (self.options.trace) {
                std.debug.print("[ip={d}] {s}\n", .{ frame.ip, inst.op.toString() });
            }

            self.steps += 1;

            frame.advance();

            self.dispatchInstruction(inst) catch |err| switch (err) {
                error.UnsupportedOpcode => return VmError.UnsupportedOpcode,
                else => return err,
            };
        }

        var result_value = Value.UNDEFINED;
        if (self.stack.size() > 0) {
            result_value = self.stack.peek() catch Value.UNDEFINED;
        }

        return RunResult{ .completed = result_value };
    }

    fn dispatchInstruction(self: *Vm, inst: Instruction) VmError!void {
        switch (inst.op) {
            .nop => {},
            .pop => try self.doPop(),
            .dup => try self.doDup(),
            .dup2 => try self.doDup2(),
            .swap => try self.doSwap(),
            .rot3 => try self.doRot3(),

            .push_undefined => try self.stack.push(Value.UNDEFINED),
            .push_null => try self.stack.push(Value.NULL),
            .push_true => try self.stack.push(Value.TRUE),
            .push_false => try self.stack.push(Value.FALSE),
            .push_zero => try self.stack.push(Value.ZERO),
            .push_one => try self.stack.push(Value.fromNumber(1.0)),
            .push_int8 => try self.stack.push(Value.fromNumber(@floatFromInt(getInt8(inst)))),
            .push_int16 => try self.stack.push(Value.fromNumber(@floatFromInt(getInt16(inst)))),
            .push_int32 => try self.stack.push(Value.fromNumber(@floatFromInt(getInt32(inst)))),
            .push_const => try self.doPushConst(getConst(inst)),
            .push_string => try self.doPushConst(getConst(inst)),
            .push_bigint => try self.doPushConst(getConst(inst)),

            .load_local => try self.doLoadLocal(getLocal(inst)),
            .store_local => try self.doStoreLocal(getLocal(inst)),
            .load_global => try self.doLoadGlobal(getConst(inst)),
            .store_global => try self.doStoreGlobal(getConst(inst)),
            .load_upvalue => try self.doLoadUpvalue(getUpvalue(inst)),
            .store_upvalue => try self.doStoreUpvalue(getUpvalue(inst)),
            .load_this => try self.doLoadThis(),

            .add => try self.doAdd(),
            .sub => try self.doSub(),
            .mul => try self.doMul(),
            .div => try self.doDiv(),
            .mod => try self.doMod(),
            .exp => try self.doExp(),
            .neg => try self.doNeg(),
            .pos => {},
            .inc => try self.doInc(),
            .dec => try self.doDec(),

            .eq => try self.doEq(),
            .neq => try self.doNeq(),
            .strict_eq => try self.doStrictEq(),
            .strict_neq => try self.doStrictNeq(),
            .lt => try self.doLt(),
            .gt => try self.doGt(),
            .lte => try self.doLte(),
            .gte => try self.doGte(),

            .not => try self.doNot(),
            .typeof_ => try self.doTypeof(),
            .void_ => try self.doVoid(),

            .jump => try self.doJump(getJump(inst)),
            .jump_if_true => try self.doJumpIfTrue(getJump(inst)),
            .jump_if_false => try self.doJumpIfFalse(getJump(inst)),
            .jump_if_null => try self.doJumpIfNull(getJump(inst)),
            .jump_if_not_null => try self.doJumpIfNotNull(getJump(inst)),
            .jump_if_undefined => try self.doJumpIfUndefined(getJump(inst)),
            .jump_if_not_undefined => try self.doJumpIfNotUndefined(getJump(inst)),

            .return_ => try self.doReturn(),
            .return_undefined => try self.doReturnUndefined(),
            .halt => {
                self.frames.clear();
            },

            .debugger, .trace, .breakpoint => {},

            else => return VmError.UnsupportedOpcode,
        }
    }

    pub fn doPop(self: *Vm) VmError!void {
        _ = self.stack.pop() catch return VmError.StackUnderflow;
    }

    pub fn doDup(self: *Vm) VmError!void {
        self.stack.dup() catch return VmError.StackUnderflow;
    }

    pub fn doDup2(self: *Vm) VmError!void {
        self.stack.dup2() catch return VmError.StackUnderflow;
    }

    pub fn doSwap(self: *Vm) VmError!void {
        self.stack.swap() catch return VmError.StackUnderflow;
    }

    pub fn doRot3(self: *Vm) VmError!void {
        self.stack.rot3() catch return VmError.StackUnderflow;
    }

    pub fn doPushConst(self: *Vm, idx: ConstantIndex) VmError!void {
        const module = self.module orelse return VmError.NoModule;
        const frame = self.frames.current() orelse return VmError.NoFrame;

        const c = frame.function.constants.get(idx) orelse return VmError.InvalidOperand;

        const v: Value = switch (c) {
            .undefined_ => Value.UNDEFINED,
            .null_ => Value.NULL,
            .boolean => |b| Value.fromBool(b),
            .integer => |i| Value.fromNumber(@floatFromInt(i)),
            .float => |f| Value.fromNumber(f),
            .string => |s| blk: {
                const str = self.allocator.create(string_mod.String) catch return VmError.OutOfMemory;
                str.* = string_mod.String.init(s);
                break :blk string_mod.toValue(str);
            },
            .bigint => |s| blk: {
                _ = s;
                break :blk Value.UNDEFINED;
            },
            .symbol => Value.UNDEFINED,
            .regex => Value.UNDEFINED,
        };
        _ = module;
        try self.stack.push(v);
    }

    pub fn doLoadLocal(self: *Vm, idx: LocalIndex) VmError!void {
        const frame = self.frames.current() orelse return VmError.NoFrame;
        const abs_index = frame.localIndex(idx);
        const v = self.stack.get(abs_index) catch return VmError.StackUnderflow;
        try self.stack.push(v);
    }

    pub fn doStoreLocal(self: *Vm, idx: LocalIndex) VmError!void {
        const frame = self.frames.current() orelse return VmError.NoFrame;
        const abs_index = frame.localIndex(idx);
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(v);
        self.stack.set(abs_index, v) catch return VmError.StackUnderflow;
    }

    pub fn doLoadGlobal(self: *Vm, idx: ConstantIndex) VmError!void {
        _ = idx;
        try self.stack.push(Value.UNDEFINED);
    }

    pub fn doStoreGlobal(self: *Vm, idx: ConstantIndex) VmError!void {
        _ = idx;
        _ = self.stack.pop() catch return VmError.StackUnderflow;
    }

    pub fn doLoadUpvalue(self: *Vm, idx: UpvalueIndex) VmError!void {
        _ = idx;
        try self.stack.push(Value.UNDEFINED);
    }

    pub fn doStoreUpvalue(self: *Vm, idx: UpvalueIndex) VmError!void {
        _ = idx;
        _ = self.stack.pop() catch return VmError.StackUnderflow;
    }

    pub fn doLoadThis(self: *Vm) VmError!void {
        const frame = self.frames.current() orelse return VmError.NoFrame;
        try self.stack.push(frame.this_value);
    }

    fn popTwo(self: *Vm) VmError!struct { Value, Value } {
        const b = self.stack.pop() catch return VmError.StackUnderflow;
        const a = self.stack.pop() catch return VmError.StackUnderflow;
        return .{ a, b };
    }

    pub fn doAdd(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticAdd(pair[0], pair[1]));
    }

    pub fn doSub(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticSub(pair[0], pair[1]));
    }

    pub fn doMul(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticMul(pair[0], pair[1]));
    }

    pub fn doDiv(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticDiv(pair[0], pair[1]));
    }

    pub fn doMod(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticMod(pair[0], pair[1]));
    }

    pub fn doExp(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.arithmeticExp(pair[0], pair[1]));
    }

    pub fn doNeg(self: *Vm) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(Value.fromNumber(-dispatch_mod.toNumber(v)));
    }

    pub fn doInc(self: *Vm) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(Value.fromNumber(dispatch_mod.toNumber(v) + 1.0));
    }

    pub fn doDec(self: *Vm) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(Value.fromNumber(dispatch_mod.toNumber(v) - 1.0));
    }

    pub fn doEq(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.looseEq(pair[0], pair[1]));
    }

    pub fn doNeq(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.looseNeq(pair[0], pair[1]));
    }

    pub fn doStrictEq(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.strictEq(pair[0], pair[1]));
    }

    pub fn doStrictNeq(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.strictNeq(pair[0], pair[1]));
    }

    pub fn doLt(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.compareLt(pair[0], pair[1]));
    }

    pub fn doGt(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.compareGt(pair[0], pair[1]));
    }

    pub fn doLte(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.compareLte(pair[0], pair[1]));
    }

    pub fn doGte(self: *Vm) VmError!void {
        const pair = try self.popTwo();
        try self.stack.push(dispatch_mod.compareGte(pair[0], pair[1]));
    }

    pub fn doNot(self: *Vm) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(dispatch_mod.logicalNot(v));
    }

    pub fn doTypeof(self: *Vm) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        const name = dispatch_mod.typeOf(v);
        const s = self.allocator.create(string_mod.String) catch return VmError.OutOfMemory;
        s.* = string_mod.String.init(name);
        try self.stack.push(string_mod.toValue(s));
    }

    pub fn doVoid(self: *Vm) VmError!void {
        _ = self.stack.pop() catch return VmError.StackUnderflow;
        try self.stack.push(Value.UNDEFINED);
    }

    pub fn doJump(self: *Vm, offset: JumpOffset) VmError!void {
        const frame = self.frames.current() orelse return VmError.NoFrame;
        const current: i64 = @intCast(frame.ip);
        const target = current + offset;
        if (target < 0) return VmError.InvalidOperand;
        frame.setIp(@intCast(target));
    }

    pub fn doJumpIfTrue(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (dispatch_mod.isTruthy(v)) {
            try self.doJump(offset);
        }
    }

    pub fn doJumpIfFalse(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (dispatch_mod.isFalsy(v)) {
            try self.doJump(offset);
        }
    }

    pub fn doJumpIfNull(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (v.isNull()) {
            try self.doJump(offset);
        }
    }

    pub fn doJumpIfNotNull(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (!v.isNull()) {
            try self.doJump(offset);
        }
    }

    pub fn doJumpIfUndefined(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (v.isUndefined()) {
            try self.doJump(offset);
        }
    }

    pub fn doJumpIfNotUndefined(self: *Vm, offset: JumpOffset) VmError!void {
        const v = self.stack.pop() catch return VmError.StackUnderflow;
        if (!v.isUndefined()) {
            try self.doJump(offset);
        }
    }

    pub fn doReturn(self: *Vm) VmError!void {
        const v = self.stack.pop() catch Value.UNDEFINED;
        _ = self.returner.returnValue(v) catch return VmError.InternalError;
        try self.stack.push(v);
    }

    pub fn doReturnUndefined(self: *Vm) VmError!void {
        _ = self.returner.returnValue(Value.UNDEFINED) catch return VmError.InternalError;
    }

    pub fn doThrow(self: *Vm) VmError!void {
        const v = self.stack.pop() catch Value.UNDEFINED;
        const r = self.exceptions.throw(v) catch return VmError.InternalError;
        if (r.isUncaught()) {
            return VmError.UncaughtException;
        }
    }

    pub fn stepsExecuted(self: Vm) u64 {
        return self.steps;
    }

    pub fn resetSteps(self: *Vm) void {
        self.steps = 0;
    }

    pub fn stackSize(self: Vm) usize {
        return self.stack.size();
    }

    pub fn frameDepth(self: Vm) usize {
        return self.frames.depth();
    }
};

fn getInt8(inst: Instruction) i8 {
    return switch (inst.operand) {
        .int8 => |v| v,
        else => 0,
    };
}

fn getInt16(inst: Instruction) i16 {
    return switch (inst.operand) {
        .int16 => |v| v,
        else => 0,
    };
}

fn getInt32(inst: Instruction) i32 {
    return switch (inst.operand) {
        .int32 => |v| v,
        else => 0,
    };
}

fn getConst(inst: Instruction) ConstantIndex {
    return switch (inst.operand) {
        .constant => |c| c,
        else => 0,
    };
}

fn getLocal(inst: Instruction) LocalIndex {
    return switch (inst.operand) {
        .local => |l| l,
        else => 0,
    };
}

fn getUpvalue(inst: Instruction) UpvalueIndex {
    return switch (inst.operand) {
        .upvalue => |u| u,
        else => 0,
    };
}

fn getJump(inst: Instruction) JumpOffset {
    return switch (inst.operand) {
        .jump => |j| j,
        else => 0,
    };
}

pub fn create(allocator: std.mem.Allocator) !*Vm {
    const vm = try allocator.create(Vm);
    vm.* = try Vm.init(allocator);
    return vm;
}

pub fn destroy(vm: *Vm) void {
    const allocator = vm.allocator;
    vm.deinit();
    allocator.destroy(vm);
}

pub fn createWithOptions(allocator: std.mem.Allocator, options: Options) !*Vm {
    const vm = try allocator.create(Vm);
    vm.* = try Vm.initWithOptions(allocator, options);
    return vm;
}

test "Vm init" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(@as(usize, 0), vm.frameDepth());
    try std.testing.expectEqual(@as(usize, 0), vm.stackSize());
}

test "Vm initWithOptions" {
    var vm = try Vm.initWithOptions(std.testing.allocator, .{
        .max_frames = 32,
        .max_stack = 256,
    });
    defer vm.deinit();
    try std.testing.expectEqual(@as(usize, 256), vm.stack.capacity());
}

test "Vm doPop" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.TRUE);
    try vm.doPop();
    try std.testing.expectEqual(@as(usize, 0), vm.stackSize());
}

test "Vm doPop empty" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(VmError.StackUnderflow, vm.doPop());
}

test "Vm doDup" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(42.0));
    try vm.doDup();
    try std.testing.expectEqual(@as(usize, 2), vm.stackSize());
}

test "Vm doAdd" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(1.0));
    try vm.stack.push(Value.fromNumber(2.0));
    try vm.doAdd();

    const r = try vm.stack.peek();
    try std.testing.expectEqual(@as(f64, 3.0), r.asNumber().?);
}

test "Vm doSub" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(10.0));
    try vm.stack.push(Value.fromNumber(3.0));
    try vm.doSub();

    const r = try vm.stack.peek();
    try std.testing.expectEqual(@as(f64, 7.0), r.asNumber().?);
}

test "Vm doMul" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(3.0));
    try vm.stack.push(Value.fromNumber(4.0));
    try vm.doMul();

    const r = try vm.stack.peek();
    try std.testing.expectEqual(@as(f64, 12.0), r.asNumber().?);
}

test "Vm doDiv" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(10.0));
    try vm.stack.push(Value.fromNumber(2.0));
    try vm.doDiv();

    const r = try vm.stack.peek();
    try std.testing.expectEqual(@as(f64, 5.0), r.asNumber().?);
}

test "Vm doNeg" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(5.0));
    try vm.doNeg();

    const r = try vm.stack.peek();
    try std.testing.expectEqual(@as(f64, -5.0), r.asNumber().?);
}

test "Vm doStrictEq" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.TRUE);
    try vm.stack.push(Value.TRUE);
    try vm.doStrictEq();

    const r = try vm.stack.peek();
    try std.testing.expect(r.asBool().?);
}

test "Vm doLt" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(1.0));
    try vm.stack.push(Value.fromNumber(2.0));
    try vm.doLt();

    const r = try vm.stack.peek();
    try std.testing.expect(r.asBool().?);
}

test "Vm doNot" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.FALSE);
    try vm.doNot();

    const r = try vm.stack.peek();
    try std.testing.expect(r.asBool().?);
}

test "Vm doVoid" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try vm.stack.push(Value.fromNumber(42.0));
    try vm.doVoid();

    const r = try vm.stack.peek();
    try std.testing.expect(r.isUndefined());
}

test "Vm run 1+2" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.add));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expect(result.isCompleted());
    try std.testing.expectEqual(@as(f64, 2.0), result.completed.asNumber().?);
}

test "Vm run 10 - 3" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    const idx10 = try main_fn.constants.addInteger(10);
    const idx3 = try main_fn.constants.addInteger(3);
    _ = try main_fn.addInstruction(Instruction.withConstant(.push_const, idx10));
    _ = try main_fn.addInstruction(Instruction.withConstant(.push_const, idx3));
    _ = try main_fn.addInstruction(Instruction.init(.sub));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expectEqual(@as(f64, 7.0), result.completed.asNumber().?);
}

test "Vm run strict equals" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_true));
    _ = try main_fn.addInstruction(Instruction.init(.push_true));
    _ = try main_fn.addInstruction(Instruction.init(.strict_eq));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expect(result.completed.asBool().?);
}

test "Vm run conditional jump" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_true));
    const jump_idx = try main_fn.addInstruction(Instruction.withJump(.jump_if_false, 0));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    const else_target = main_fn.currentOffset();
    _ = try main_fn.addInstruction(Instruction.init(.push_zero));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    try main_fn.patchJump(jump_idx, else_target);

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expectEqual(@as(f64, 1.0), result.completed.asNumber().?);
}

test "Vm run conditional jump taken" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_false));
    const jump_idx = try main_fn.addInstruction(Instruction.withJump(.jump_if_false, 0));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    const else_target = main_fn.currentOffset();
    _ = try main_fn.addInstruction(Instruction.init(.push_zero));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    try main_fn.patchJump(jump_idx, else_target);

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expectEqual(@as(f64, 0.0), result.completed.asNumber().?);
}

test "Vm run function via runFunction" {
    const main_fn = try bytecode.createFunction(std.testing.allocator, "test");
    defer {
        main_fn.deinit();
        std.testing.allocator.destroy(main_fn);
    }

    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.add));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    const result = try vm.runFunction(main_fn);
    try std.testing.expectEqual(@as(f64, 2.0), result.completed.asNumber().?);
}

test "Vm run no module" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectError(VmError.NoModule, vm.run());
}

test "Vm stepsExecuted" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    try std.testing.expectEqual(@as(u64, 0), vm.stepsExecuted());
}

test "Vm resetSteps" {
    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();

    vm.steps = 42;
    vm.resetSteps();
    try std.testing.expectEqual(@as(u64, 0), vm.stepsExecuted());
}

test "Vm run multiple arithmetic" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.add));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.add));
    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.add));
    _ = try main_fn.addInstruction(Instruction.init(.return_));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expectEqual(@as(f64, 4.0), result.completed.asNumber().?);
}

test "Vm run return_undefined" {
    var module = bytecode.Module.init(std.testing.allocator);
    defer module.deinit();

    const main_fn = try bytecode.createFunction(std.testing.allocator, "main");
    _ = try module.addFunction(main_fn);

    _ = try main_fn.addInstruction(Instruction.init(.push_one));
    _ = try main_fn.addInstruction(Instruction.init(.return_undefined));

    var vm = try Vm.init(std.testing.allocator);
    defer vm.deinit();
    vm.loadModule(&module);

    const result = try vm.run();
    try std.testing.expect(result.isCompleted());
}

test "create helper" {
    const vm = try create(std.testing.allocator);
    defer destroy(vm);
    try std.testing.expectEqual(@as(usize, 0), vm.frameDepth());
}

test "createWithOptions helper" {
    const vm = try createWithOptions(std.testing.allocator, .{
        .max_frames = 64,
        .max_stack = 128,
    });
    defer destroy(vm);
    try std.testing.expectEqual(@as(usize, 128), vm.stack.capacity());
}

test "RunResult isCompleted" {
    const r = RunResult{ .completed = Value.TRUE };
    try std.testing.expect(r.isCompleted());
    try std.testing.expect(!r.isThrew());
}

test "RunResult isThrew" {
    const r = RunResult{ .threw = Value.TRUE };
    try std.testing.expect(r.isThrew());
    try std.testing.expect(!r.isCompleted());
}
