const std = @import("std");
const value_mod = @import("../values/value.zig");
const coercion = @import("../values/coercion.zig");
const bytecode = @import("../compiler/bytecode.zig");
const opcode_mod = @import("../compiler/opcode.zig");

pub const Value = value_mod.Value;
pub const OpCode = opcode_mod.OpCode;
pub const Instruction = bytecode.Instruction;
pub const ConstantIndex = bytecode.ConstantIndex;
pub const LocalIndex = bytecode.LocalIndex;
pub const UpvalueIndex = bytecode.UpvalueIndex;
pub const JumpOffset = bytecode.JumpOffset;

pub const DispatchError = error{
    OutOfMemory,
    StackOverflow,
    StackUnderflow,
    TypeError,
    ReferenceError,
    InternalError,
    UnsupportedOpcode,
    InvalidOperand,
    NotCallable,
};

pub const Vm = @import("vm.zig").Vm;

pub fn dispatch(vm: *Vm, inst: Instruction) DispatchError!void {
    switch (inst.op) {
        .nop => {},
        .pop => try vm.doPop(),
        .dup => try vm.doDup(),
        .dup2 => try vm.doDup2(),
        .swap => try vm.doSwap(),
        .rot3 => try vm.doRot3(),

        .push_undefined => try vm.stack.push(Value.UNDEFINED),
        .push_null => try vm.stack.push(Value.NULL),
        .push_true => try vm.stack.push(Value.TRUE),
        .push_false => try vm.stack.push(Value.FALSE),
        .push_zero => try vm.stack.push(Value.ZERO),
        .push_one => try vm.stack.push(Value.fromNumber(1.0)),
        .push_int8 => |op| try vm.stack.push(Value.fromNumber(@floatFromInt(operandInt8(op, inst)))),
        .push_int16 => |op| try vm.stack.push(Value.fromNumber(@floatFromInt(operandInt16(op, inst)))),
        .push_int32 => |op| try vm.stack.push(Value.fromNumber(@floatFromInt(operandInt32(op, inst)))),
        .push_const => try vm.doPushConst(operandConst(inst)),
        .push_string => try vm.doPushConst(operandConst(inst)),
        .push_bigint => try vm.doPushConst(operandConst(inst)),

        .load_local => try vm.doLoadLocal(operandLocal(inst)),
        .store_local => try vm.doStoreLocal(operandLocal(inst)),
        .load_global => try vm.doLoadGlobal(operandConst(inst)),
        .store_global => try vm.doStoreGlobal(operandConst(inst)),
        .load_upvalue => try vm.doLoadUpvalue(operandUpvalue(inst)),
        .store_upvalue => try vm.doStoreUpvalue(operandUpvalue(inst)),
        .load_this => try vm.doLoadThis(),

        .add => try vm.doAdd(),
        .sub => try vm.doSub(),
        .mul => try vm.doMul(),
        .div => try vm.doDiv(),
        .mod => try vm.doMod(),
        .exp => try vm.doExp(),
        .neg => try vm.doNeg(),
        .pos => {},
        .inc => try vm.doInc(),
        .dec => try vm.doDec(),

        .eq => try vm.doEq(),
        .neq => try vm.doNeq(),
        .strict_eq => try vm.doStrictEq(),
        .strict_neq => try vm.doStrictNeq(),
        .lt => try vm.doLt(),
        .gt => try vm.doGt(),
        .lte => try vm.doLte(),
        .gte => try vm.doGte(),

        .not => try vm.doNot(),
        .typeof_ => try vm.doTypeof(),
        .void_ => try vm.doVoid(),

        .logical_and => {},
        .logical_or => {},
        .logical_nullish => {},

        .jump => try vm.doJump(operandJump(inst)),
        .jump_if_true => try vm.doJumpIfTrue(operandJump(inst)),
        .jump_if_false => try vm.doJumpIfFalse(operandJump(inst)),
        .jump_if_null => try vm.doJumpIfNull(operandJump(inst)),
        .jump_if_not_null => try vm.doJumpIfNotNull(operandJump(inst)),
        .jump_if_undefined => try vm.doJumpIfUndefined(operandJump(inst)),
        .jump_if_not_undefined => try vm.doJumpIfNotUndefined(operandJump(inst)),

        .return_ => try vm.doReturn(),
        .return_undefined => try vm.doReturnUndefined(),
        .throw_ => try vm.doThrow(),
        .halt => return error.InternalError,

        .debugger, .trace, .breakpoint => {},

        else => return DispatchError.UnsupportedOpcode,
    }
}

fn operandInt8(op: opcode_mod.OpCode, inst: Instruction) i8 {
    _ = op;
    return switch (inst.operand) {
        .int8 => |v| v,
        else => 0,
    };
}

fn operandInt16(op: opcode_mod.OpCode, inst: Instruction) i16 {
    _ = op;
    return switch (inst.operand) {
        .int16 => |v| v,
        else => 0,
    };
}

