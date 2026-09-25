const std = @import("std");
const value_mod = @import("../values/value.zig");
const bytecode = @import("../compiler/bytecode.zig");
const stack_mod = @import("stack.zig");
const frame_mod = @import("frame.zig");

pub const Value = value_mod.Value;
pub const Function = bytecode.Function;
pub const Stack = stack_mod.Stack;
pub const Frame = frame_mod.Frame;
pub const FrameStack = frame_mod.FrameStack;
pub const CallKind = frame_mod.CallKind;
pub const CallInfo = frame_mod.CallInfo;

pub const CallError = error{
    OutOfMemory,
    StackOverflow,
    StackUnderflow,
    NotCallable,
    NotConstructable,
    TooManyArguments,
    FrameStackOverflow,
    InvalidFunction,
    InvalidCallKind,
};

pub const MAX_CALL_ARGS: u16 = 65535;

pub const ArgumentInfo = struct {
    start: u32,
    count: u16,

    pub fn init(start: u32, count: u16) ArgumentInfo {
        return .{ .start = start, .count = count };
    }

    pub fn end(self: ArgumentInfo) u32 {
        return self.start + self.count;
    }
};

pub const CallFrameSetup = struct {
    function: *Function,
    this_value: Value,
    new_target: Value,
    kind: CallKind,
    arg_count: u16,
    return_address: u32,

    pub fn init(function: *Function) CallFrameSetup {
        return .{
            .function = function,
            .this_value = Value.UNDEFINED,
            .new_target = Value.UNDEFINED,
            .kind = .normal,
            .arg_count = 0,
            .return_address = 0,
        };
    }

    pub fn withThis(self: CallFrameSetup, this_value: Value) CallFrameSetup {
        var s = self;
        s.this_value = this_value;
        return s;
    }

    pub fn withNewTarget(self: CallFrameSetup, new_target: Value) CallFrameSetup {
        var s = self;
        s.new_target = new_target;
        return s;
    }

    pub fn withKind(self: CallFrameSetup, kind: CallKind) CallFrameSetup {
        var s = self;
        s.kind = kind;
        return s;
    }

    pub fn withArgCount(self: CallFrameSetup, count: u16) CallFrameSetup {
        var s = self;
        s.arg_count = count;
        return s;
    }

    pub fn withReturnAddress(self: CallFrameSetup, addr: u32) CallFrameSetup {
        var s = self;
        s.return_address = addr;
        return s;
    }
};

pub const CallResult = struct {
    frame_id: u32,
    stack_base: u32,
    local_base: u32,
    arguments_start: u32,
    arguments_count: u16,

    pub fn init(
        frame_id: u32,
        stack_base: u32,
        local_base: u32,
        args_start: u32,
        args_count: u16,
    ) CallResult {
        return .{
            .frame_id = frame_id,
            .stack_base = stack_base,
            .local_base = local_base,
            .arguments_start = args_start,
            .arguments_count = args_count,
        };
    }
};

