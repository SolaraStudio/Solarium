const std = @import("std");
const errors = @import("error.zig");

pub const EvalError = struct {
    message: []const u8,

    pub fn init(message: []const u8) EvalError {
        return .{ .message = message };
    }

    pub fn name(self: EvalError) []const u8 {
        _ = self;
        return "EvalError";
    }

    pub fn format(
        self: EvalError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("EvalError: {s}", .{self.message});
    }

    pub fn toError(self: EvalError) errors.Error {
        _ = self;
        return error.EvalError;
    }
};

pub const Kind = enum {
    invalid_eval_call,
    eval_disabled,
    eval_not_supported,
    eval_context_invalid,
    eval_depth_exceeded,
    eval_source_too_large,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .invalid_eval_call => "invalid eval call",
            .eval_disabled => "eval is disabled",
            .eval_not_supported => "eval is not supported in this context",
            .eval_context_invalid => "eval context is invalid",
            .eval_depth_exceeded => "eval depth exceeded",
            .eval_source_too_large => "eval source exceeds maximum size",
        };
    }
};

pub fn make(message: []const u8) EvalError {
    return EvalError.init(message);
}

pub fn fromKind(kind: Kind) EvalError {
    return EvalError.init(kind.message());
}

pub fn invalidEvalCall() EvalError {
    return EvalError.init(Kind.invalid_eval_call.message());
}

pub fn evalDisabled() EvalError {
    return EvalError.init(Kind.eval_disabled.message());
}

pub fn evalNotSupported() EvalError {
    return EvalError.init(Kind.eval_not_supported.message());
}

pub fn evalContextInvalid() EvalError {
    return EvalError.init(Kind.eval_context_invalid.message());
}

pub fn evalDepthExceeded() EvalError {
    return EvalError.init(Kind.eval_depth_exceeded.message());
}

pub fn evalSourceTooLarge() EvalError {
    return EvalError.init(Kind.eval_source_too_large.message());
}

test "init sets message" {
    const e = EvalError.init("bad eval");
    try std.testing.expectEqualStrings("bad eval", e.message);
}

test "name returns EvalError" {
    const e = EvalError.init("x");
    try std.testing.expectEqualStrings("EvalError", e.name());
}

test "toError returns error.EvalError" {
    const e = EvalError.init("x");
    try std.testing.expectEqual(errors.Error.EvalError, e.toError());
}

test "fromKind uses kind message" {
    const e = fromKind(.eval_disabled);
    try std.testing.expectEqualStrings("eval is disabled", e.message);
}

test "convenience constructors" {
    try std.testing.expectEqualStrings("invalid eval call", invalidEvalCall().message);
    try std.testing.expectEqualStrings("eval is disabled", evalDisabled().message);
    try std.testing.expectEqualStrings("eval is not supported in this context", evalNotSupported().message);
    try std.testing.expectEqualStrings("eval context is invalid", evalContextInvalid().message);
    try std.testing.expectEqualStrings("eval depth exceeded", evalDepthExceeded().message);
    try std.testing.expectEqualStrings("eval source exceeds maximum size", evalSourceTooLarge().message);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("invalid eval call", Kind.invalid_eval_call.message());
}
