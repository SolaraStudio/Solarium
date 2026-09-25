const std = @import("std");

pub const OpCode = enum(u8) {
    nop,
    pop,
    dup,
    dup2,
    swap,
    rot3,

    push_undefined,
    push_null,
    push_true,
    push_false,
    push_zero,
    push_one,
    push_int8,
    push_int16,
    push_int32,
    push_const,
    push_bigint,
    push_string,
    push_symbol,

    load_local,
    store_local,
    load_global,
    store_global,
    load_upvalue,
    store_upvalue,
    load_this,
    store_this,
    load_arguments,
    load_new_target,
    load_super,
    load_import_meta,

    add,
    sub,
    mul,
    div,
    mod,
    exp,
    neg,
    pos,
    inc,
    dec,

    bit_and,
    bit_or,
    bit_xor,
    bit_not,
    shl,
    shr,
    ushr,

    eq,
    neq,
    strict_eq,
    strict_neq,
    lt,
    gt,
    lte,
    gte,
    in,
    instanceof,

    not,
    logical_and,
    logical_or,
    logical_nullish,

    typeof_,
    void_,
    delete_,

    to_number,
    to_string,
    to_object,
    to_boolean,
    to_property_key,
    to_numeric,
    to_primitive,

    jump,
    jump_if_true,
    jump_if_false,
    jump_if_null,
    jump_if_not_null,
    jump_if_undefined,
    jump_if_not_undefined,
    jump_back,

    call,
    call_method,
    call_spread,
    new_,
    new_spread,
    return_,
    return_undefined,
    throw_,
    rethrow,

    try_push,
    try_pop,
    finally_push,
    finally_pop,

    get_property,
    get_property_optional,
    set_property,
    set_property_optional,
    get_element,
    set_element,
    delete_property,
    delete_element,
    has_property,

    new_object,
    new_array,
    new_regex,
    new_map,
    new_set,
    new_weakmap,
    new_weakset,
    new_date,
    new_promise,
    new_error,

    array_push,
    array_spread,
    object_spread,
    object_define_property,

    make_closure,
    make_arrow,
    make_generator,
    make_async,
    make_async_generator,
    make_method,
    make_class,
    make_class_method,

    iterator_init,
    iterator_next,
    iterator_close,
    iterator_return,
    for_in_init,
    for_in_next,
    for_of_init,
    for_of_next,

    yield_,
    yield_delegate,
    await_,
    async_return,
    async_throw,

    get_super_property,
    set_super_property,
    super_call,
    super_construct,

    import_module,
    export_value,
    export_default,
    dynamic_import,

    debugger,
    breakpoint,
    trace,

    halt,

    pub fn toString(self: OpCode) []const u8 {
        return @tagName(self);
    }

    pub fn hasOperand(self: OpCode) bool {
        return switch (self) {
            .push_int8,
            .push_int16,
            .push_int32,
            .push_const,
            .push_bigint,
            .push_string,
            .push_symbol,
            .load_local,
            .store_local,
            .load_global,
            .store_global,
            .load_upvalue,
            .store_upvalue,
            .load_arguments,
            .jump,
            .jump_if_true,
            .jump_if_false,
            .jump_if_null,
            .jump_if_not_null,
            .jump_if_undefined,
            .jump_if_not_undefined,
            .jump_back,
            .call,
            .call_method,
            .call_spread,
            .new_,
            .new_spread,
            .get_property,
            .get_property_optional,
            .set_property,
            .set_property_optional,
            .get_element,
            .set_element,
            .delete_property,
            .delete_element,
            .has_property,
            .new_regex,
            .new_error,
            .make_closure,
            .make_arrow,
            .make_generator,
            .make_async,
            .make_async_generator,
            .make_method,
            .make_class,
            .make_class_method,
            .iterator_init,
            .iterator_next,
            .iterator_close,
            .iterator_return,
            .for_in_init,
            .for_in_next,
            .for_of_init,
            .for_of_next,
            .get_super_property,
            .set_super_property,
            .super_call,
            .super_construct,
            .import_module,
            .export_value,
            .export_default,
            .dynamic_import,
            .try_push,
            .try_pop,
            .finally_push,
            .finally_pop,
            .breakpoint,
            => true,
            else => false,
        };
    }

    pub fn operandSize(self: OpCode) u8 {
        return switch (self) {
            .push_int8 => 1,
            .push_int16 => 2,
            .push_int32 => 4,
            .push_const => 2,
            .push_bigint => 2,
            .push_string => 2,
            .push_symbol => 2,
            .load_local,
            .store_local,
            .load_global,
            .store_global,
            .load_upvalue,
            .store_upvalue,
            .load_arguments,
            .get_property,
            .get_property_optional,
            .set_property,
            .set_property_optional,
            .delete_property,
            .has_property,
            .new_regex,
            .new_error,
            .make_closure,
            .make_arrow,
            .make_generator,
            .make_async,
            .make_async_generator,
            .make_method,
            .make_class,
            .make_class_method,
            .iterator_init,
            .iterator_next,
            .iterator_close,
            .iterator_return,
            .for_in_init,
            .for_in_next,
            .for_of_init,
            .for_of_next,
            .get_super_property,
            .set_super_property,
            .import_module,
            .export_value,
            .export_default,
            .dynamic_import,
            => 2,
            .jump,
            .jump_if_true,
            .jump_if_false,
            .jump_if_null,
            .jump_if_not_null,
            .jump_if_undefined,
            .jump_if_not_undefined,
            .jump_back,
            .try_push,
            .try_pop,
            .finally_push,
            .finally_pop,
            => 4,
            .call,
            .call_method,
            .call_spread,
            .new_,
            .new_spread,
            .super_call,
            .super_construct,
            .breakpoint,
            => 1,
            else => 0,
        };
    }

    pub fn category(self: OpCode) Category {
        return switch (self) {
            .nop,
            .pop,
            .dup,
            .dup2,
            .swap,
            .rot3,
            => .stack,

            .push_undefined,
            .push_null,
            .push_true,
            .push_false,
            .push_zero,
            .push_one,
            .push_int8,
            .push_int16,
            .push_int32,
            .push_const,
            .push_bigint,
            .push_string,
            .push_symbol,
            => .constant,

            .load_local,
            .store_local,
            .load_global,
            .store_global,
            .load_upvalue,
            .store_upvalue,
            .load_this,
            .store_this,
            .load_arguments,
            .load_new_target,
            .load_super,
            .load_import_meta,
            => .variable,

            .add,
            .sub,
            .mul,
            .div,
            .mod,
            .exp,
            .neg,
            .pos,
            .inc,
            .dec,
            => .arithmetic,

            .bit_and,
            .bit_or,
            .bit_xor,
            .bit_not,
            .shl,
            .shr,
            .ushr,
            => .bitwise,

            .eq,
            .neq,
            .strict_eq,
            .strict_neq,
            .lt,
            .gt,
            .lte,
            .gte,
            .in,
            .instanceof,
            => .comparison,

            .not,
            .logical_and,
            .logical_or,
            .logical_nullish,
            => .logical,

            .typeof_,
            .void_,
            .delete_,
            => .unary,

            .to_number,
            .to_string,
            .to_object,
            .to_boolean,
            .to_property_key,
            .to_numeric,
            .to_primitive,
            => .conversion,

            .jump,
            .jump_if_true,
            .jump_if_false,
            .jump_if_null,
            .jump_if_not_null,
            .jump_if_undefined,
            .jump_if_not_undefined,
            .jump_back,
            => .control,

            .call,
            .call_method,
            .call_spread,
            .new_,
            .new_spread,
            .return_,
            .return_undefined,
            .throw_,
            .rethrow,
            => .function,

            .try_push,
            .try_pop,
            .finally_push,
            .finally_pop,
            => .exception,

            .get_property,
            .get_property_optional,
            .set_property,
            .set_property_optional,
            .get_element,
            .set_element,
            .delete_property,
            .delete_element,
            .has_property,
            => .property,

            .new_object,
            .new_array,
            .new_regex,
            .new_map,
            .new_set,
            .new_weakmap,
            .new_weakset,
            .new_date,
            .new_promise,
            .new_error,
            => .construction,

            .array_push,
            .array_spread,
            .object_spread,
            .object_define_property,
            => .aggregate,

            .make_closure,
            .make_arrow,
            .make_generator,
            .make_async,
            .make_async_generator,
            .make_method,
            .make_class,
            .make_class_method,
            => .closure,

            .iterator_init,
            .iterator_next,
            .iterator_close,
            .iterator_return,
            .for_in_init,
            .for_in_next,
            .for_of_init,
            .for_of_next,
            => .iteration,

            .yield_,
            .yield_delegate,
            .await_,
            .async_return,
            .async_throw,
            => .async,

            .get_super_property,
            .set_super_property,
            .super_call,
            .super_construct,
            => .super,

            .import_module,
            .export_value,
            .export_default,
            .dynamic_import,
            => .module,

            .debugger,
            .breakpoint,
            .trace,
            => .debug,

            .halt => .control,
        };
    }
};