fn operandInt32(op: opcode_mod.OpCode, inst: Instruction) i32 {
    _ = op;
    return switch (inst.operand) {
        .int32 => |v| v,
        else => 0,
    };
}

fn operandConst(inst: Instruction) ConstantIndex {
    return switch (inst.operand) {
        .constant => |c| c,
        else => 0,
    };
}

fn operandLocal(inst: Instruction) LocalIndex {
    return switch (inst.operand) {
        .local => |l| l,
        else => 0,
    };
}

fn operandUpvalue(inst: Instruction) UpvalueIndex {
    return switch (inst.operand) {
        .upvalue => |u| u,
        else => 0,
    };
}

fn operandJump(inst: Instruction) JumpOffset {
    return switch (inst.operand) {
        .jump => |j| j,
        else => 0,
    };
}

pub fn toNumber(v: Value) f64 {
    return switch (v) {
        .undefined => std.math.nan(f64),
        .null_val => 0.0,
        .boolean => |b| if (b) 1.0 else 0.0,
        .number => |n| n,
        else => std.math.nan(f64),
    };
}

pub fn numberToValue(n: f64) Value {
    return Value.fromNumber(n);
}

pub fn arithmeticAdd(a: Value, b: Value) Value {
    if (a.isString() or b.isString()) {
        return Value.UNDEFINED;
    }
    return Value.fromNumber(toNumber(a) + toNumber(b));
}

pub fn arithmeticSub(a: Value, b: Value) Value {
    return Value.fromNumber(toNumber(a) - toNumber(b));
}

pub fn arithmeticMul(a: Value, b: Value) Value {
    return Value.fromNumber(toNumber(a) * toNumber(b));
}

pub fn arithmeticDiv(a: Value, b: Value) Value {
    return Value.fromNumber(toNumber(a) / toNumber(b));
}

pub fn arithmeticMod(a: Value, b: Value) Value {
    const y = toNumber(b);
    if (y == 0.0) return Value.NAN;
    return Value.fromNumber(@rem(toNumber(a), y));
}

pub fn arithmeticExp(a: Value, b: Value) Value {
    return Value.fromNumber(std.math.pow(f64, toNumber(a), toNumber(b)));
}

pub fn compareLt(a: Value, b: Value) Value {
    const x = toNumber(a);
    const y = toNumber(b);
    if (std.math.isNan(x) or std.math.isNan(y)) return Value.FALSE;
    return Value.fromBool(x < y);
}

pub fn compareGt(a: Value, b: Value) Value {
    const x = toNumber(a);
    const y = toNumber(b);
    if (std.math.isNan(x) or std.math.isNan(y)) return Value.FALSE;
    return Value.fromBool(x > y);
}

pub fn compareLte(a: Value, b: Value) Value {
    const x = toNumber(a);
    const y = toNumber(b);
    if (std.math.isNan(x) or std.math.isNan(y)) return Value.FALSE;
    return Value.fromBool(x <= y);
}

pub fn compareGte(a: Value, b: Value) Value {
    const x = toNumber(a);
    const y = toNumber(b);
    if (std.math.isNan(x) or std.math.isNan(y)) return Value.FALSE;
    return Value.fromBool(x >= y);
}

pub fn looseEq(a: Value, b: Value) Value {
    return Value.fromBool(a.looseEquals(b));
}

pub fn looseNeq(a: Value, b: Value) Value {
    return Value.fromBool(!a.looseEquals(b));
}

pub fn strictEq(a: Value, b: Value) Value {
    return Value.fromBool(a.strictEquals(b));
}

pub fn strictNeq(a: Value, b: Value) Value {
    return Value.fromBool(!a.strictEquals(b));
}

pub fn logicalNot(a: Value) Value {
    return Value.fromBool(!coercion.toBoolean(a));
}

pub fn typeOf(v: Value) []const u8 {
    return switch (v) {
        .undefined => "undefined",
        .null_val => "object",
        .boolean => "boolean",
        .number => "number",
        .string => "string",
        .symbol => "symbol",
        .bigint => "bigint",
        .object => "object",
    };
}

pub fn isTruthy(v: Value) bool {
    return coercion.toBoolean(v);
}

pub fn isFalsy(v: Value) bool {
    return !coercion.toBoolean(v);
}

test "toNumber undefined" {
    try std.testing.expect(std.math.isNan(toNumber(Value.UNDEFINED)));
}

test "toNumber null" {
    try std.testing.expectEqual(@as(f64, 0.0), toNumber(Value.NULL));
}

test "toNumber boolean" {
    try std.testing.expectEqual(@as(f64, 1.0), toNumber(Value.TRUE));
    try std.testing.expectEqual(@as(f64, 0.0), toNumber(Value.FALSE));
}

test "toNumber number" {
    try std.testing.expectEqual(@as(f64, 42.0), toNumber(Value.fromNumber(42.0)));
}

test "arithmeticAdd" {
    const r = arithmeticAdd(Value.fromNumber(1.0), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 3.0), r.asNumber().?);
}

