const std = @import("std");

pub const Error = error{
    OutOfMemory,
    StackOverflow,
    HeapOverflow,
    AllocationLimitExceeded,

    TypeError,
    SyntaxError,
    ReferenceError,
    RangeError,
    EvalError,
    URIError,
    AggregateError,
    InternalError,

    UnexpectedToken,
    UnexpectedEndOfInput,
    InvalidEscapeSequence,
    InvalidNumericLiteral,
    InvalidStringLiteral,
    InvalidRegexPattern,
    InvalidTemplateLiteral,
    InvalidIdentifier,
    DuplicateParameter,
    StrictModeViolation,
    ReservedWord,
    InvalidAssignmentTarget,
    InvalidDestructuring,
    InvalidLeftHandSide,

    CompileError,
    TooManyLocals,
    TooManyConstants,
    TooManyArguments,
    TooManyParameters,
    TooManyCaptures,
    BytecodeTooLarge,
    UnknownOpcode,

    RuntimeError,
    TypeMismatch,
    NotCallable,
    NotConstructable,
    NotIterable,
    NotAsyncIterable,
    NotObject,
    PropertyNotFound,
    CannotReadProperty,
    CannotSetProperty,
    CannotDeleteProperty,
    CannotDefineProperty,
    CannotRedefineProperty,
    CannotExtendObject,
    CannotConvertToPrimitive,
    CannotConvertToString,
    CannotConvertToNumber,
    CannotConvertToBigInt,
    CannotConvertToObject,
    DivisionByZero,
    InvalidDate,
    InvalidArrayLength,
    InvalidBufferLength,
    DetachedBuffer,
    OutOfBounds,
    NegativeIndex,
    InvalidIndex,
    UndefinedVariable,
    DuplicateVariable,
    TDZViolation,

    CallDepthExceeded,
    ParseDepthExceeded,
    EvalDepthExceeded,
    PrototypeChainTooDeep,
    ModuleDepthExceeded,
    JsonDepthExceeded,
    RegexBacktrackLimitExceeded,
    IteratorStepLimitExceeded,
    GeneratorStepLimitExceeded,

    ModuleNotFound,
    ModuleLoadError,
    ModuleCircularImport,
    ModuleSyntaxError,
    ModuleExportError,
    ModuleImportError,
    ModuleSpecifierInvalid,

    Timeout,
    Cancelled,
    Interrupted,

    FeatureDisabled,
    NotSupported,

    InvalidArgument,
    InvalidState,
    InvalidOperation,
    Internal,
};

pub const ErrorKind = enum {
    memory,
    js,
    parse,
    compile,
    runtime,
    limit,
    module,
    control,
    feature,
    internal,

    pub fn toString(self: ErrorKind) []const u8 {
        return @tagName(self);
    }
};

