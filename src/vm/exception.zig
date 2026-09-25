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

pub const ExceptionError = error{
    OutOfMemory,
    StackOverflow,
    StackUnderflow,
    NoHandler,
    InvalidHandlerState,
    UncaughtException,
    RethrowWithoutActive,
};

pub const HandlerKind = enum(u8) {
    try_block,
    catch_block,
    finally_block,
    async,
    generator,

    pub fn toString(self: HandlerKind) []const u8 {
        return @tagName(self);
    }

    pub fn isCatch(self: HandlerKind) bool {
        return self == .catch_block;
    }

    pub fn isFinally(self: HandlerKind) bool {
        return self == .finally_block;
    }
};

pub const Handler = struct {
    kind: HandlerKind,
    try_start_ip: u32,
    catch_target_ip: u32,
    finally_target_ip: u32,
    end_target_ip: u32,
    stack_depth: u32,
    frame_depth: usize,
    has_catch: bool,
    has_finally: bool,
    exception_value: Value,

    pub fn init(try_start: u32) Handler {
        return .{
            .kind = .try_block,
            .try_start_ip = try_start,
            .catch_target_ip = 0,
            .finally_target_ip = 0,
            .end_target_ip = 0,
            .stack_depth = 0,
            .frame_depth = 0,
            .has_catch = false,
            .has_finally = false,
            .exception_value = Value.UNDEFINED,
        };
    }

    pub fn withCatch(self: Handler, target: u32) Handler {
        var h = self;
        h.catch_target_ip = target;
        h.has_catch = true;
        return h;
    }

    pub fn withFinally(self: Handler, target: u32) Handler {
        var h = self;
        h.finally_target_ip = target;
        h.has_finally = true;
        return h;
    }

    pub fn withEnd(self: Handler, target: u32) Handler {
        var h = self;
        h.end_target_ip = target;
        return h;
    }

    pub fn withStackDepth(self: Handler, depth: u32) Handler {
        var h = self;
        h.stack_depth = depth;
        return h;
    }

    pub fn withFrameDepth(self: Handler, depth: usize) Handler {
        var h = self;
        h.frame_depth = depth;
        return h;
    }

    pub fn withException(self: Handler, e: Value) Handler {
        var h = self;
        h.exception_value = e;
        return h;
    }

    pub fn canHandle(self: Handler) bool {
        return self.has_catch or self.has_finally;
    }

    pub fn targetIp(self: Handler) u32 {
        if (self.has_catch) return self.catch_target_ip;
        if (self.has_finally) return self.finally_target_ip;
        return self.end_target_ip;
    }
};

pub const ExceptionState = struct {
    value: Value,
    pending: bool,
    caught: bool,
    rethrow_pending: bool,

    pub fn init() ExceptionState {
        return .{
            .value = Value.UNDEFINED,
            .pending = false,
            .caught = false,
            .rethrow_pending = false,
        };
    }

    pub fn withValue(self: ExceptionState, v: Value) ExceptionState {
        var s = self;
        s.value = v;
        s.pending = true;
        return s;
    }

    pub fn markCaught(self: ExceptionState) ExceptionState {
        var s = self;
        s.pending = false;
        s.caught = true;
        return s;
    }

    pub fn markRethrow(self: ExceptionState) ExceptionState {
        var s = self;
        s.rethrow_pending = true;
        s.pending = true;
        return s;
    }

    pub fn clear(self: ExceptionState) ExceptionState {
        var s = self;
        s.value = Value.UNDEFINED;
        s.pending = false;
        s.caught = false;
        s.rethrow_pending = false;
        return s;
    }

    pub fn hasPending(self: ExceptionState) bool {
        return self.pending;
    }

    pub fn isActive(self: ExceptionState) bool {
        return self.pending or self.caught or self.rethrow_pending;
    }
};

