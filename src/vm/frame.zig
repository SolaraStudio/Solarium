const std = @import("std");
const value_mod = @import("../values/value.zig");
const bytecode = @import("../compiler/bytecode.zig");
const stack_mod = @import("stack.zig");

pub const Value = value_mod.Value;
pub const Function = bytecode.Function;
pub const Stack = stack_mod.Stack;

pub const FrameError = error{
    OutOfMemory,
    InvalidFrame,
    NoFramesAvailable,
    InvalidReturnAddress,
    InvalidStackBase,
};

pub const FrameId = u32;
pub const NO_FRAME: FrameId = 0xFFFFFFFF;

pub const Frame = struct {
    function: *Function,
    ip: u32,
    stack_base: u32,
    local_base: u32,
    saved_frame_id: FrameId,
    return_address: u32,
    this_value: Value,
    new_target: Value,
    is_constructor: bool,
    strict: bool,
    arguments_start: u32,
    arguments_count: u16,

    pub fn init(function: *Function, stack_base: u32) Frame {
        return .{
            .function = function,
            .ip = 0,
            .stack_base = stack_base,
            .local_base = stack_base,
            .saved_frame_id = NO_FRAME,
            .return_address = 0,
            .this_value = Value.UNDEFINED,
            .new_target = Value.UNDEFINED,
            .is_constructor = false,
            .strict = function.strict,
            .arguments_start = 0,
            .arguments_count = 0,
        };
    }

    pub fn withThis(self: Frame, this_value: Value) Frame {
        var f = self;
        f.this_value = this_value;
        return f;
    }

    pub fn withNewTarget(self: Frame, new_target: Value) Frame {
        var f = self;
        f.new_target = new_target;
        return f;
    }

    pub fn asConstructor(self: Frame) Frame {
        var f = self;
        f.is_constructor = true;
        return f;
    }

    pub fn withArguments(self: Frame, start: u32, count: u16) Frame {
        var f = self;
        f.arguments_start = start;
        f.arguments_count = count;
        return f;
    }

    pub fn currentInstruction(self: Frame) ?bytecode.Instruction {
        if (self.ip >= self.function.instructions.items.len) return null;
        return self.function.instructions.items[self.ip];
    }

    pub fn instructionAt(self: Frame, offset: u32) ?bytecode.Instruction {
        if (offset >= self.function.instructions.items.len) return null;
        return self.function.instructions.items[offset];
    }

    pub fn advance(self: *Frame) void {
        self.ip += 1;
    }

    pub fn jump(self: *Frame, target: u32) void {
        self.ip = target;
    }

    pub fn jumpRelative(self: *Frame, offset: i32) void {
        const next: i64 = @as(i64, @intCast(self.ip)) + offset;
        if (next < 0) {
            self.ip = 0;
            return;
        }
        self.ip = @intCast(next);
    }

    pub fn atEnd(self: Frame) bool {
        return self.ip >= self.function.instructions.items.len;
    }

    pub fn localIndex(self: Frame, index: u16) u32 {
        return self.local_base + index;
    }

    pub fn stackIndex(self: Frame, index: u32) u32 {
        return self.stack_base + index;
    }

    pub fn localCount(self: Frame) usize {
        return self.function.localCount();
    }

    pub fn isConstructor(self: Frame) bool {
        return self.is_constructor;
    }

    pub fn getThis(self: Frame) Value {
        return self.this_value;
    }

    pub fn getNewTarget(self: Frame) Value {
        return self.new_target;
    }

    pub fn setIp(self: *Frame, new_ip: u32) void {
        self.ip = new_ip;
    }

    pub fn saveReturn(self: *Frame, return_address: u32) void {
        self.return_address = return_address;
    }
};