pub const Category = enum(u8) {
    stack,
    constant,
    variable,
    arithmetic,
    bitwise,
    comparison,
    logical,
    unary,
    conversion,
    control,
    function,
    exception,
    property,
    construction,
    aggregate,
    closure,
    iteration,
    async,
    super,
    module,
    debug,

    pub fn toString(self: Category) []const u8 {
        return @tagName(self);
    }
};

pub const MAX_OPERAND_SIZE: u8 = 4;
pub const MAX_INSTRUCTION_SIZE: u8 = 5;

pub fn isJump(op: OpCode) bool {
    return switch (op) {
        .jump,
        .jump_if_true,
        .jump_if_false,
        .jump_if_null,
        .jump_if_not_null,
        .jump_if_undefined,
        .jump_if_not_undefined,
        .jump_back,
        => true,
        else => false,
    };
}

pub fn isConditionalJump(op: OpCode) bool {
    return switch (op) {
        .jump_if_true,
        .jump_if_false,
        .jump_if_null,
        .jump_if_not_null,
        .jump_if_undefined,
        .jump_if_not_undefined,
        => true,
        else => false,
    };
}

pub fn isUnconditionalJump(op: OpCode) bool {
    return op == .jump or op == .jump_back;
}

pub fn isReturn(op: OpCode) bool {
    return op == .return_ or op == .return_undefined;
}