pub const Caller = struct {
    stack: *Stack,
    frames: *FrameStack,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        stack: *Stack,
        frames: *FrameStack,
    ) Caller {
        return .{
            .allocator = allocator,
            .stack = stack,
            .frames = frames,
        };
    }

    pub fn setupCall(self: *Caller, setup: CallFrameSetup) CallError!CallResult {
        if (setup.arg_count > MAX_CALL_ARGS) {
            return CallError.TooManyArguments;
        }

        const arg_start: u32 = @intCast(self.stack.size() - setup.arg_count);

        const stack_base: u32 = @intCast(self.stack.size());

        const frame = Frame.init(setup.function, stack_base)
            .withThis(setup.this_value)
            .withNewTarget(setup.new_target)
            .withArguments(arg_start, setup.arg_count);

        var final_frame = frame;
        if (setup.kind == .constructor or setup.kind == .super_constructor) {
            final_frame = frame.asConstructor();
        }
        final_frame.saveReturn(setup.return_address);

        const frame_id = self.frames.push(final_frame) catch {
            return CallError.FrameStackOverflow;
        };

        const locals_needed = setup.function.localCount();
        var i: usize = 0;
        while (i < locals_needed) : (i += 1) {
            self.stack.push(Value.UNDEFINED) catch {
                _ = self.frames.pop();
                return CallError.StackOverflow;
            };
        }

        return CallResult.init(
            frame_id,
            stack_base,
            stack_base,
            arg_start,
            setup.arg_count,
        );
    }

    pub fn returnFromCall(self: *Caller) CallError!?Value {
        const popped = self.frames.pop() orelse return null;

        const new_top: u32 = popped.stack_base;
        const current_size: u32 = @intCast(self.stack.size());

        if (new_top < current_size) {
            const to_drop: usize = @intCast(current_size - new_top);
            self.stack.drop(to_drop) catch {};
        }

        return Value.UNDEFINED;
    }

    pub fn currentFrame(self: *Caller) ?*Frame {
        return self.frames.current();
    }

    pub fn frameDepth(self: Caller) usize {
        return self.frames.depth();
    }

    pub fn stackSize(self: Caller) usize {
        return self.stack.size();
    }

    pub fn currentThis(self: *Caller) Value {
        if (self.frames.current()) |frame| {
            return frame.this_value;
        }
        return Value.UNDEFINED;
    }

    pub fn callerFrame(self: *Caller) ?*Frame {
        return self.frames.caller();
    }

    pub fn unwindTo(self: *Caller, target_depth: usize) CallError!void {
        while (self.frames.depth() > target_depth) {
            _ = try self.returnFromCall();
        }
    }

    pub fn clear(self: *Caller) void {
        self.frames.clear();
        self.stack.clear();
    }
};

pub const ArgumentLayout = struct {
    this_slot: u32,
    function_slot: u32,
    first_arg: u32,
    arg_count: u16,

    pub fn init(this_slot: u32, function_slot: u32, first_arg: u32, arg_count: u16) ArgumentLayout {
        return .{
            .this_slot = this_slot,
            .function_slot = function_slot,
            .first_arg = first_arg,
            .arg_count = arg_count,
        };
    }

    pub fn lastArg(self: ArgumentLayout) u32 {
        if (self.arg_count == 0) return self.first_arg;
        return self.first_arg + self.arg_count - 1;
    }
};

pub fn isCallable(v: Value) bool {
    _ = v;
    return true;
}

pub fn isConstructor(v: Value) bool {
    _ = v;
    return true;
}

pub fn callKindFromOp(op: @import("../compiler/opcode.zig").OpCode) CallKind {
    return switch (op) {
        .call => .normal,
        .call_method => .method,
        .call_spread => .normal,
        .new_ => .constructor,
        .new_spread => .constructor,
        .super_call => .super_call,
        .super_construct => .super_constructor,
        else => .normal,
    };
}

pub fn argumentCountForOp(op: @import("../compiler/opcode.zig").OpCode) u8 {
    return switch (op) {
        .call, .call_method, .call_spread, .new_, .new_spread, .super_call, .super_construct => 1,
        else => 0,
    };
}

test "ArgumentInfo init" {
    const ai = ArgumentInfo.init(5, 3);
    try std.testing.expectEqual(@as(u32, 5), ai.start);
    try std.testing.expectEqual(@as(u16, 3), ai.count);
    try std.testing.expectEqual(@as(u32, 8), ai.end());
}

test "CallFrameSetup init" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const s = CallFrameSetup.init(&f);
    try std.testing.expectEqual(CallKind.normal, s.kind);
    try std.testing.expectEqual(@as(u16, 0), s.arg_count);
    try std.testing.expect(s.this_value.isUndefined());
}

test "CallFrameSetup withThis" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const s = CallFrameSetup.init(&f).withThis(Value.TRUE);
    try std.testing.expect(s.this_value.asBool().?);
}

test "CallFrameSetup withKind" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const s = CallFrameSetup.init(&f).withKind(.method);
    try std.testing.expectEqual(CallKind.method, s.kind);
}

test "CallFrameSetup withArgCount" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const s = CallFrameSetup.init(&f).withArgCount(3);
    try std.testing.expectEqual(@as(u16, 3), s.arg_count);
}