pub fn kindOf(err: anyerror) ErrorKind {
    return switch (err) {
        error.OutOfMemory,
        error.StackOverflow,
        error.HeapOverflow,
        error.AllocationLimitExceeded,
        => .memory,

        error.TypeError,
        error.SyntaxError,
        error.ReferenceError,
        error.RangeError,
        error.EvalError,
        error.URIError,
        error.AggregateError,
        error.InternalError,
        => .js,

        error.UnexpectedToken,
        error.UnexpectedEndOfInput,
        error.InvalidEscapeSequence,
        error.InvalidNumericLiteral,
        error.InvalidStringLiteral,
        error.InvalidRegexPattern,
        error.InvalidTemplateLiteral,
        error.InvalidIdentifier,
        error.DuplicateParameter,
        error.StrictModeViolation,
        error.ReservedWord,
        error.InvalidAssignmentTarget,
        error.InvalidDestructuring,
        error.InvalidLeftHandSide,
        => .parse,

        error.CompileError,
        error.TooManyLocals,
        error.TooManyConstants,
        error.TooManyArguments,
        error.TooManyParameters,
        error.TooManyCaptures,
        error.BytecodeTooLarge,
        error.UnknownOpcode,
        => .compile,

        error.RuntimeError,
        error.TypeMismatch,
        error.NotCallable,
        error.NotConstructable,
        error.NotIterable,
        error.NotAsyncIterable,
        error.NotObject,
        error.PropertyNotFound,
        error.CannotReadProperty,
        error.CannotSetProperty,
        error.CannotDeleteProperty,
        error.CannotDefineProperty,
        error.CannotRedefineProperty,
        error.CannotExtendObject,
        error.CannotConvertToPrimitive,
        error.CannotConvertToString,
        error.CannotConvertToNumber,
        error.CannotConvertToBigInt,
        error.CannotConvertToObject,
        error.DivisionByZero,
        error.InvalidDate,
        error.InvalidArrayLength,
        error.InvalidBufferLength,
        error.DetachedBuffer,
        error.OutOfBounds,
        error.NegativeIndex,
        error.InvalidIndex,
        error.UndefinedVariable,
        error.DuplicateVariable,
        error.TDZViolation,
        => .runtime,

        error.CallDepthExceeded,
        error.ParseDepthExceeded,
        error.EvalDepthExceeded,
        error.PrototypeChainTooDeep,
        error.ModuleDepthExceeded,
        error.JsonDepthExceeded,
        error.RegexBacktrackLimitExceeded,
        error.IteratorStepLimitExceeded,
        error.GeneratorStepLimitExceeded,
        => .limit,

        error.ModuleNotFound,
        error.ModuleLoadError,
        error.ModuleCircularImport,
        error.ModuleSyntaxError,
        error.ModuleExportError,
        error.ModuleImportError,
        error.ModuleSpecifierInvalid,
        => .module,

        error.Timeout,
        error.Cancelled,
        error.Interrupted,
        => .control,

        error.FeatureDisabled,
        error.NotSupported,
        => .feature,

        else => .internal,
    };
}

pub fn jsName(err: anyerror) []const u8 {
    return switch (err) {
        error.TypeError,
        error.TypeMismatch,
        error.NotCallable,
        error.NotConstructable,
        error.NotObject,
        error.CannotConvertToPrimitive,
        error.CannotConvertToString,
        error.CannotConvertToNumber,
        error.CannotConvertToBigInt,
        error.CannotConvertToObject,
        => "TypeError",

        error.SyntaxError,
        error.UnexpectedToken,
        error.UnexpectedEndOfInput,
        error.InvalidEscapeSequence,
        error.InvalidNumericLiteral,
        error.InvalidStringLiteral,
        error.InvalidRegexPattern,
        error.InvalidTemplateLiteral,
        error.InvalidIdentifier,
        error.DuplicateParameter,
        error.StrictModeViolation,
        error.ReservedWord,
        error.InvalidAssignmentTarget,
        error.InvalidDestructuring,
        error.InvalidLeftHandSide,
        error.ModuleSyntaxError,
        => "SyntaxError",

        error.ReferenceError,
        error.UndefinedVariable,
        error.DuplicateVariable,
        error.TDZViolation,
        => "ReferenceError",

        error.RangeError,
        error.NegativeIndex,
        error.InvalidIndex,
        error.InvalidArrayLength,
        error.InvalidBufferLength,
        error.OutOfBounds,
        error.InvalidDate,
        => "RangeError",

        error.EvalError => "EvalError",
        error.URIError => "URIError",
        error.AggregateError => "AggregateError",

        error.InternalError,
        error.Internal,
        => "InternalError",

        else => "Error",
    };
}

pub fn isSpecError(err: anyerror) bool {
    return switch (err) {
        error.TypeError,
        error.SyntaxError,
        error.ReferenceError,
        error.RangeError,
        error.EvalError,
        error.URIError,
        error.AggregateError,
        => true,
        else => false,
    };
}