pub const HandlerStack = struct {
    allocator: std.mem.Allocator,
    handlers: std.ArrayList(Handler),

    pub fn init(allocator: std.mem.Allocator) HandlerStack {
        return .{
            .allocator = allocator,
            .handlers = .empty,
        };
    }

    pub fn deinit(self: *HandlerStack) void {
        self.handlers.deinit(self.allocator);
    }

    pub fn depth(self: HandlerStack) usize {
        return self.handlers.items.len;
    }

    pub fn isEmpty(self: HandlerStack) bool {
        return self.handlers.items.len == 0;
    }

    pub fn push(self: *HandlerStack, h: Handler) !void {
        try self.handlers.append(self.allocator, h);
    }

    pub fn pop(self: *HandlerStack) ?Handler {
        if (self.handlers.items.len == 0) return null;
        return self.handlers.pop();
    }

    pub fn current(self: *HandlerStack) ?*Handler {
        if (self.handlers.items.len == 0) return null;
        return &self.handlers.items[self.handlers.items.len - 1];
    }

    pub fn findCatch(self: *HandlerStack, frame_depth: usize) ?*Handler {
        var i: usize = self.handlers.items.len;
        while (i > 0) {
            i -= 1;
            const h = &self.handlers.items[i];
            if (h.has_catch and h.frame_depth <= frame_depth) return h;
        }
        return null;
    }

    pub fn findFinally(self: *HandlerStack, frame_depth: usize) ?*Handler {
        var i: usize = self.handlers.items.len;
        while (i > 0) {
            i -= 1;
            const h = &self.handlers.items[i];
            if (h.has_finally and h.frame_depth <= frame_depth) return h;
        }
        return null;
    }

    pub fn clear(self: *HandlerStack) void {
        self.handlers.clearRetainingCapacity();
    }

    pub fn truncate(self: *HandlerStack, d: usize) void {
        if (d < self.handlers.items.len) {
            self.handlers.items.len = d;
        }
    }
};

pub const ExceptionHandler = struct {
    handlers: *HandlerStack,
    stack: *Stack,
    frames: *FrameStack,
    state: ExceptionState,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        handlers: *HandlerStack,
        stack: *Stack,
        frames: *FrameStack,
    ) ExceptionHandler {
        return .{
            .allocator = allocator,
            .handlers = handlers,
            .stack = stack,
            .frames = frames,
            .state = ExceptionState.init(),
        };
    }

    pub fn throw(self: *ExceptionHandler, value: Value) ExceptionError!ExceptionResult {
        self.state = self.state.withValue(value);

        const current_frame_depth = self.frames.depth();

        if (self.handlers.findCatch(current_frame_depth)) |handler| {
            return try self.dispatchToCatch(handler, value);
        }

        if (self.handlers.findFinally(current_frame_depth)) |handler| {
            return try self.dispatchToFinally(handler, value);
        }

        return try self.propagate(value);
    }

    fn dispatchToCatch(
        self: *ExceptionHandler,
        handler: *Handler,
        value: Value,
    ) ExceptionError!ExceptionResult {
        while (self.stack.size() > handler.stack_depth) {
            _ = self.stack.pop() catch break;
        }

        while (self.frames.depth() > handler.frame_depth) {
            _ = self.frames.pop();
        }

        try self.stack.push(value);

        if (self.frames.current()) |frame| {
            frame.setIp(handler.catch_target_ip);
        }

        self.state = self.state.markCaught();

        return ExceptionResult.init(.handled_catch, value, handler.catch_target_ip);
    }

    fn dispatchToFinally(
        self: *ExceptionHandler,
        handler: *Handler,
        value: Value,
    ) ExceptionError!ExceptionResult {
        try self.stack.push(value);

        if (self.frames.current()) |frame| {
            frame.setIp(handler.finally_target_ip);
        }

        return ExceptionResult.init(.handled_finally, value, handler.finally_target_ip);
    }

    fn propagate(self: *ExceptionHandler, value: Value) ExceptionError!ExceptionResult {
        _ = self;
        return ExceptionResult.init(.uncaught, value, 0);
    }

    pub fn rethrow(self: *ExceptionHandler) ExceptionError!ExceptionResult {
        if (!self.state.isActive()) {
            return ExceptionError.RethrowWithoutActive;
        }
        const value = self.state.value;
        self.state = self.state.markRethrow();
        return try self.throw(value);
    }

    pub fn pushHandler(self: *ExceptionHandler, h: Handler) ExceptionError!void {
        try self.handlers.push(h);
    }

    pub fn popHandler(self: *ExceptionHandler) ExceptionError!void {
        _ = self.handlers.pop();
    }

    pub fn currentHandler(self: *ExceptionHandler) ?*Handler {
        return self.handlers.current();
    }

    pub fn hasHandler(self: ExceptionHandler) bool {
        return !self.handlers.isEmpty();
    }

    pub fn clearException(self: *ExceptionHandler) void {
        self.state = ExceptionState.init();
    }

    pub fn isPending(self: *ExceptionHandler) bool {
        return self.state.hasPending();
    }

    pub fn getExceptionValue(self: *ExceptionHandler) Value {
        return self.state.value;
    }
};