pub fn isThrow(op: OpCode) bool {
    return op == .throw_ or op == .rethrow;
}

pub fn isCall(op: OpCode) bool {
    return switch (op) {
        .call, .call_method, .call_spread, .super_call => true,
        else => false,
    };
}

pub fn isConstruct(op: OpCode) bool {
    return switch (op) {
        .new_, .new_spread, .super_construct => true,
        else => false,
    };
}

pub fn isAsyncOp(op: OpCode) bool {
    return switch (op) {
        .yield_,
        .yield_delegate,
        .await_,
        .async_return,
        .async_throw,
        => true,
        else => false,
    };
}

pub fn terminatesBlock(op: OpCode) bool {
    return switch (op) {
        .jump,
        .jump_back,
        .return_,
        .return_undefined,
        .throw_,
        .rethrow,
        .halt,
        => true,
        else => false,
    };
}

pub fn producesValue(op: OpCode) bool {
    return switch (op) {
        .nop,
        .pop,
        .jump,
        .jump_back,
        .jump_if_true,
        .jump_if_false,
        .jump_if_null,
        .jump_if_not_null,
        .jump_if_undefined,
        .jump_if_not_undefined,
        .store_local,
        .store_global,
        .store_upvalue,
        .store_this,
        .set_property,
        .set_property_optional,
        .set_element,
        .delete_property,
        .delete_element,
        .try_push,
        .try_pop,
        .finally_push,
        .finally_pop,
        .return_,
        .return_undefined,
        .throw_,
        .rethrow,
        .halt,
        .debugger,
        .breakpoint,
        .trace,
        .export_value,
        .export_default,
        .array_push,
        .object_define_property,
        .async_return,
        .async_throw,
        => false,
        else => true,
    };
}

pub fn consumesValue(op: OpCode) bool {
    return switch (op) {
        .nop,
        .push_undefined,
        .push_null,
        .push_true,
        .push_false,
        .push_zero,
        .push_one,
        .push_int8,
        .push_int16,
        .push_int32,
        .push_const,
        .push_bigint,
        .push_string,
        .push_symbol,
        .load_local,
        .load_global,
        .load_upvalue,
        .load_this,
        .load_arguments,
        .load_new_target,
        .load_super,
        .load_import_meta,
        .jump,
        .jump_back,
        .new_object,
        .new_array,
        .new_map,
        .new_set,
        .new_weakmap,
        .new_weakset,
        .try_push,
        .try_pop,
        .finally_push,
        .finally_pop,
        .import_module,
        .dynamic_import,
        .debugger,
        .breakpoint,
        .trace,
        .halt,
        => false,
        else => true,
    };
}

