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

pub const ReturnError = error{
    OutOfMemory,
    StackOverflow,
    StackUnderflow,
    NoFrameToReturnFrom,
    InvalidReturnState,
};

pub const ReturnKind = enum(u8) {
    normal,
    undefined_,
    constructor,
    generator,
    async_,
    tail_call,

    pub fn toString(self: ReturnKind) []const u8 {
        return @tagName(self);
    }

    pub fn isConstructor(self: ReturnKind) bool {
        return self == .constructor;
    }

    pub fn isAsync(self: ReturnKind) bool {
        return self == .async_;
    }

    pub fn hasValue(self: ReturnKind) bool {
        return self != .undefined_;
    }
};

pub const ReturnInfo = struct {
    kind: ReturnKind,
    value: Value,
    return_address: u32,
    had_explicit_value: bool,

    pub fn init(kind: ReturnKind, value: Value) ReturnInfo {
        return .{
            .kind = kind,
            .value = value,
            .return_address = 0,
            .had_explicit_value = kind.hasValue(),
        };
    }

    pub fn undefinedReturn() ReturnInfo {
        return .{
            .kind = .undefined_,
            .value = Value.UNDEFINED,
            .return_address = 0,
            .had_explicit_value = false,
        };
    }

    pub fn withReturnAddress(self: ReturnInfo, addr: u32) ReturnInfo {
        var r = self;
        r.return_address = addr;
        return r;
    }
};

pub const ReturnResult = struct {
    caller_frame: ?*Frame,
    return_value: Value,
    return_address: u32,
    kind: ReturnKind,
    unwound_frames: usize,

    pub fn init(
        caller: ?*Frame,
        value: Value,
        address: u32,
        kind: ReturnKind,
    ) ReturnResult {
        return .{
            .caller_frame = caller,
            .return_value = value,
            .return_address = address,
            .kind = kind,
            .unwound_frames = 1,
        };
    }

    pub fn hasCaller(self: ReturnResult) bool {
        return self.caller_frame != null;
    }

    pub fn isTopLevel(self: ReturnResult) bool {
        return self.caller_frame == null;
    }
};

pub const Returner = struct {
    stack: *Stack,
    frames: *FrameStack,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        stack: *Stack,
        frames: *FrameStack,
    ) Returner {
        return .{
            .allocator = allocator,
            .stack = stack,
            .frames = frames,
        };
    }

    pub fn returnValue(self: *Returner, value: Value) ReturnError!ReturnResult {
        const current = self.frames.currentConst() orelse {
            return ReturnError.NoFrameToReturnFrom;
        };

        const return_address = current.return_address;
        const is_constructor = current.is_constructor;
        const stack_base = current.stack_base;
        const saved_frame_id = current.saved_frame_id;
        _ = saved_frame_id;

        const current_size: u32 = @intCast(self.stack.size());

        while (self.stack.size() > stack_base) {
            _ = self.stack.pop() catch break;
        }

        _ = self.frames.pop();

        const final_value = if (is_constructor) current.this_value else value;
        const kind: ReturnKind = if (is_constructor) .constructor else .normal;

        const caller = self.frames.current();
        if (caller) |c| {
            if (return_address > 0) {
                c.setIp(return_address);
            }
        }

        _ = current_size;

        return ReturnResult.init(caller, final_value, return_address, kind);
    }

    pub fn returnUndefined(self: *Returner) ReturnError!ReturnResult {
        return try self.returnValue(Value.UNDEFINED);
    }

    pub fn returnFromTop(self: *Returner) ReturnError!?Value {
        const current = self.frames.currentConst() orelse return null;

        const stack_base = current.stack_base;
        const return_address = current.return_address;
        const is_constructor = current.is_constructor;

        var return_value = Value.UNDEFINED;
        if (self.stack.size() > stack_base) {
            return_value = self.stack.pop() catch Value.UNDEFINED;
        }

        while (self.stack.size() > stack_base) {
            _ = self.stack.pop() catch break;
        }

        _ = self.frames.pop();

        const final_value = if (is_constructor) current.this_value else return_value;

        if (self.frames.current()) |caller| {
            if (return_address > 0) {
                caller.setIp(return_address);
            }
        }

        return final_value;
    }

    pub fn pushReturnValue(self: *Returner, result: ReturnResult) ReturnError!void {
        if (result.hasCaller()) {
            try self.stack.push(result.return_value);
        }
    }

    pub fn unwindAll(self: *Returner) void {
        self.frames.clear();
        self.stack.clear();
    }

    pub fn frameDepth(self: Returner) usize {
        return self.frames.depth();
    }

    pub fn stackSize(self: Returner) usize {
        return self.stack.size();
    }
};

