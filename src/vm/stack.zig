const std = @import("std");
const value_mod = @import("../values/value.zig");

pub const Value = value_mod.Value;

pub const StackError = error{
    OutOfMemory,
    StackUnderflow,
    StackOverflow,
};

pub const DEFAULT_STACK_SIZE: usize = 1024;
pub const MAX_STACK_SIZE: usize = 65536;

pub const Stack = struct {
    allocator: std.mem.Allocator,
    values: []Value,
    top: usize,
    max_size: usize,
    peak: usize,

    pub fn init(allocator: std.mem.Allocator) !Stack {
        return try initCapacity(allocator, DEFAULT_STACK_SIZE);
    }

    pub fn initCapacity(allocator: std.mem.Allocator, cap: usize) !Stack {
        const cap_size = if (cap == 0) DEFAULT_STACK_SIZE else cap;
        const values = try allocator.alloc(Value, cap_size);
        for (values) |*v| {
            v.* = Value.UNDEFINED;
        }
        return .{
            .allocator = allocator,
            .values = values,
            .top = 0,
            .max_size = cap_size,
            .peak = 0,
        };
    }

    pub fn deinit(self: *Stack) void {
        self.allocator.free(self.values);
        self.values = &.{};
        self.top = 0;
    }

    pub fn size(self: Stack) usize {
        return self.top;
    }

    pub fn capacity(self: Stack) usize {
        return self.max_size;
    }

    pub fn remaining(self: Stack) usize {
        return self.max_size - self.top;
    }

    pub fn isEmpty(self: Stack) bool {
        return self.top == 0;
    }

    pub fn isFull(self: Stack) bool {
        return self.top >= self.max_size;
    }

    pub fn peakSize(self: Stack) usize {
        return self.peak;
    }

    pub fn push(self: *Stack, v: Value) StackError!void {
        if (self.top >= self.max_size) {
            return StackError.StackOverflow;
        }
        self.values[self.top] = v;
        self.top += 1;
        if (self.top > self.peak) {
            self.peak = self.top;
        }
    }

    pub fn pop(self: *Stack) StackError!Value {
        if (self.top == 0) {
            return StackError.StackUnderflow;
        }
        self.top -= 1;
        return self.values[self.top];
    }

    pub fn peek(self: Stack) StackError!Value {
        if (self.top == 0) {
            return StackError.StackUnderflow;
        }
        return self.values[self.top - 1];
    }

    pub fn peekAt(self: Stack, depth: usize) StackError!Value {
        if (depth >= self.top) {
            return StackError.StackUnderflow;
        }
        return self.values[self.top - 1 - depth];
    }

    pub fn popN(self: *Stack, n: usize, out: []Value) StackError!void {
        if (n > self.top) {
            return StackError.StackUnderflow;
        }
        var i: usize = 0;
        while (i < n) : (i += 1) {
            self.top -= 1;
            out[i] = self.values[self.top];
        }
    }

    pub fn pushN(self: *Stack, values: []const Value) StackError!void {
        if (self.top + values.len > self.max_size) {
            return StackError.StackOverflow;
        }
        @memcpy(self.values[self.top .. self.top + values.len], values);
        self.top += values.len;
        if (self.top > self.peak) {
            self.peak = self.top;
        }
    }

    pub fn dup(self: *Stack) StackError!void {
        const v = try self.peek();
        try self.push(v);
    }

    pub fn dup2(self: *Stack) StackError!void {
        if (self.top < 2) {
            return StackError.StackUnderflow;
        }
        const a = self.values[self.top - 2];
        const b = self.values[self.top - 1];
        try self.push(a);
        try self.push(b);
    }

    pub fn swap(self: *Stack) StackError!void {
        if (self.top < 2) {
            return StackError.StackUnderflow;
        }
        const tmp = self.values[self.top - 1];
        self.values[self.top - 1] = self.values[self.top - 2];
        self.values[self.top - 2] = tmp;
    }

    pub fn rot3(self: *Stack) StackError!void {
        if (self.top < 3) {
            return StackError.StackUnderflow;
        }
        const a = self.values[self.top - 3];
        const b = self.values[self.top - 2];
        const c = self.values[self.top - 1];
        self.values[self.top - 3] = b;
        self.values[self.top - 2] = c;
        self.values[self.top - 1] = a;
    }

    pub fn drop(self: *Stack, n: usize) StackError!void {
        if (n > self.top) {
            return StackError.StackUnderflow;
        }
        self.top -= n;
    }

    pub fn clear(self: *Stack) void {
        var i: usize = 0;
        while (i < self.top) : (i += 1) {
            self.values[i] = Value.UNDEFINED;
        }
        self.top = 0;
    }

    pub fn truncate(self: *Stack, new_size: usize) StackError!void {
        if (new_size > self.top) {
            return StackError.StackUnderflow;
        }
        var i: usize = new_size;
        while (i < self.top) : (i += 1) {
            self.values[i] = Value.UNDEFINED;
        }
        self.top = new_size;
    }

    pub fn set(self: *Stack, index: usize, v: Value) StackError!void {
        if (index >= self.top) {
            return StackError.StackUnderflow;
        }
        self.values[index] = v;
    }

    pub fn get(self: Stack, index: usize) StackError!Value {
        if (index >= self.top) {
            return StackError.StackUnderflow;
        }
        return self.values[index];
    }

    pub fn slice(self: Stack) []Value {
        return self.values[0..self.top];
    }

    pub fn sliceConst(self: Stack) []const Value {
        return self.values[0..self.top];
    }

    pub fn resetPeak(self: *Stack) void {
        self.peak = self.top;
    }

    pub fn grow(self: *Stack, new_capacity: usize) !void {
        if (new_capacity <= self.max_size) return;
        if (new_capacity > MAX_STACK_SIZE) {
            return StackError.StackOverflow;
        }
        const new_values = try self.allocator.alloc(Value, new_capacity);
        @memcpy(new_values[0..self.top], self.values[0..self.top]);
        var i: usize = self.top;
        while (i < new_capacity) : (i += 1) {
            new_values[i] = Value.UNDEFINED;
        }
        self.allocator.free(self.values);
        self.values = new_values;
        self.max_size = new_capacity;
    }
};

