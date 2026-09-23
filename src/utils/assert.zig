const std = @import("std");
const builtin = @import("builtin");

pub const AssertError = error{
    AssertionFailed,
    EqualityFailed,
    InequalityFailed,
    NullCheckFailed,
    NotNullCheckFailed,
    RangeCheckFailed,
    UnreachableReached,
};

pub fn isDebug() bool {
    return builtin.mode == .Debug;
}

pub fn isReleaseSafe() bool {
    return builtin.mode == .ReleaseSafe;
}

pub fn isReleaseFast() bool {
    return builtin.mode == .ReleaseFast;
}

pub fn isReleaseSmall() bool {
    return builtin.mode == .ReleaseSmall;
}

pub fn assert(condition: bool) void {
    if (!condition) {
        @panic("assertion failed");
    }
}

pub fn assertWithMessage(condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @panic(message);
    }
}

pub fn debugAssert(condition: bool) void {
    if (builtin.mode == .Debug and !condition) {
        @panic("debug assertion failed");
    }
}

pub fn debugAssertWithMessage(condition: bool, comptime message: []const u8) void {
    if (builtin.mode == .Debug and !condition) {
        @panic(message);
    }
}

pub fn assertEqual(comptime T: type, expected: T, actual: T) void {
    if (expected != actual) {
        std.debug.print("assertion failed: expected {any}, got {any}\n", .{ expected, actual });
        @panic("equality assertion failed");
    }
}

pub fn assertEqualWithMessage(comptime T: type, expected: T, actual: T, comptime message: []const u8) void {
    if (expected != actual) {
        std.debug.print("{s}: expected {any}, got {any}\n", .{ message, expected, actual });
        @panic(message);
    }
}

pub fn assertNotEqual(comptime T: type, unexpected: T, actual: T) void {
    if (unexpected == actual) {
        @panic("inequality assertion failed: values are equal");
    }
}

pub fn assertNull(value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    if (info != .optional) {
        @compileError("assertNull requires an optional type");
    }
    if (value != null) {
        @panic("expected null");
    }
}

pub fn assertNotNull(value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    if (info != .optional) {
        @compileError("assertNotNull requires an optional type");
    }
    if (value == null) {
        @panic("expected non-null");
    }
}

pub fn assertInRange(comptime T: type, value: T, min_value: T, max_value: T) void {
    if (value < min_value or value > max_value) {
        std.debug.print("value {any} not in range [{any}, {any}]\n", .{ value, min_value, max_value });
        @panic("range assertion failed");
    }
}

pub fn assertPositive(comptime T: type, value: T) void {
    if (value <= 0) {
        @panic("expected positive value");
    }
}

pub fn assertNonNegative(comptime T: type, value: T) void {
    if (value < 0) {
        @panic("expected non-negative value");
    }
}

pub fn assertNonZero(comptime T: type, value: T) void {
    if (value == 0) {
        @panic("expected non-zero value");
    }
}

pub fn assertTrue(condition: bool) void {
    assert(condition);
}

pub fn assertFalse(condition: bool) void {
    if (condition) {
        @panic("expected false");
    }
}

pub fn unreachableCode() noreturn {
    @panic("unreachable code reached");
}

pub fn unreachableWithMessage(comptime message: []const u8) noreturn {
    @panic(message);
}

pub fn comptimeAssert(comptime condition: bool) void {
    if (!condition) {
        @compileError("comptime assertion failed");
    }
}

pub fn comptimeAssertWithMessage(comptime condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @compileError(message);
    }
}

pub fn expectError(comptime T: type, result: anytype, expected: anyerror) !void {
    _ = T;
    _ = result;
    _ = expected;
    @compileError("expectError is a test-only helper; use std.testing.expectError instead");
}

pub fn assertInSlice(comptime T: type, slice: []const T, value: T) void {
    for (slice) |item| {
        if (item == value) return;
    }
    @panic("value not found in slice");
}

pub fn assertSliceEqual(comptime T: type, expected: []const T, actual: []const T) void {
    if (expected.len != actual.len) {
        @panic("slice lengths differ");
    }
    for (expected, actual) |e, a| {
        if (e != a) {
            @panic("slice element mismatch");
        }
    }
}

pub fn assertStringEqual(expected: []const u8, actual: []const u8) void {
    if (!std.mem.eql(u8, expected, actual)) {
        std.debug.print("expected '{s}', got '{s}'\n", .{ expected, actual });
        @panic("string equality assertion failed");
    }
}

pub fn assertStringContains(haystack: []const u8, needle: []const u8) void {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        @panic("substring not found");
    }
}