pub const ExceptionKind = enum(u8) {
    handled_catch,
    handled_finally,
    uncaught,
    propagating,
    rethrown,

    pub fn toString(self: ExceptionKind) []const u8 {
        return @tagName(self);
    }

    pub fn isHandled(self: ExceptionKind) bool {
        return self == .handled_catch or self == .handled_finally;
    }

    pub fn isUncaught(self: ExceptionKind) bool {
        return self == .uncaught;
    }
};

pub const ExceptionResult = struct {
    kind: ExceptionKind,
    value: Value,
    target_ip: u32,

    pub fn init(kind: ExceptionKind, value: Value, target: u32) ExceptionResult {
        return .{
            .kind = kind,
            .value = value,
            .target_ip = target,
        };
    }

    pub fn isHandled(self: ExceptionResult) bool {
        return self.kind.isHandled();
    }

    pub fn isUncaught(self: ExceptionResult) bool {
        return self.kind.isUncaught();
    }
};

pub fn isExceptionOp(op: @import("../compiler/opcode.zig").OpCode) bool {
    return switch (op) {
        .throw_,
        .rethrow,
        .try_push,
        .try_pop,
        .finally_push,
        .finally_pop,
        => true,
        else => false,
    };
}

pub fn isThrowOp(op: @import("../compiler/opcode.zig").OpCode) bool {
    return op == .throw_ or op == .rethrow;
}

pub fn createHandler(kind: HandlerKind, try_start: u32) Handler {
    var h = Handler.init(try_start);
    h.kind = kind;
    return h;
}

test "HandlerKind toString" {
    try std.testing.expectEqualStrings("try_block", HandlerKind.try_block.toString());
    try std.testing.expectEqualStrings("catch_block", HandlerKind.catch_block.toString());
}

test "HandlerKind isCatch" {
    try std.testing.expect(HandlerKind.catch_block.isCatch());
    try std.testing.expect(!HandlerKind.try_block.isCatch());
}

test "HandlerKind isFinally" {
    try std.testing.expect(HandlerKind.finally_block.isFinally());
    try std.testing.expect(!HandlerKind.try_block.isFinally());
}

test "Handler init" {
    const h = Handler.init(10);
    try std.testing.expectEqual(@as(u32, 10), h.try_start_ip);
    try std.testing.expect(!h.has_catch);
    try std.testing.expect(!h.has_finally);
}

test "Handler withCatch" {
    const h = Handler.init(0).withCatch(20);
    try std.testing.expect(h.has_catch);
    try std.testing.expectEqual(@as(u32, 20), h.catch_target_ip);
}

test "Handler withFinally" {
    const h = Handler.init(0).withFinally(30);
    try std.testing.expect(h.has_finally);
    try std.testing.expectEqual(@as(u32, 30), h.finally_target_ip);
}