pub fn isCatchable(err: anyerror) bool {
    return switch (err) {
        error.OutOfMemory,
        error.StackOverflow,
        error.HeapOverflow,
        error.AllocationLimitExceeded,
        error.Timeout,
        error.Cancelled,
        error.Interrupted,
        => false,
        else => true,
    };
}

pub fn isFatal(err: anyerror) bool {
    return !isCatchable(err);
}

pub fn isJsError(err: anyerror) bool {
    return kindOf(err) == .js;
}

pub fn nameOf(err: anyerror) []const u8 {
    return @errorName(err);
}

pub const ErrorInfo = struct {
    kind: ErrorKind,
    name: []const u8,
    catchable: bool,
    spec: bool,
};

pub fn infoOf(err: anyerror) ErrorInfo {
    return .{
        .kind = kindOf(err),
        .name = jsName(err),
        .catchable = isCatchable(err),
        .spec = isSpecError(err),
    };
}

pub fn isParseError(err: anyerror) bool {
    return kindOf(err) == .parse;
}

pub fn isModuleError(err: anyerror) bool {
    return kindOf(err) == .module;
}

pub fn isLimitError(err: anyerror) bool {
    return kindOf(err) == .limit;
}

pub fn isControlError(err: anyerror) bool {
    return kindOf(err) == .control;
}

test "kindOf categorizes memory errors" {
    try std.testing.expectEqual(ErrorKind.memory, kindOf(error.OutOfMemory));
    try std.testing.expectEqual(ErrorKind.memory, kindOf(error.StackOverflow));
    try std.testing.expectEqual(ErrorKind.memory, kindOf(error.HeapOverflow));
    try std.testing.expectEqual(ErrorKind.memory, kindOf(error.AllocationLimitExceeded));
}

test "kindOf categorizes js errors" {
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.TypeError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.SyntaxError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.ReferenceError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.RangeError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.EvalError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.URIError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.AggregateError));
    try std.testing.expectEqual(ErrorKind.js, kindOf(error.InternalError));
}

test "kindOf categorizes parse errors" {
    try std.testing.expectEqual(ErrorKind.parse, kindOf(error.UnexpectedToken));
    try std.testing.expectEqual(ErrorKind.parse, kindOf(error.UnexpectedEndOfInput));
    try std.testing.expectEqual(ErrorKind.parse, kindOf(error.InvalidEscapeSequence));
    try std.testing.expectEqual(ErrorKind.parse, kindOf(error.InvalidIdentifier));
}

test "kindOf categorizes compile errors" {
    try std.testing.expectEqual(ErrorKind.compile, kindOf(error.CompileError));
    try std.testing.expectEqual(ErrorKind.compile, kindOf(error.TooManyLocals));
    try std.testing.expectEqual(ErrorKind.compile, kindOf(error.BytecodeTooLarge));
}

test "kindOf categorizes runtime errors" {
    try std.testing.expectEqual(ErrorKind.runtime, kindOf(error.RuntimeError));
    try std.testing.expectEqual(ErrorKind.runtime, kindOf(error.TypeMismatch));
    try std.testing.expectEqual(ErrorKind.runtime, kindOf(error.NotCallable));
    try std.testing.expectEqual(ErrorKind.runtime, kindOf(error.OutOfBounds));
}

test "kindOf categorizes limit errors" {
    try std.testing.expectEqual(ErrorKind.limit, kindOf(error.CallDepthExceeded));
    try std.testing.expectEqual(ErrorKind.limit, kindOf(error.ParseDepthExceeded));
    try std.testing.expectEqual(ErrorKind.limit, kindOf(error.RegexBacktrackLimitExceeded));
}

test "kindOf categorizes module errors" {
    try std.testing.expectEqual(ErrorKind.module, kindOf(error.ModuleNotFound));
    try std.testing.expectEqual(ErrorKind.module, kindOf(error.ModuleLoadError));
    try std.testing.expectEqual(ErrorKind.module, kindOf(error.ModuleSyntaxError));
}