pub const ReturnCheck = struct {
    can_return: bool,
    in_function: bool,
    in_async: bool,
    in_generator: bool,

    pub fn init() ReturnCheck {
        return .{
            .can_return = true,
            .in_function = false,
            .in_async = false,
            .in_generator = false,
        };
    }

    pub fn allowReturn(self: ReturnCheck, allow: bool) ReturnCheck {
        var c = self;
        c.can_return = allow;
        return c;
    }

    pub fn inFunctionContext(self: ReturnCheck) ReturnCheck {
        var c = self;
        c.in_function = true;
        return c;
    }

    pub fn inAsyncContext(self: ReturnCheck) ReturnCheck {
        var c = self;
        c.in_async = true;
        c.in_function = true;
        return c;
    }

    pub fn inGeneratorContext(self: ReturnCheck) ReturnCheck {
        var c = self;
        c.in_generator = true;
        c.in_function = true;
        return c;
    }
};

pub fn validateReturn(check: ReturnCheck) bool {
    if (!check.can_return) return false;
    return check.in_function;
}

pub fn returnKindForFunction(kind: bytecode.FunctionKind) ReturnKind {
    return switch (kind) {
        .generator => .generator,
        .async => .async_,
        .async_generator => .async_,
        .constructor => .constructor,
        else => .normal,
    };
}

pub fn isImplicitReturn(op: @import("../compiler/opcode.zig").OpCode) bool {
    return switch (op) {
        .return_undefined => true,
        .return_ => false,
        else => false,
    };
}

pub fn popsValue(op: @import("../compiler/opcode.zig").OpCode) bool {
    return switch (op) {
        .return_ => true,
        .return_undefined => false,
        else => false,
    };
}

pub fn isTerminating(op: @import("../compiler/opcode.zig").OpCode) bool {
    return switch (op) {
        .return_,
        .return_undefined,
        .throw_,
        .rethrow,
        .halt,
        => true,
        else => false,
    };
}

test "ReturnKind toString" {
    try std.testing.expectEqualStrings("normal", ReturnKind.normal.toString());
    try std.testing.expectEqualStrings("constructor", ReturnKind.constructor.toString());
    try std.testing.expectEqualStrings("undefined_", ReturnKind.undefined_.toString());
}

test "ReturnKind isConstructor" {
    try std.testing.expect(ReturnKind.constructor.isConstructor());
    try std.testing.expect(!ReturnKind.normal.isConstructor());
}

test "ReturnKind isAsync" {
    try std.testing.expect(ReturnKind.async_.isAsync());
    try std.testing.expect(!ReturnKind.normal.isAsync());
}

test "ReturnKind hasValue" {
    try std.testing.expect(ReturnKind.normal.hasValue());
    try std.testing.expect(!ReturnKind.undefined_.hasValue());
}

test "ReturnInfo init" {
    const r = ReturnInfo.init(.normal, Value.fromNumber(42.0));
    try std.testing.expectEqual(ReturnKind.normal, r.kind);
    try std.testing.expectEqual(@as(f64, 42.0), r.value.asNumber().?);
    try std.testing.expect(r.had_explicit_value);
}

test "ReturnInfo undefinedReturn" {
    const r = ReturnInfo.undefinedReturn();
    try std.testing.expectEqual(ReturnKind.undefined_, r.kind);
    try std.testing.expect(!r.had_explicit_value);
}

test "ReturnInfo withReturnAddress" {
    const r = ReturnInfo.init(.normal, Value.TRUE).withReturnAddress(42);
    try std.testing.expectEqual(@as(u32, 42), r.return_address);
}

test "ReturnResult init" {
    const r = ReturnResult.init(null, Value.UNDEFINED, 0, .normal);
    try std.testing.expectEqual(@as(usize, 1), r.unwound_frames);
}

test "ReturnResult hasCaller" {
    const r = ReturnResult.init(null, Value.UNDEFINED, 0, .normal);
    try std.testing.expect(!r.hasCaller());
    try std.testing.expect(r.isTopLevel());
}

test "Returner init" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    const r = Returner.init(std.testing.allocator, &stack, &frames);
    try std.testing.expectEqual(@as(usize, 0), r.frameDepth());
    try std.testing.expectEqual(@as(usize, 0), r.stackSize());
}

test "Returner returnValue no frame" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    try std.testing.expectError(ReturnError.NoFrameToReturnFrom, r.returnValue(Value.TRUE));
}