test "CallFrameSetup withReturnAddress" {
    var f = Function.init(std.testing.allocator, "foo");
    defer f.deinit();

    const s = CallFrameSetup.init(&f).withReturnAddress(42);
    try std.testing.expectEqual(@as(u32, 42), s.return_address);
}

test "Caller setupCall" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);

    const setup = CallFrameSetup.init(&f);
    const result = try caller.setupCall(setup);

    try std.testing.expectEqual(@as(u32, 0), result.frame_id);
    try std.testing.expectEqual(@as(usize, 1), frames.depth());
}

test "Caller setupCall with args" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    try stack.push(Value.fromNumber(1.0));
    try stack.push(Value.fromNumber(2.0));

    var caller = Caller.init(std.testing.allocator, &stack, &frames);

    const setup = CallFrameSetup.init(&f).withArgCount(2);
    const result = try caller.setupCall(setup);

    try std.testing.expectEqual(@as(u16, 2), result.arguments_count);
}

test "Caller returnFromCall" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);

    _ = try caller.setupCall(CallFrameSetup.init(&f));
    try std.testing.expectEqual(@as(usize, 1), frames.depth());

    _ = try caller.returnFromCall();
    try std.testing.expectEqual(@as(usize, 0), frames.depth());
}

test "Caller currentFrame" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);
    try std.testing.expect(caller.currentFrame() == null);

    _ = try caller.setupCall(CallFrameSetup.init(&f));
    try std.testing.expect(caller.currentFrame() != null);
}

test "Caller currentThis" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);
    _ = try caller.setupCall(CallFrameSetup.init(&f).withThis(Value.fromNumber(42.0)));

    try std.testing.expectEqual(@as(f64, 42.0), caller.currentThis().asNumber().?);
}

test "Caller callerFrame" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f1 = Function.init(std.testing.allocator, "outer");
    defer f1.deinit();
    var f2 = Function.init(std.testing.allocator, "inner");
    defer f2.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);
    _ = try caller.setupCall(CallFrameSetup.init(&f1));
    try std.testing.expect(caller.callerFrame() == null);
    _ = try caller.setupCall(CallFrameSetup.init(&f2));
    try std.testing.expect(caller.callerFrame() != null);
}

test "Caller unwindTo" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);
    _ = try caller.setupCall(CallFrameSetup.init(&f));
    _ = try caller.setupCall(CallFrameSetup.init(&f));
    _ = try caller.setupCall(CallFrameSetup.init(&f));

    try std.testing.expectEqual(@as(usize, 3), frames.depth());
    try caller.unwindTo(1);
    try std.testing.expectEqual(@as(usize, 1), frames.depth());
}

test "Caller clear" {
    var stack = try Stack.initCapacity(std.testing.allocator, 64);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var caller = Caller.init(std.testing.allocator, &stack, &frames);
    _ = try caller.setupCall(CallFrameSetup.init(&f));
    caller.clear();
    try std.testing.expectEqual(@as(usize, 0), frames.depth());
    try std.testing.expectEqual(@as(usize, 0), stack.size());
}

test "ArgumentLayout init" {
    const al = ArgumentLayout.init(0, 1, 2, 3);
    try std.testing.expectEqual(@as(u32, 0), al.this_slot);
    try std.testing.expectEqual(@as(u32, 1), al.function_slot);
    try std.testing.expectEqual(@as(u32, 2), al.first_arg);
    try std.testing.expectEqual(@as(u16, 3), al.arg_count);
}

test "ArgumentLayout lastArg" {
    const al = ArgumentLayout.init(0, 1, 2, 3);
    try std.testing.expectEqual(@as(u32, 4), al.lastArg());

    const empty = ArgumentLayout.init(0, 1, 2, 0);
    try std.testing.expectEqual(@as(u32, 2), empty.lastArg());
}

test "MAX_CALL_ARGS" {
    try std.testing.expectEqual(@as(u16, 65535), MAX_CALL_ARGS);
}

test "CallResult init" {
    const r = CallResult.init(0, 10, 10, 5, 3);
    try std.testing.expectEqual(@as(u32, 0), r.frame_id);
    try std.testing.expectEqual(@as(u32, 10), r.stack_base);
    try std.testing.expectEqual(@as(u16, 3), r.arguments_count);
}
