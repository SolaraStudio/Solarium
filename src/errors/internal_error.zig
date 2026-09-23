const std = @import("std");
const errors = @import("error.zig");

pub const InternalError = struct {
    message: []const u8,
    context: ?[]const u8 = null,

    pub fn init(message: []const u8) InternalError {
        return .{ .message = message };
    }

    pub fn withContext(message: []const u8, ctx: []const u8) InternalError {
        return .{ .message = message, .context = ctx };
    }

    pub fn name(self: InternalError) []const u8 {
        _ = self;
        return "InternalError";
    }

    pub fn format(
        self: InternalError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("InternalError: {s}", .{self.message});
        if (self.context) |ctx| {
            try writer.print(" [{s}]", .{ctx});
        }
    }

    pub fn toError(self: InternalError) errors.Error {
        _ = self;
        return error.InternalError;
    }
};

pub const Kind = enum {
    unreachable_state,
    invariant_violation,
    invalid_opcode,
    corrupted_bytecode,
    corrupted_heap,
    invalid_handle,
    invalid_pointer,
    null_dereference,
    not_implemented,
    assertion_failed,
    debug_assertion_failed,
    type_confusion,
    corrupted_stack,
    corrupted_scope,
    gc_invariant,
    allocator_mismatch,
    unhandled_error,
    os_error,
    io_error,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .unreachable_state => "reached unreachable state",
            .invariant_violation => "internal invariant violated",
            .invalid_opcode => "invalid opcode encountered",
            .corrupted_bytecode => "bytecode is corrupted",
            .corrupted_heap => "heap is corrupted",
            .invalid_handle => "invalid handle",
            .invalid_pointer => "invalid pointer",
            .null_dereference => "null pointer dereference",
            .not_implemented => "feature not implemented",
            .assertion_failed => "assertion failed",
            .debug_assertion_failed => "debug assertion failed",
            .type_confusion => "type confusion detected",
            .corrupted_stack => "stack is corrupted",
            .corrupted_scope => "scope is corrupted",
            .gc_invariant => "garbage collector invariant violated",
            .allocator_mismatch => "allocator mismatch",
            .unhandled_error => "unhandled error",
            .os_error => "operating system error",
            .io_error => "input or output error",
        };
    }
};

pub fn make(message: []const u8) InternalError {
    return InternalError.init(message);
}

pub fn fromKind(kind: Kind) InternalError {
    return InternalError.init(kind.message());
}

pub fn unreachableState() InternalError {
    return InternalError.init(Kind.unreachable_state.message());
}

pub fn invariantViolation() InternalError {
    return InternalError.init(Kind.invariant_violation.message());
}

pub fn invalidOpcode() InternalError {
    return InternalError.init(Kind.invalid_opcode.message());
}

pub fn corruptedBytecode() InternalError {
    return InternalError.init(Kind.corrupted_bytecode.message());
}

pub fn corruptedHeap() InternalError {
    return InternalError.init(Kind.corrupted_heap.message());
}

pub fn invalidHandle() InternalError {
    return InternalError.init(Kind.invalid_handle.message());
}

pub fn notImplemented() InternalError {
    return InternalError.init(Kind.not_implemented.message());
}

pub fn assertionFailed() InternalError {
    return InternalError.init(Kind.assertion_failed.message());
}

pub fn typeConfusion() InternalError {
    return InternalError.init(Kind.type_confusion.message());
}

pub fn gcInvariant() InternalError {
    return InternalError.init(Kind.gc_invariant.message());
}

pub fn allocatorMismatch() InternalError {
    return InternalError.init(Kind.allocator_mismatch.message());
}

pub fn unhandledError() InternalError {
    return InternalError.init(Kind.unhandled_error.message());
}

test "init sets message" {
    const i = InternalError.init("bad thing");
    try std.testing.expectEqualStrings("bad thing", i.message);
}

test "withContext sets both" {
    const i = InternalError.withContext("bad", "vm");
    try std.testing.expectEqualStrings("bad", i.message);
    try std.testing.expectEqualStrings("vm", i.context.?);
}

test "name returns InternalError" {
    const i = InternalError.init("x");
    try std.testing.expectEqualStrings("InternalError", i.name());
}

test "toError returns error.InternalError" {
    const i = InternalError.init("x");
    try std.testing.expectEqual(errors.Error.InternalError, i.toError());
}

test "fromKind uses kind message" {
    const i = fromKind(.not_implemented);
    try std.testing.expectEqualStrings("feature not implemented", i.message);
}

test "convenience constructors part one" {
    try std.testing.expectEqualStrings("reached unreachable state", unreachableState().message);
    try std.testing.expectEqualStrings("internal invariant violated", invariantViolation().message);
    try std.testing.expectEqualStrings("invalid opcode encountered", invalidOpcode().message);
    try std.testing.expectEqualStrings("bytecode is corrupted", corruptedBytecode().message);
    try std.testing.expectEqualStrings("heap is corrupted", corruptedHeap().message);
}

test "convenience constructors part two" {
    try std.testing.expectEqualStrings("invalid handle", invalidHandle().message);
    try std.testing.expectEqualStrings("feature not implemented", notImplemented().message);
    try std.testing.expectEqualStrings("assertion failed", assertionFailed().message);
    try std.testing.expectEqualStrings("type confusion detected", typeConfusion().message);
    try std.testing.expectEqualStrings("garbage collector invariant violated", gcInvariant().message);
    try std.testing.expectEqualStrings("allocator mismatch", allocatorMismatch().message);
    try std.testing.expectEqualStrings("unhandled error", unhandledError().message);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("reached unreachable state", Kind.unreachable_state.message());
    try std.testing.expectEqualStrings("feature not implemented", Kind.not_implemented.message());
}