test "Returner returnValue one frame" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0);
    _ = try frames.push(frame);

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    const result = try r.returnValue(Value.fromNumber(42.0));

    try std.testing.expect(result.isTopLevel());
    try std.testing.expectEqual(@as(usize, 0), frames.depth());
}

test "Returner returnUndefined" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try frames.push(Frame.init(&f, 0));

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    const result = try r.returnUndefined();
    try std.testing.expectEqual(ReturnKind.normal, result.kind);
}

test "Returner clears stack to frame base" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    try stack.push(Value.fromNumber(1.0));
    try stack.push(Value.fromNumber(2.0));
    const base: u32 = @intCast(stack.size());
    try stack.push(Value.fromNumber(99.0));

    _ = try frames.push(Frame.init(&f, base));

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    _ = try r.returnValue(Value.UNDEFINED);

    try std.testing.expectEqual(@as(usize, 2), stack.size());
}

test "Returner constructor returns this" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "Ctor");
    defer f.deinit();

    const frame = Frame.init(&f, 0)
        .withThis(Value.fromNumber(42.0))
        .asConstructor();
    _ = try frames.push(frame);

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    const result = try r.returnValue(Value.UNDEFINED);

    try std.testing.expectEqual(ReturnKind.constructor, result.kind);
    try std.testing.expectEqual(@as(f64, 42.0), result.return_value.asNumber().?);
}

test "Returner returnFromTop" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try frames.push(Frame.init(&f, 0));
    try stack.push(Value.fromNumber(99.0));

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    const v = try r.returnFromTop();

    try std.testing.expect(v != null);
    try std.testing.expectEqual(@as(f64, 99.0), v.?.asNumber().?);
    try std.testing.expectEqual(@as(usize, 0), frames.depth());
}

test "Returner returnFromTop no frame" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    const v = try r.returnFromTop();
    try std.testing.expect(v == null);
}

test "Returner unwindAll" {
    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try frames.push(Frame.init(&f, 0));
    _ = try frames.push(Frame.init(&f, 0));
    try stack.push(Value.TRUE);

    var r = Returner.init(std.testing.allocator, &stack, &frames);
    r.unwindAll();

    try std.testing.expectEqual(@as(usize, 0), frames.depth());
    try std.testing.expectEqual(@as(usize, 0), stack.size());
}

test "ReturnCheck init" {
    const c = ReturnCheck.init();
    try std.testing.expect(c.can_return);
    try std.testing.expect(!c.in_function);
}

test "ReturnCheck inFunctionContext" {
    const c = ReturnCheck.init().inFunctionContext();
    try std.testing.expect(c.in_function);
}

test "ReturnCheck inAsyncContext" {
    const c = ReturnCheck.init().inAsyncContext();
    try std.testing.expect(c.in_async);
    try std.testing.expect(c.in_function);
}

test "ReturnCheck inGeneratorContext" {
    const c = ReturnCheck.init().inGeneratorContext();
    try std.testing.expect(c.in_generator);
    try std.testing.expect(c.in_function);
}

test "ReturnCheck allowReturn false" {
    const c = ReturnCheck.init().allowReturn(false).inFunctionContext();
    try std.testing.expect(!c.can_return);
    try std.testing.expect(!validateReturn(c));
}

test "validateReturn inside function" {
    const c = ReturnCheck.init().inFunctionContext();
    try std.testing.expect(validateReturn(c));
}

test "validateReturn top level" {
    const c = ReturnCheck.init();
    try std.testing.expect(!validateReturn(c));
}

test "returnKindForFunction normal" {
    try std.testing.expectEqual(ReturnKind.normal, returnKindForFunction(.normal));
}

test "returnKindForFunction generator" {
    try std.testing.expectEqual(ReturnKind.generator, returnKindForFunction(.generator));
}

test "returnKindForFunction async" {
    try std.testing.expectEqual(ReturnKind.async_, returnKindForFunction(.async));
}

test "returnKindForFunction constructor" {
    try std.testing.expectEqual(ReturnKind.constructor, returnKindForFunction(.constructor));
}

test "isImplicitReturn" {
    try std.testing.expect(isImplicitReturn(.return_undefined));
    try std.testing.expect(!isImplicitReturn(.return_));
}

test "popsValue" {
    try std.testing.expect(popsValue(.return_));
    try std.testing.expect(!popsValue(.return_undefined));
}

test "isTerminating" {
    try std.testing.expect(isTerminating(.return_));
    try std.testing.expect(isTerminating(.return_undefined));
    try std.testing.expect(isTerminating(.throw_));
    try std.testing.expect(isTerminating(.halt));
    try std.testing.expect(!isTerminating(.add));
}