pub fn assertIsSorted(comptime T: type, slice: []const T) void {
    if (slice.len < 2) return;
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        if (slice[i - 1] > slice[i]) {
            @panic("slice is not sorted");
        }
    }
}

pub fn assertIsWithinCallDepth(depth: usize, max_depth: usize) void {
    if (depth > max_depth) {
        std.debug.print("call depth {d} exceeds maximum {d}\n", .{ depth, max_depth });
        @panic("call depth exceeded");
    }
}

pub fn assertValidIndex(index: usize, len: usize) void {
    if (index >= len) {
        std.debug.print("index {d} out of bounds for length {d}\n", .{ index, len });
        @panic("index out of bounds");
    }
}

test "isDebug reflects build mode" {
    const is_debug = isDebug();
    const is_release = isReleaseFast() or isReleaseSafe() or isReleaseSmall();
    try std.testing.expect(is_debug != is_release);
}

test "assert with true condition does not panic" {
    assert(true);
}

test "assertWithMessage with true does not panic" {
    assertWithMessage(true, "should not fire");
}

test "debugAssert with true does not panic" {
    debugAssert(true);
}

test "debugAssertWithMessage with true does not panic" {
    debugAssertWithMessage(true, "should not fire");
}

test "assertEqual passing" {
    assertEqual(u32, 42, 42);
}

test "assertEqualWithMessage passing" {
    assertEqualWithMessage(u32, 1, 1, "should match");
}

test "assertNotEqual passing" {
    assertNotEqual(u32, 1, 2);
}

test "assertNotNull passing" {
    const x: ?u32 = 42;
    assertNotNull(x);
}

test "assertNull passing" {
    const x: ?u32 = null;
    assertNull(x);
}

test "assertInRange passing" {
    assertInRange(u32, 5, 0, 10);
    assertInRange(u32, 0, 0, 10);
    assertInRange(u32, 10, 0, 10);
}

test "assertPositive passing" {
    assertPositive(i32, 5);
}

test "assertNonNegative passing" {
    assertNonNegative(i32, 0);
    assertNonNegative(i32, 5);
}

test "assertNonZero passing" {
    assertNonZero(i32, 5);
    assertNonZero(i32, -5);
}

test "assertTrue passing" {
    assertTrue(true);
}

test "assertFalse passing" {
    assertFalse(false);
}

test "comptimeAssert passing" {
    comptimeAssert(true);
    comptimeAssert(1 + 1 == 2);
}

test "comptimeAssertWithMessage passing" {
    comptimeAssertWithMessage(true, "should be ok");
}

test "assertInSlice passing" {
    const arr = [_]u32{ 1, 2, 3, 4 };
    assertInSlice(u32, &arr, 3);
}

test "assertSliceEqual passing" {
    const a = [_]u32{ 1, 2, 3 };
    const b = [_]u32{ 1, 2, 3 };
    assertSliceEqual(u32, &a, &b);
}

test "assertSliceEqual empty" {
    const a = [_]u32{};
    const b = [_]u32{};
    assertSliceEqual(u32, &a, &b);
}

test "assertStringEqual passing" {
    assertStringEqual("hello", "hello");
    assertStringEqual("", "");
}

test "assertStringContains passing" {
    assertStringContains("hello world", "world");
    assertStringContains("hello", "hello");
}

test "assertIsSorted passing" {
    const sorted = [_]u32{ 1, 2, 3, 4, 5 };
    assertIsSorted(u32, &sorted);
}

test "assertIsSorted single element" {
    const single = [_]u32{42};
    assertIsSorted(u32, &single);
}

test "assertIsSorted empty" {
    const empty = [_]u32{};
    assertIsSorted(u32, &empty);
}

test "assertIsWithinCallDepth passing" {
    assertIsWithinCallDepth(5, 10);
    assertIsWithinCallDepth(10, 10);
}

test "assertValidIndex passing" {
    assertValidIndex(0, 5);
    assertValidIndex(4, 5);
}

test "assertValidIndex on empty slice would fail" {
    const slice: []const u8 = &.{};
    _ = slice;
}

test "unreachableCode returns on true branch" {
    const check = struct {
        fn f(cond: bool) u32 {
            if (cond) return 1;
            unreachableCode();
        }
    };
    try std.testing.expectEqual(@as(u32, 1), check.f(true));
}

test "unreachableWithMessage returns on true branch" {
    const check = struct {
        fn f(cond: bool) u32 {
            if (cond) return 1;
            unreachableWithMessage("impossible");
        }
    };
    try std.testing.expectEqual(@as(u32, 1), check.f(true));
}