test "Handler withEnd" {
    const h = Handler.init(0).withEnd(40);
    try std.testing.expectEqual(@as(u32, 40), h.end_target_ip);
}

test "Handler withStackDepth" {
    const h = Handler.init(0).withStackDepth(5);
    try std.testing.expectEqual(@as(u32, 5), h.stack_depth);
}

test "Handler withFrameDepth" {
    const h = Handler.init(0).withFrameDepth(3);
    try std.testing.expectEqual(@as(usize, 3), h.frame_depth);
}

test "Handler withException" {
    const h = Handler.init(0).withException(Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(f64, 42.0), h.exception_value.asNumber().?);
}

test "Handler canHandle" {
    const h1 = Handler.init(0);
    try std.testing.expect(!h1.canHandle());

    const h2 = Handler.init(0).withCatch(10);
    try std.testing.expect(h2.canHandle());

    const h3 = Handler.init(0).withFinally(20);
    try std.testing.expect(h3.canHandle());
}

test "Handler targetIp catch" {
    const h = Handler.init(0).withCatch(10).withFinally(20);
    try std.testing.expectEqual(@as(u32, 10), h.targetIp());
}

test "Handler targetIp finally" {
    const h = Handler.init(0).withFinally(20);
    try std.testing.expectEqual(@as(u32, 20), h.targetIp());
}

test "ExceptionState init" {
    const s = ExceptionState.init();
    try std.testing.expect(!s.hasPending());
    try std.testing.expect(!s.isActive());
}

test "ExceptionState withValue" {
    const s = ExceptionState.init().withValue(Value.TRUE);
    try std.testing.expect(s.hasPending());
    try std.testing.expect(s.isActive());
}

test "ExceptionState markCaught" {
    const s = ExceptionState.init().withValue(Value.TRUE).markCaught();
    try std.testing.expect(!s.hasPending());
    try std.testing.expect(s.caught);
}

test "ExceptionState markRethrow" {
    const s = ExceptionState.init().withValue(Value.TRUE).markRethrow();
    try std.testing.expect(s.rethrow_pending);
    try std.testing.expect(s.hasPending());
}

test "ExceptionState clear" {
    const s = ExceptionState.init().withValue(Value.TRUE).clear();
    try std.testing.expect(!s.isActive());
}

test "HandlerStack init" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();
    try std.testing.expectEqual(@as(usize, 0), hs.depth());
    try std.testing.expect(hs.isEmpty());
}

test "HandlerStack push and pop" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0));
    try std.testing.expectEqual(@as(usize, 1), hs.depth());

    const popped = hs.pop();
    try std.testing.expect(popped != null);
    try std.testing.expectEqual(@as(usize, 0), hs.depth());
}

test "HandlerStack current" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try std.testing.expect(hs.current() == null);
    try hs.push(Handler.init(0));
    try std.testing.expect(hs.current() != null);
}

test "HandlerStack findCatch" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0).withCatch(10).withFrameDepth(0));
    try std.testing.expect(hs.findCatch(0) != null);
    try std.testing.expect(hs.findCatch(5) != null);
}

test "HandlerStack findCatch none" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0).withFrameDepth(5));
    try std.testing.expect(hs.findCatch(3) == null);
}

test "HandlerStack findFinally" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0).withFinally(20).withFrameDepth(0));
    try std.testing.expect(hs.findFinally(0) != null);
}

test "HandlerStack truncate" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0));
    try hs.push(Handler.init(1));
    try hs.push(Handler.init(2));
    hs.truncate(1);
    try std.testing.expectEqual(@as(usize, 1), hs.depth());
}

test "HandlerStack clear" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    try hs.push(Handler.init(0));
    hs.clear();
    try std.testing.expectEqual(@as(usize, 0), hs.depth());
}

test "ExceptionKind toString" {
    try std.testing.expectEqualStrings("handled_catch", ExceptionKind.handled_catch.toString());
    try std.testing.expectEqualStrings("uncaught", ExceptionKind.uncaught.toString());
}