test "kindOf categorizes control errors" {
    try std.testing.expectEqual(ErrorKind.control, kindOf(error.Timeout));
    try std.testing.expectEqual(ErrorKind.control, kindOf(error.Cancelled));
    try std.testing.expectEqual(ErrorKind.control, kindOf(error.Interrupted));
}

test "kindOf categorizes feature errors" {
    try std.testing.expectEqual(ErrorKind.feature, kindOf(error.FeatureDisabled));
    try std.testing.expectEqual(ErrorKind.feature, kindOf(error.NotSupported));
}

test "kindOf categorizes misc as internal" {
    try std.testing.expectEqual(ErrorKind.internal, kindOf(error.InvalidArgument));
    try std.testing.expectEqual(ErrorKind.internal, kindOf(error.InvalidState));
    try std.testing.expectEqual(ErrorKind.internal, kindOf(error.Internal));
}

test "jsName for type errors" {
    try std.testing.expectEqualStrings("TypeError", jsName(error.TypeError));
    try std.testing.expectEqualStrings("TypeError", jsName(error.TypeMismatch));
    try std.testing.expectEqualStrings("TypeError", jsName(error.NotCallable));
    try std.testing.expectEqualStrings("TypeError", jsName(error.NotConstructable));
}

test "jsName for syntax errors" {
    try std.testing.expectEqualStrings("SyntaxError", jsName(error.SyntaxError));
    try std.testing.expectEqualStrings("SyntaxError", jsName(error.UnexpectedToken));
    try std.testing.expectEqualStrings("SyntaxError", jsName(error.InvalidEscapeSequence));
}

test "jsName for reference errors" {
    try std.testing.expectEqualStrings("ReferenceError", jsName(error.ReferenceError));
    try std.testing.expectEqualStrings("ReferenceError", jsName(error.UndefinedVariable));
    try std.testing.expectEqualStrings("ReferenceError", jsName(error.TDZViolation));
}

test "jsName for range errors" {
    try std.testing.expectEqualStrings("RangeError", jsName(error.RangeError));
    try std.testing.expectEqualStrings("RangeError", jsName(error.OutOfBounds));
    try std.testing.expectEqualStrings("RangeError", jsName(error.InvalidArrayLength));
}

test "jsName for spec-only errors" {
    try std.testing.expectEqualStrings("EvalError", jsName(error.EvalError));
    try std.testing.expectEqualStrings("URIError", jsName(error.URIError));
    try std.testing.expectEqualStrings("AggregateError", jsName(error.AggregateError));
}

test "jsName for internal error" {
    try std.testing.expectEqualStrings("InternalError", jsName(error.InternalError));
    try std.testing.expectEqualStrings("InternalError", jsName(error.Internal));
}

test "jsName falls back to Error" {
    try std.testing.expectEqualStrings("Error", jsName(error.InvalidArgument));
    try std.testing.expectEqualStrings("Error", jsName(error.InvalidState));
    try std.testing.expectEqualStrings("Error", jsName(error.CompileError));
    try std.testing.expectEqualStrings("Error", jsName(error.ModuleNotFound));
}

test "isSpecError for spec errors" {
    try std.testing.expect(isSpecError(error.TypeError));
    try std.testing.expect(isSpecError(error.SyntaxError));
    try std.testing.expect(isSpecError(error.ReferenceError));
    try std.testing.expect(isSpecError(error.RangeError));
    try std.testing.expect(isSpecError(error.EvalError));
    try std.testing.expect(isSpecError(error.URIError));
    try std.testing.expect(isSpecError(error.AggregateError));
}

test "isSpecError returns false for non-spec" {
    try std.testing.expect(!isSpecError(error.InternalError));
    try std.testing.expect(!isSpecError(error.Internal));
    try std.testing.expect(!isSpecError(error.RuntimeError));
    try std.testing.expect(!isSpecError(error.OutOfMemory));
}

