const std = @import("std");
const errors = @import("error.zig");

pub const ReferenceError = struct {
    message: []const u8,
    identifier: ?[]const u8 = null,

    pub fn init(message: []const u8) ReferenceError {
        return .{ .message = message };
    }

    pub fn forIdentifier(identifier_name: []const u8) ReferenceError {
        return .{ .message = "identifier is not defined", .identifier = identifier_name };
    }

    pub fn name(self: ReferenceError) []const u8 {
        _ = self;
        return "ReferenceError";
    }

    pub fn format(
        self: ReferenceError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("ReferenceError: {s}", .{self.message});
        if (self.identifier) |id| {
            try writer.print(" ('{s}')", .{id});
        }
    }

    pub fn toError(self: ReferenceError) errors.Error {
        _ = self;
        return error.ReferenceError;
    }
};

pub const Kind = enum {
    not_defined,
    not_initialized,
    duplicate_declaration,
    assignment_to_constant,
    assignment_to_immutable,
    invalid_this,
    super_not_defined,
    new_target_not_defined,

    pub fn message(self: Kind) []const u8 {
        return switch (self) {
            .not_defined => "identifier is not defined",
            .not_initialized => "cannot access before initialization",
            .duplicate_declaration => "identifier has already been declared",
            .assignment_to_constant => "assignment to constant variable",
            .assignment_to_immutable => "assignment to immutable binding",
            .invalid_this => "invalid this binding",
            .super_not_defined => "super is not defined in this context",
            .new_target_not_defined => "new.target is not defined in this context",
        };
    }
};

pub fn make(message: []const u8) ReferenceError {
    return ReferenceError.init(message);
}

pub fn fromKind(kind: Kind) ReferenceError {
    return ReferenceError.init(kind.message());
}

pub fn notDefined(name: []const u8) ReferenceError {
    return ReferenceError.forIdentifier(name);
}

pub fn notInitialized(name: []const u8) ReferenceError {
    return .{ .message = Kind.not_initialized.message(), .identifier = name };
}

pub fn duplicateDeclaration(name: []const u8) ReferenceError {
    return .{ .message = Kind.duplicate_declaration.message(), .identifier = name };
}

pub fn assignmentToConstant(name: []const u8) ReferenceError {
    return .{ .message = Kind.assignment_to_constant.message(), .identifier = name };
}

pub fn assignmentToImmutable(name: []const u8) ReferenceError {
    return .{ .message = Kind.assignment_to_immutable.message(), .identifier = name };
}

pub fn invalidThis() ReferenceError {
    return ReferenceError.init(Kind.invalid_this.message());
}

pub fn superNotDefined() ReferenceError {
    return ReferenceError.init(Kind.super_not_defined.message());
}

pub fn newTargetNotDefined() ReferenceError {
    return ReferenceError.init(Kind.new_target_not_defined.message());
}

test "init sets message" {
    const r = ReferenceError.init("bad ref");
    try std.testing.expectEqualStrings("bad ref", r.message);
}

test "forIdentifier sets both fields" {
    const r = ReferenceError.forIdentifier("foo");
    try std.testing.expectEqualStrings("identifier is not defined", r.message);
    try std.testing.expectEqualStrings("foo", r.identifier.?);
}

test "name returns ReferenceError" {
    const r = ReferenceError.init("x");
    try std.testing.expectEqualStrings("ReferenceError", r.name());
}

test "toError returns error.ReferenceError" {
    const r = ReferenceError.init("x");
    try std.testing.expectEqual(errors.Error.ReferenceError, r.toError());
}

test "fromKind uses kind message" {
    const r = fromKind(.not_defined);
    try std.testing.expectEqualStrings("identifier is not defined", r.message);
}

test "notDefined sets identifier" {
    const r = notDefined("baz");
    try std.testing.expectEqualStrings("baz", r.identifier.?);
    try std.testing.expectEqualStrings("identifier is not defined", r.message);
}

test "notInitialized sets identifier" {
    const r = notInitialized("let_x");
    try std.testing.expectEqualStrings("let_x", r.identifier.?);
    try std.testing.expectEqualStrings("cannot access before initialization", r.message);
}

test "duplicateDeclaration sets identifier" {
    const r = duplicateDeclaration("dup");
    try std.testing.expectEqualStrings("dup", r.identifier.?);
}

test "assignment errors" {
    const a = assignmentToConstant("PI");
    try std.testing.expectEqualStrings("PI", a.identifier.?);
    try std.testing.expectEqualStrings("assignment to constant variable", a.message);

    const b = assignmentToImmutable("frozen");
    try std.testing.expectEqualStrings("frozen", b.identifier.?);
    try std.testing.expectEqualStrings("assignment to immutable binding", b.message);
}

test "invalidThis has no identifier" {
    const r = invalidThis();
    try std.testing.expect(r.identifier == null);
    try std.testing.expectEqualStrings("invalid this binding", r.message);
}

test "superNotDefined and newTargetNotDefined" {
    try std.testing.expectEqualStrings("super is not defined in this context", superNotDefined().message);
    try std.testing.expectEqualStrings("new.target is not defined in this context", newTargetNotDefined().message);
}

test "kind message is stable" {
    try std.testing.expectEqualStrings("identifier is not defined", Kind.not_defined.message());
    try std.testing.expectEqualStrings("assignment to constant variable", Kind.assignment_to_constant.message());
}