test "ExceptionKind isHandled" {
    try std.testing.expect(ExceptionKind.handled_catch.isHandled());
    try std.testing.expect(!ExceptionKind.uncaught.isHandled());
}

test "ExceptionKind isUncaught" {
    try std.testing.expect(ExceptionKind.uncaught.isUncaught());
    try std.testing.expect(!ExceptionKind.handled_catch.isUncaught());
}

test "ExceptionResult init" {
    const r = ExceptionResult.init(.handled_catch, Value.TRUE, 10);
    try std.testing.expectEqual(ExceptionKind.handled_catch, r.kind);
    try std.testing.expectEqual(@as(u32, 10), r.target_ip);
}

test "ExceptionResult isHandled" {
    const r = ExceptionResult.init(.handled_catch, Value.TRUE, 10);
    try std.testing.expect(r.isHandled());
    try std.testing.expect(!r.isUncaught());
}

test "ExceptionResult isUncaught" {
    const r = ExceptionResult.init(.uncaught, Value.TRUE, 0);
    try std.testing.expect(r.isUncaught());
}

test "ExceptionHandler init" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    const eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);
    try std.testing.expect(!eh.hasHandler());
}

test "ExceptionHandler push and pop handler" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);
    try eh.pushHandler(Handler.init(0));
    try std.testing.expect(eh.hasHandler());
    try eh.popHandler();
    try std.testing.expect(!eh.hasHandler());
}

test "ExceptionHandler throw uncaught" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);
    const result = try eh.throw(Value.fromNumber(42.0));
    try std.testing.expect(result.isUncaught());
    try std.testing.expect(eh.isPending());
}

test "ExceptionHandler throw handled by catch" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();
    _ = try frames.push(Frame.init(&f, 0));

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);

    const handler = Handler.init(0)
        .withCatch(20)
        .withStackDepth(0)
        .withFrameDepth(1);
    try eh.pushHandler(handler);

    const result = try eh.throw(Value.fromNumber(42.0));
    try std.testing.expect(result.isHandled());
    try std.testing.expectEqual(@as(u32, 20), result.target_ip);
}

test "ExceptionHandler throw handled by finally" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();
    _ = try frames.push(Frame.init(&f, 0));

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);

    const handler = Handler.init(0)
        .withFinally(30)
        .withFrameDepth(1);
    try eh.pushHandler(handler);

    const result = try eh.throw(Value.fromNumber(42.0));
    try std.testing.expect(result.isHandled());
    try std.testing.expectEqual(@as(u32, 30), result.target_ip);
}

test "ExceptionHandler clearException" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);
    _ = try eh.throw(Value.TRUE);
    try std.testing.expect(eh.isPending());

    eh.clearException();
    try std.testing.expect(!eh.isPending());
}

test "ExceptionHandler rethrow without active" {
    var hs = HandlerStack.init(std.testing.allocator);
    defer hs.deinit();

    var stack = try Stack.initCapacity(std.testing.allocator, 32);
    defer stack.deinit();

    var frames = FrameStack.init(std.testing.allocator);
    defer frames.deinit();

    var eh = ExceptionHandler.init(std.testing.allocator, &hs, &stack, &frames);
    try std.testing.expectError(ExceptionError.RethrowWithoutActive, eh.rethrow());
}

test "isExceptionOp" {
    try std.testing.expect(isExceptionOp(.throw_));
    try std.testing.expect(isExceptionOp(.try_push));
    try std.testing.expect(isExceptionOp(.finally_pop));
    try std.testing.expect(!isExceptionOp(.add));
}

test "isThrowOp" {
    try std.testing.expect(isThrowOp(.throw_));
    try std.testing.expect(isThrowOp(.rethrow));
    try std.testing.expect(!isThrowOp(.try_push));
}

test "createHandler helper" {
    const h = createHandler(.try_block, 10);
    try std.testing.expectEqual(HandlerKind.try_block, h.kind);
    try std.testing.expectEqual(@as(u32, 10), h.try_start_ip);
}