pub const FrameStack = struct {
    allocator: std.mem.Allocator,
    frames: std.ArrayList(Frame),
    max_depth: u32,

    pub fn init(allocator: std.mem.Allocator) FrameStack {
        return .{
            .allocator = allocator,
            .frames = .empty,
            .max_depth = 1024,
        };
    }

    pub fn initWithDepth(allocator: std.mem.Allocator, max_depth: u32) FrameStack {
        return .{
            .allocator = allocator,
            .frames = .empty,
            .max_depth = max_depth,
        };
    }

    pub fn deinit(self: *FrameStack) void {
        self.frames.deinit(self.allocator);
    }

    pub fn depth(self: FrameStack) usize {
        return self.frames.items.len;
    }

    pub fn isEmpty(self: FrameStack) bool {
        return self.frames.items.len == 0;
    }

    pub fn isFull(self: FrameStack) bool {
        return self.frames.items.len >= self.max_depth;
    }

    pub fn push(self: *FrameStack, frame: Frame) FrameError!FrameId {
        if (self.frames.items.len >= self.max_depth) {
            return FrameError.NoFramesAvailable;
        }
        const id: FrameId = @intCast(self.frames.items.len);
        try self.frames.append(self.allocator, frame);
        return id;
    }

    pub fn pop(self: *FrameStack) ?Frame {
        if (self.frames.items.len == 0) return null;
        return self.frames.pop();
    }

    pub fn current(self: *FrameStack) ?*Frame {
        if (self.frames.items.len == 0) return null;
        return &self.frames.items[self.frames.items.len - 1];
    }

    pub fn currentConst(self: FrameStack) ?Frame {
        if (self.frames.items.len == 0) return null;
        return self.frames.items[self.frames.items.len - 1];
    }

    pub fn caller(self: *FrameStack) ?*Frame {
        if (self.frames.items.len < 2) return null;
        return &self.frames.items[self.frames.items.len - 2];
    }

    pub fn at(self: *FrameStack, index: usize) ?*Frame {
        if (index >= self.frames.items.len) return null;
        return &self.frames.items[index];
    }

    pub fn top(self: *FrameStack) ?FrameId {
        if (self.frames.items.len == 0) return null;
        return @intCast(self.frames.items.len - 1);
    }

    pub fn clear(self: *FrameStack) void {
        self.frames.clearRetainingCapacity();
    }

    pub fn truncate(self: *FrameStack, new_depth: usize) FrameError!void {
        if (new_depth > self.frames.items.len) {
            return FrameError.InvalidFrame;
        }
        self.frames.items.len = new_depth;
    }

    pub fn setMaxDepth(self: *FrameStack, d: u32) void {
        self.max_depth = d;
    }

    pub fn maxDepth(self: FrameStack) u32 {
        return self.max_depth;
    }
};

pub const CallKind = enum(u8) {
    normal,
    method,
    constructor,
    super_call,
    super_constructor,
    tail_call,

    pub fn toString(self: CallKind) []const u8 {
        return @tagName(self);
    }

    pub fn isConstructor(self: CallKind) bool {
        return self == .constructor or self == .super_constructor;
    }

    pub fn isTailCall(self: CallKind) bool {
        return self == .tail_call;
    }
};

pub const CallInfo = struct {
    kind: CallKind,
    arg_count: u8,
    return_address: u32,
    this_value: Value,

    pub fn init(kind: CallKind, arg_count: u8) CallInfo {
        return .{
            .kind = kind,
            .arg_count = arg_count,
            .return_address = 0,
            .this_value = Value.UNDEFINED,
        };
    }

    pub fn withThis(self: CallInfo, this_value: Value) CallInfo {
        var c = self;
        c.this_value = this_value;
        return c;
    }

    pub fn withReturnAddress(self: CallInfo, addr: u32) CallInfo {
        var c = self;
        c.return_address = addr;
        return c;
    }
};

pub fn createFrame(function: *Function, stack_base: u32) Frame {
    return Frame.init(function, stack_base);
}

pub fn createFrameStack(allocator: std.mem.Allocator) *FrameStack {
    const fs = allocator.create(FrameStack) catch return undefined;
    fs.* = FrameStack.init(allocator);
    return fs;
}

test "Frame init" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0);
    try std.testing.expectEqual(@as(u32, 0), frame.ip);
    try std.testing.expectEqual(@as(u32, 0), frame.stack_base);
    try std.testing.expectEqual(@as(u32, 0), frame.local_base);
    try std.testing.expectEqual(NO_FRAME, frame.saved_frame_id);
}

test "Frame withThis" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0).withThis(Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), frame.this_value.asNumber().?);
}

test "Frame withNewTarget" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0).withNewTarget(Value.TRUE);
    try std.testing.expect(frame.new_target.asBool().?);
}

test "Frame asConstructor" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0).asConstructor();
    try std.testing.expect(frame.isConstructor());
}

test "Frame withArguments" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0).withArguments(10, 3);
    try std.testing.expectEqual(@as(u32, 10), frame.arguments_start);
    try std.testing.expectEqual(@as(u16, 3), frame.arguments_count);
}

test "Frame advance" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.advance();
    try std.testing.expectEqual(@as(u32, 1), frame.ip);
}

test "Frame jump" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.jump(10);
    try std.testing.expectEqual(@as(u32, 10), frame.ip);
}

test "Frame jumpRelative positive" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.jumpRelative(5);
    try std.testing.expectEqual(@as(u32, 5), frame.ip);
}

test "Frame jumpRelative negative clamps" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.ip = 3;
    frame.jumpRelative(-10);
    try std.testing.expectEqual(@as(u32, 0), frame.ip);
}

test "Frame atEnd" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = Frame.init(&f, 0);
    try std.testing.expect(frame.atEnd());
}