test "isCatchable for js errors" {
    try std.testing.expect(isCatchable(error.TypeError));
    try std.testing.expect(isCatchable(error.SyntaxError));
    try std.testing.expect(isCatchable(error.RuntimeError));
}

test "isCatchable for memory errors" {
    try std.testing.expect(!isCatchable(error.OutOfMemory));
    try std.testing.expect(!isCatchable(error.StackOverflow));
    try std.testing.expect(!isCatchable(error.HeapOverflow));
}

test "isCatchable for control errors" {
    try std.testing.expect(!isCatchable(error.Timeout));
    try std.testing.expect(!isCatchable(error.Cancelled));
    try std.testing.expect(!isCatchable(error.Interrupted));
}

test "isFatal for uncatchable" {
    try std.testing.expect(isFatal(error.OutOfMemory));
    try std.testing.expect(isFatal(error.StackOverflow));
    try std.testing.expect(isFatal(error.Timeout));
}

test "isFatal for catchable returns false" {
    try std.testing.expect(!isFatal(error.TypeError));
    try std.testing.expect(!isFatal(error.RuntimeError));
}

test "isJsError for js kind" {
    try std.testing.expect(isJsError(error.TypeError));
    try std.testing.expect(isJsError(error.SyntaxError));
    try std.testing.expect(!isJsError(error.RuntimeError));
    try std.testing.expect(!isJsError(error.OutOfMemory));
}

test "isParseError and isModuleError and isLimitError and isControlError" {
    try std.testing.expect(isParseError(error.UnexpectedToken));
    try std.testing.expect(!isParseError(error.TypeError));
    try std.testing.expect(isModuleError(error.ModuleNotFound));
    try std.testing.expect(!isModuleError(error.TypeError));
    try std.testing.expect(isLimitError(error.CallDepthExceeded));
    try std.testing.expect(!isLimitError(error.TypeError));
    try std.testing.expect(isControlError(error.Timeout));
    try std.testing.expect(!isControlError(error.TypeError));
}

test "infoOf returns consistent info for js errors" {
    const info = infoOf(error.TypeError);
    try std.testing.expectEqual(ErrorKind.js, info.kind);
    try std.testing.expectEqualStrings("TypeError", info.name);
    try std.testing.expect(info.catchable);
    try std.testing.expect(info.spec);
}

test "infoOf for internal" {
    const info = infoOf(error.Internal);
    try std.testing.expectEqual(ErrorKind.internal, info.kind);
    try std.testing.expectEqualStrings("InternalError", info.name);
    try std.testing.expect(info.catchable);
    try std.testing.expect(!info.spec);
}

test "infoOf for out of memory" {
    const info = infoOf(error.OutOfMemory);
    try std.testing.expectEqual(ErrorKind.memory, info.kind);
    try std.testing.expect(!info.catchable);
    try std.testing.expect(!info.spec);
}

test "nameOf returns error name" {
    try std.testing.expectEqualStrings("TypeError", nameOf(error.TypeError));
    try std.testing.expectEqualStrings("OutOfMemory", nameOf(error.OutOfMemory));
    try std.testing.expectEqualStrings("StackOverflow", nameOf(error.StackOverflow));
}

test "ErrorKind toString" {
    try std.testing.expectEqualStrings("js", ErrorKind.js.toString());
    try std.testing.expectEqualStrings("memory", ErrorKind.memory.toString());
    try std.testing.expectEqualStrings("runtime", ErrorKind.runtime.toString());
    try std.testing.expectEqualStrings("parse", ErrorKind.parse.toString());
}

test "every Error tag has a kind and a name" {
    inline for (std.meta.tags(Error)) |tag| {
        _ = kindOf(tag);
        _ = jsName(tag);
        _ = isCatchable(tag);
        _ = isSpecError(tag);
        _ = infoOf(tag);
    }
}