pub const FrameStack = struct {
    allocator: std.mem.Allocator,
    frames: std.ArrayList(u32),
    top: usize,

    pub fn init(allocator: std.mem.Allocator) FrameStack {
        return .{
            .allocator = allocator,
            .frames = .empty,
            .top = 0,
        };
    }

    pub fn deinit(self: *FrameStack) void {
        self.frames.deinit(self.allocator);
    }

    pub fn push(self: *FrameStack, base: u32) !void {
        try self.frames.append(self.allocator, base);
        self.top += 1;
    }

    pub fn pop(self: *FrameStack) ?u32 {
        if (self.top == 0) return null;
        self.top -= 1;
        return self.frames.items[self.top];
    }

    pub fn current(self: FrameStack) ?u32 {
        if (self.top == 0) return null;
        return self.frames.items[self.top - 1];
    }

    pub fn depth(self: FrameStack) usize {
        return self.top;
    }
};

pub fn create(allocator: std.mem.Allocator) !*Stack {
    const s = try allocator.create(Stack);
    s.* = try Stack.init(allocator);
    return s;
}

pub fn createCapacity(allocator: std.mem.Allocator, capacity: usize) !*Stack {
    const s = try allocator.create(Stack);
    s.* = try Stack.initCapacity(allocator, capacity);
    return s;
}

pub fn destroy(s: *Stack) void {
    const allocator = s.allocator;
    s.deinit();
    allocator.destroy(s);
}

test "Stack init" {
    var s = try Stack.init(std.testing.allocator);
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.size());
    try std.testing.expect(s.isEmpty());
    try std.testing.expect(!s.isFull());
}

test "Stack push and pop" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(42.0));
    try std.testing.expectEqual(@as(usize, 1), s.size());

    const v = try s.pop();
    try std.testing.expectEqual(@as(f64, 42.0), v.asNumber().?);
    try std.testing.expectEqual(@as(usize, 0), s.size());
}

test "Stack push overflow" {
    var s = try Stack.initCapacity(std.testing.allocator, 2);
    defer s.deinit();

    try s.push(Value.TRUE);
    try s.push(Value.FALSE);
    try std.testing.expectError(StackError.StackOverflow, s.push(Value.TRUE));
}

test "Stack pop underflow" {
    var s = try Stack.initCapacity(std.testing.allocator, 2);
    defer s.deinit();

    try std.testing.expectError(StackError.StackUnderflow, s.pop());
}

test "Stack peek" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));

    const top = try s.peek();
    try std.testing.expectEqual(@as(f64, 2.0), top.asNumber().?);
    try std.testing.expectEqual(@as(usize, 2), s.size());
}

test "Stack peekAt" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.push(Value.fromNumber(3.0));

    try std.testing.expectEqual(@as(f64, 3.0), (try s.peekAt(0)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 2.0), (try s.peekAt(1)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 1.0), (try s.peekAt(2)).asNumber().?);
}

test "Stack popN" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.push(Value.fromNumber(3.0));

    var out: [2]Value = undefined;
    try s.popN(2, &out);

    try std.testing.expectEqual(@as(usize, 1), s.size());
    try std.testing.expectEqual(@as(f64, 3.0), out[0].asNumber().?);
    try std.testing.expectEqual(@as(f64, 2.0), out[1].asNumber().?);
}

test "Stack pushN" {
    var s = try Stack.initCapacity(std.testing.allocator, 8);
    defer s.deinit();

    const vals = [_]Value{ Value.fromNumber(1.0), Value.fromNumber(2.0), Value.fromNumber(3.0) };
    try s.pushN(&vals);
    try std.testing.expectEqual(@as(usize, 3), s.size());
}