pub fn stackEffect(op: OpCode) i8 {
    return switch (op) {
        .nop => 0,
        .pop => -1,
        .dup => 1,
        .dup2 => 2,
        .swap => 0,
        .rot3 => 0,

        .push_undefined,
        .push_null,
        .push_true,
        .push_false,
        .push_zero,
        .push_one,
        .push_int8,
        .push_int16,
        .push_int32,
        .push_const,
        .push_bigint,
        .push_string,
        .push_symbol,
        .load_local,
        .load_global,
        .load_upvalue,
        .load_this,
        .load_arguments,
        .load_new_target,
        .load_super,
        .load_import_meta,
        => 1,

        .store_local,
        .store_global,
        .store_upvalue,
        .store_this,
        => -1,

        .add,
        .sub,
        .mul,
        .div,
        .mod,
        .exp,
        .bit_and,
        .bit_or,
        .bit_xor,
        .shl,
        .shr,
        .ushr,
        .eq,
        .neq,
        .strict_eq,
        .strict_neq,
        .lt,
        .gt,
        .lte,
        .gte,
        .in,
        .instanceof,
        .logical_and,
        .logical_or,
        .logical_nullish,
        => -1,

        .neg,
        .pos,
        .inc,
        .dec,
        .bit_not,
        .not,
        .typeof_,
        .void_,
        .delete_,
        .to_number,
        .to_string,
        .to_object,
        .to_boolean,
        .to_property_key,
        .to_numeric,
        .to_primitive,
        => 0,

        .jump,
        .jump_back,
        .try_pop,
        .finally_pop,
        .debugger,
        .breakpoint,
        .trace,
        => 0,

        .jump_if_true,
        .jump_if_false,
        .jump_if_null,
        .jump_if_not_null,
        .jump_if_undefined,
        .jump_if_not_undefined,
        => -1,

        .call,
        .call_method,
        => 1,
        .call_spread => 0,
        .new_ => 1,
        .new_spread => 0,
        .super_call => 1,
        .super_construct => 1,

        .return_ => -1,
        .return_undefined => 0,
        .throw_ => -1,
        .rethrow => -1,
        .halt => 0,

        .try_push,
        .finally_push,
        => 1,

        .get_property,
        .get_property_optional,
        .get_element,
        .has_property,
        .get_super_property,
        => 0,

        .set_property,
        .set_property_optional,
        .set_element,
        .delete_property,
        .delete_element,
        .set_super_property,
        => -2,

        .new_object,
        .new_array,
        .new_map,
        .new_set,
        .new_weakmap,
        .new_weakset,
        .new_date,
        .new_promise,
        .new_regex,
        => 1,

        .new_error => 0,
        .array_push => -1,
        .array_spread => -1,
        .object_spread => -1,
        .object_define_property => -3,

        .make_closure,
        .make_arrow,
        .make_generator,
        .make_async,
        .make_async_generator,
        .make_method,
        .make_class,
        .make_class_method,
        => 1,

        .iterator_init => 0,
        .iterator_next => 1,
        .iterator_close => -1,
        .iterator_return => -1,
        .for_in_init => 0,
        .for_in_next => 1,
        .for_of_init => 0,
        .for_of_next => 1,

        .yield_ => 0,
        .yield_delegate => 0,
        .await_ => 0,
        .async_return => -1,
        .async_throw => -1,

        .import_module => 1,
        .export_value => -1,
        .export_default => -1,
        .dynamic_import => 0,
    };
}

test "OpCode toString" {
    try std.testing.expectEqualStrings("add", OpCode.add.toString());
    try std.testing.expectEqualStrings("push_const", OpCode.push_const.toString());
}

test "OpCode hasOperand" {
    try std.testing.expect(OpCode.push_const.hasOperand());
    try std.testing.expect(OpCode.load_local.hasOperand());
    try std.testing.expect(OpCode.jump.hasOperand());
    try std.testing.expect(!OpCode.add.hasOperand());
    try std.testing.expect(!OpCode.pop.hasOperand());
}

test "OpCode operandSize" {
    try std.testing.expectEqual(@as(u8, 1), OpCode.push_int8.operandSize());
    try std.testing.expectEqual(@as(u8, 2), OpCode.push_int16.operandSize());
    try std.testing.expectEqual(@as(u8, 4), OpCode.push_int32.operandSize());
    try std.testing.expectEqual(@as(u8, 2), OpCode.push_const.operandSize());
    try std.testing.expectEqual(@as(u8, 4), OpCode.jump.operandSize());
    try std.testing.expectEqual(@as(u8, 0), OpCode.add.operandSize());
}