test "arithmeticSub" {
    const r = arithmeticSub(Value.fromNumber(5.0), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 3.0), r.asNumber().?);
}

test "arithmeticMul" {
    const r = arithmeticMul(Value.fromNumber(3.0), Value.fromNumber(4.0));
    try std.testing.expectEqual(@as(f64, 12.0), r.asNumber().?);
}

test "arithmeticDiv" {
    const r = arithmeticDiv(Value.fromNumber(10.0), Value.fromNumber(2.0));
    try std.testing.expectEqual(@as(f64, 5.0), r.asNumber().?);
}

test "arithmeticMod" {
    const r = arithmeticMod(Value.fromNumber(10.0), Value.fromNumber(3.0));
    try std.testing.expectEqual(@as(f64, 1.0), r.asNumber().?);
}

test "arithmeticMod zero" {
    const r = arithmeticMod(Value.fromNumber(10.0), Value.fromNumber(0.0));
    try std.testing.expect(std.math.isNan(r.asNumber().?));
}

test "arithmeticExp" {
    const r = arithmeticExp(Value.fromNumber(2.0), Value.fromNumber(3.0));
    try std.testing.expectEqual(@as(f64, 8.0), r.asNumber().?);
}

test "compareLt true" {
    const r = compareLt(Value.fromNumber(1.0), Value.fromNumber(2.0));
    try std.testing.expect(r.asBool().?);
}

test "compareLt false" {
    const r = compareLt(Value.fromNumber(2.0), Value.fromNumber(1.0));
    try std.testing.expect(!r.asBool().?);
}

test "compareGt" {
    try std.testing.expect(compareGt(Value.fromNumber(2.0), Value.fromNumber(1.0)).asBool().?);
}

test "compareLte equal" {
    try std.testing.expect(compareLte(Value.fromNumber(2.0), Value.fromNumber(2.0)).asBool().?);
}

test "compareGte equal" {
    try std.testing.expect(compareGte(Value.fromNumber(2.0), Value.fromNumber(2.0)).asBool().?);
}

test "looseEq" {
    try std.testing.expect(looseEq(Value.fromNumber(1.0), Value.fromNumber(1.0)).asBool().?);
}

test "looseNeq" {
    try std.testing.expect(looseNeq(Value.fromNumber(1.0), Value.fromNumber(2.0)).asBool().?);
}

test "strictEq" {
    try std.testing.expect(strictEq(Value.fromNumber(1.0), Value.fromNumber(1.0)).asBool().?);
    try std.testing.expect(!strictEq(Value.TRUE, Value.fromNumber(1.0)).asBool().?);
}

test "strictNeq" {
    try std.testing.expect(strictNeq(Value.TRUE, Value.fromNumber(1.0)).asBool().?);
}

test "logicalNot" {
    try std.testing.expect(logicalNot(Value.FALSE).asBool().?);
    try std.testing.expect(!logicalNot(Value.TRUE).asBool().?);
}

test "typeOf undefined" {
    try std.testing.expectEqualStrings("undefined", typeOf(Value.UNDEFINED));
}

test "typeOf null" {
    try std.testing.expectEqualStrings("object", typeOf(Value.NULL));
}

test "typeOf boolean" {
    try std.testing.expectEqualStrings("boolean", typeOf(Value.TRUE));
}

test "typeOf number" {
    try std.testing.expectEqualStrings("number", typeOf(Value.fromNumber(1.0)));
}

test "isTruthy" {
    try std.testing.expect(isTruthy(Value.TRUE));
    try std.testing.expect(isTruthy(Value.fromNumber(1.0)));
    try std.testing.expect(!isTruthy(Value.FALSE));
    try std.testing.expect(!isTruthy(Value.UNDEFINED));
    try std.testing.expect(!isTruthy(Value.NULL));
    try std.testing.expect(!isTruthy(Value.ZERO));
}

test "isFalsy" {
    try std.testing.expect(isFalsy(Value.FALSE));
    try std.testing.expect(isFalsy(Value.UNDEFINED));
    try std.testing.expect(!isFalsy(Value.TRUE));
}

test "operandConst" {
    const inst = Instruction.withConstant(.push_const, 42);
    try std.testing.expectEqual(@as(ConstantIndex, 42), operandConst(inst));
}

test "operandLocal" {
    const inst = Instruction.withLocal(.load_local, 5);
    try std.testing.expectEqual(@as(LocalIndex, 5), operandLocal(inst));
}

test "operandJump" {
    const inst = Instruction.withJump(.jump, 100);
    try std.testing.expectEqual(@as(JumpOffset, 100), operandJump(inst));
}

test "operandInt8" {
    const inst = Instruction.withInt8(.push_int8, 42);
    try std.testing.expectEqual(@as(i8, 42), operandInt8(.push_int8, inst));
}

test "numberToValue" {
    const v = numberToValue(42.0);
    try std.testing.expectEqual(@as(f64, 42.0), v.asNumber().?);
}