test "Frame localIndex" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 10);
    frame.local_base = 10;
    try std.testing.expectEqual(@as(u32, 13), frame.localIndex(3));
}

test "Frame setIp" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.setIp(5);
    try std.testing.expectEqual(@as(u32, 5), frame.ip);
}

test "Frame saveReturn" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var frame = Frame.init(&f, 0);
    frame.saveReturn(42);
    try std.testing.expectEqual(@as(u32, 42), frame.return_address);
}

test "FrameStack init" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();
    try std.testing.expectEqual(@as(usize, 0), fs.depth());
    try std.testing.expect(fs.isEmpty());
}

test "FrameStack initWithDepth" {
    var fs = FrameStack.initWithDepth(std.testing.allocator, 64);
    defer fs.deinit();
    try std.testing.expectEqual(@as(u32, 64), fs.maxDepth());
}

test "FrameStack push and pop" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const id = try fs.push(Frame.init(&f, 0));
    try std.testing.expectEqual(@as(usize, 1), fs.depth());
    try std.testing.expectEqual(@as(FrameId, 0), id);

    const popped = fs.pop();
    try std.testing.expect(popped != null);
    try std.testing.expectEqual(@as(usize, 0), fs.depth());
}

test "FrameStack isFull" {
    var fs = FrameStack.initWithDepth(std.testing.allocator, 2);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try fs.push(Frame.init(&f, 0));
    _ = try fs.push(Frame.init(&f, 0));
    try std.testing.expect(fs.isFull());
    try std.testing.expectError(FrameError.NoFramesAvailable, fs.push(Frame.init(&f, 0)));
}

test "FrameStack current" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    try std.testing.expect(fs.current() == null);
    _ = try fs.push(Frame.init(&f, 0));
    try std.testing.expect(fs.current() != null);
}

test "FrameStack caller" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f1 = Function.init(std.testing.allocator, "caller");
    defer f1.deinit();
    var f2 = Function.init(std.testing.allocator, "callee");
    defer f2.deinit();

    _ = try fs.push(Frame.init(&f1, 0));
    try std.testing.expect(fs.caller() == null);
    _ = try fs.push(Frame.init(&f2, 0));
    try std.testing.expect(fs.caller() != null);
}

test "FrameStack at" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try fs.push(Frame.init(&f, 0));
    try std.testing.expect(fs.at(0) != null);
    try std.testing.expect(fs.at(10) == null);
}

test "FrameStack clear" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try fs.push(Frame.init(&f, 0));
    _ = try fs.push(Frame.init(&f, 0));
    fs.clear();
    try std.testing.expectEqual(@as(usize, 0), fs.depth());
}

test "FrameStack truncate" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try fs.push(Frame.init(&f, 0));
    _ = try fs.push(Frame.init(&f, 0));
    try fs.truncate(1);
    try std.testing.expectEqual(@as(usize, 1), fs.depth());
}

test "FrameStack truncate invalid" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    try std.testing.expectError(FrameError.InvalidFrame, fs.truncate(10));
}

test "FrameStack top" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    try std.testing.expect(fs.top() == null);
    _ = try fs.push(Frame.init(&f, 0));
    try std.testing.expectEqual(@as(?FrameId, 0), fs.top());
}

test "CallKind toString" {
    try std.testing.expectEqualStrings("normal", CallKind.normal.toString());
    try std.testing.expectEqualStrings("method", CallKind.method.toString());
}

test "CallKind isConstructor" {
    try std.testing.expect(CallKind.constructor.isConstructor());
    try std.testing.expect(CallKind.super_constructor.isConstructor());
    try std.testing.expect(!CallKind.normal.isConstructor());
}

test "CallKind isTailCall" {
    try std.testing.expect(CallKind.tail_call.isTailCall());
    try std.testing.expect(!CallKind.normal.isTailCall());
}

test "CallInfo init" {
    const ci = CallInfo.init(.normal, 3);
    try std.testing.expectEqual(CallKind.normal, ci.kind);
    try std.testing.expectEqual(@as(u8, 3), ci.arg_count);
}

test "CallInfo withThis" {
    const ci = CallInfo.init(.method, 1).withThis(Value.TRUE);
    try std.testing.expect(ci.this_value.asBool().?);
}

test "CallInfo withReturnAddress" {
    const ci = CallInfo.init(.normal, 0).withReturnAddress(42);
    try std.testing.expectEqual(@as(u32, 42), ci.return_address);
}

test "createFrame helper" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const frame = createFrame(&f, 5);
    try std.testing.expectEqual(@as(u32, 5), frame.stack_base);
}

test "NO_FRAME" {
    try std.testing.expectEqual(@as(FrameId, 0xFFFFFFFF), NO_FRAME);
}