test "OpCode category" {
    try std.testing.expectEqual(Category.stack, OpCode.pop.category());
    try std.testing.expectEqual(Category.arithmetic, OpCode.add.category());
    try std.testing.expectEqual(Category.control, OpCode.jump.category());
    try std.testing.expectEqual(Category.function, OpCode.call.category());
    try std.testing.expectEqual(Category.property, OpCode.get_property.category());
    try std.testing.expectEqual(Category.async, OpCode.await_.category());
}

test "Category toString" {
    try std.testing.expectEqualStrings("stack", Category.stack.toString());
    try std.testing.expectEqualStrings("arithmetic", Category.arithmetic.toString());
}

test "isJump" {
    try std.testing.expect(isJump(.jump));
    try std.testing.expect(isJump(.jump_if_true));
    try std.testing.expect(isJump(.jump_back));
    try std.testing.expect(!isJump(.add));
}

test "isConditionalJump" {
    try std.testing.expect(isConditionalJump(.jump_if_true));
    try std.testing.expect(isConditionalJump(.jump_if_false));
    try std.testing.expect(!isConditionalJump(.jump));
}

test "isUnconditionalJump" {
    try std.testing.expect(isUnconditionalJump(.jump));
    try std.testing.expect(isUnconditionalJump(.jump_back));
    try std.testing.expect(!isUnconditionalJump(.jump_if_true));
}

test "isReturn" {
    try std.testing.expect(isReturn(.return_));
    try std.testing.expect(isReturn(.return_undefined));
    try std.testing.expect(!isReturn(.throw_));
}

test "isThrow" {
    try std.testing.expect(isThrow(.throw_));
    try std.testing.expect(isThrow(.rethrow));
    try std.testing.expect(!isThrow(.return_));
}

test "isCall" {
    try std.testing.expect(isCall(.call));
    try std.testing.expect(isCall(.call_method));
    try std.testing.expect(isCall(.call_spread));
    try std.testing.expect(!isCall(.new_));
}

test "isConstruct" {
    try std.testing.expect(isConstruct(.new_));
    try std.testing.expect(isConstruct(.new_spread));
    try std.testing.expect(!isConstruct(.call));
}

test "isAsyncOp" {
    try std.testing.expect(isAsyncOp(.yield_));
    try std.testing.expect(isAsyncOp(.await_));
    try std.testing.expect(!isAsyncOp(.add));
}

test "terminatesBlock" {
    try std.testing.expect(terminatesBlock(.jump));
    try std.testing.expect(terminatesBlock(.return_));
    try std.testing.expect(terminatesBlock(.throw_));
    try std.testing.expect(!terminatesBlock(.add));
}

test "producesValue" {
    try std.testing.expect(producesValue(.add));
    try std.testing.expect(producesValue(.push_const));
    try std.testing.expect(!producesValue(.pop));
    try std.testing.expect(!producesValue(.jump));
    try std.testing.expect(!producesValue(.return_));
}

test "consumesValue" {
    try std.testing.expect(consumesValue(.add));
    try std.testing.expect(!consumesValue(.push_const));
    try std.testing.expect(!consumesValue(.nop));
}

test "stackEffect add" {
    try std.testing.expectEqual(@as(i8, -1), stackEffect(.add));
}

test "stackEffect push" {
    try std.testing.expectEqual(@as(i8, 1), stackEffect(.push_const));
}

test "stackEffect dup" {
    try std.testing.expectEqual(@as(i8, 1), stackEffect(.dup));
}

test "stackEffect pop" {
    try std.testing.expectEqual(@as(i8, -1), stackEffect(.pop));
}

test "MAX_OPERAND_SIZE" {
    try std.testing.expectEqual(@as(u8, 4), MAX_OPERAND_SIZE);
}

test "MAX_INSTRUCTION_SIZE" {
    try std.testing.expectEqual(@as(u8, 5), MAX_INSTRUCTION_SIZE);
}

test "all opcodes have a category" {
    inline for (@typeInfo(OpCode).@"enum".fields) |field| {
        const op: OpCode = @enumFromInt(field.value);
        _ = op.category();
    }
}