test "Stack dup" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(42.0));
    try s.dup();
    try std.testing.expectEqual(@as(usize, 2), s.size());
    try std.testing.expectEqual(@as(f64, 42.0), (try s.peek()).asNumber().?);
}

test "Stack dup2" {
    var s = try Stack.initCapacity(std.testing.allocator, 8);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.dup2();
    try std.testing.expectEqual(@as(usize, 4), s.size());
    try std.testing.expectEqual(@as(f64, 2.0), (try s.peekAt(0)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 1.0), (try s.peekAt(1)).asNumber().?);
}

test "Stack dup2 underflow" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.TRUE);
    try std.testing.expectError(StackError.StackUnderflow, s.dup2());
}

test "Stack swap" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.swap();

    try std.testing.expectEqual(@as(f64, 1.0), (try s.peekAt(0)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 2.0), (try s.peekAt(1)).asNumber().?);
}

test "Stack swap underflow" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.TRUE);
    try std.testing.expectError(StackError.StackUnderflow, s.swap());
}

test "Stack rot3" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.push(Value.fromNumber(3.0));
    try s.rot3();

    try std.testing.expectEqual(@as(f64, 2.0), (try s.peekAt(2)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 3.0), (try s.peekAt(1)).asNumber().?);
    try std.testing.expectEqual(@as(f64, 1.0), (try s.peekAt(0)).asNumber().?);
}

test "Stack rot3 underflow" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.TRUE);
    try s.push(Value.FALSE);
    try std.testing.expectError(StackError.StackUnderflow, s.rot3());
}

test "Stack drop" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.push(Value.fromNumber(3.0));

    try s.drop(2);
    try std.testing.expectEqual(@as(usize, 1), s.size());
}

test "Stack clear" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    s.clear();
    try std.testing.expectEqual(@as(usize, 0), s.size());
}

test "Stack truncate" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));
    try s.push(Value.fromNumber(3.0));

    try s.truncate(1);
    try std.testing.expectEqual(@as(usize, 1), s.size());
}

test "Stack set and get" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.set(0, Value.fromNumber(99.0));
    try std.testing.expectEqual(@as(f64, 99.0), (try s.get(0)).asNumber().?);
}

test "Stack slice" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try s.push(Value.fromNumber(1.0));
    try s.push(Value.fromNumber(2.0));

    const sl = s.sliceConst();
    try std.testing.expectEqual(@as(usize, 2), sl.len);
}

test "Stack peak tracking" {
    var s = try Stack.initCapacity(std.testing.allocator, 8);
    defer s.deinit();

    try s.push(Value.TRUE);
    try s.push(Value.TRUE);
    try s.push(Value.TRUE);
    _ = try s.pop();
    _ = try s.pop();

    try std.testing.expectEqual(@as(usize, 3), s.peakSize());
    try std.testing.expectEqual(@as(usize, 1), s.size());
}

test "Stack grow" {
    var s = try Stack.initCapacity(std.testing.allocator, 2);
    defer s.deinit();

    try s.push(Value.TRUE);
    try s.push(Value.FALSE);
    try std.testing.expectError(StackError.StackOverflow, s.push(Value.TRUE));

    try s.grow(8);
    try s.push(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 3), s.size());
}

test "Stack remaining" {
    var s = try Stack.initCapacity(std.testing.allocator, 4);
    defer s.deinit();

    try std.testing.expectEqual(@as(usize, 4), s.remaining());
    try s.push(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 3), s.remaining());
}

test "FrameStack init" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();
    try std.testing.expectEqual(@as(usize, 0), fs.depth());
}

test "FrameStack push and pop" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();

    try fs.push(10);
    try std.testing.expectEqual(@as(usize, 1), fs.depth());
    try std.testing.expectEqual(@as(?u32, 10), fs.current());

    const v = fs.pop();
    try std.testing.expectEqual(@as(?u32, 10), v);
    try std.testing.expectEqual(@as(usize, 0), fs.depth());
}

test "FrameStack current empty" {
    var fs = FrameStack.init(std.testing.allocator);
    defer fs.deinit();
    try std.testing.expect(fs.current() == null);
}

test "create helper" {
    const s = try create(std.testing.allocator);
    defer destroy(s);
    try std.testing.expectEqual(@as(usize, DEFAULT_STACK_SIZE), s.capacity());
}

test "createCapacity helper" {
    const s = try createCapacity(std.testing.allocator, 8);
    defer destroy(s);
    try std.testing.expectEqual(@as(usize, 8), s.capacity());
}

test "DEFAULT_STACK_SIZE" {
    try std.testing.expectEqual(@as(usize, 1024), DEFAULT_STACK_SIZE);
}

test "MAX_STACK_SIZE" {
    try std.testing.expectEqual(@as(usize, 65536), MAX_STACK_SIZE);
}
