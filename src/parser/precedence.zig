const std = @import("std");
const token = @import("../lexer/token.zig");
const ast = @import("ast.zig");

pub const Kind = token.Kind;
pub const BinaryOperator = ast.BinaryOperator;
pub const LogicalOperator = ast.LogicalOperator;

pub const PREC_COMMA: u8 = 1;
pub const PREC_ASSIGN: u8 = 2;
pub const PREC_CONDITIONAL: u8 = 3;
pub const PREC_NULLISH: u8 = 4;
pub const PREC_LOGICAL_OR: u8 = 5;
pub const PREC_LOGICAL_AND: u8 = 6;
pub const PREC_BIT_OR: u8 = 7;
pub const PREC_BIT_XOR: u8 = 8;
pub const PREC_BIT_AND: u8 = 9;
pub const PREC_EQUALITY: u8 = 10;
pub const PREC_RELATIONAL: u8 = 11;
pub const PREC_SHIFT: u8 = 12;
pub const PREC_ADDITIVE: u8 = 13;
pub const PREC_MULTIPLICATIVE: u8 = 14;
pub const PREC_EXPONENT: u8 = 15;
pub const PREC_UNARY: u8 = 16;
pub const PREC_UPDATE: u8 = 17;
pub const PREC_CALL: u8 = 18;
pub const PREC_MEMBER: u8 = 19;
pub const PREC_PRIMARY: u8 = 20;

pub const Assignability = enum(u8) {
    invalid,
    assignable,
    valid,
};

pub const BinaryInfo = struct {
    precedence: u8,
    operator: BinaryOperator,
    right_associative: bool = false,
};

pub const LogicalInfo = struct {
    precedence: u8,
    operator: LogicalOperator,
};

pub fn binaryInfo(kind: Kind) ?BinaryInfo {
    return switch (kind) {
        .op_add => .{ .precedence = PREC_ADDITIVE, .operator = .add },
        .op_sub => .{ .precedence = PREC_ADDITIVE, .operator = .sub },
        .op_mul => .{ .precedence = PREC_MULTIPLICATIVE, .operator = .mul },
        .op_div => .{ .precedence = PREC_MULTIPLICATIVE, .operator = .div },
        .op_mod => .{ .precedence = PREC_MULTIPLICATIVE, .operator = .mod },
        .op_exp => .{ .precedence = PREC_EXPONENT, .operator = .exp, .right_associative = true },
        .op_eq => .{ .precedence = PREC_EQUALITY, .operator = .eq },
        .op_neq => .{ .precedence = PREC_EQUALITY, .operator = .neq },
        .op_strict_eq => .{ .precedence = PREC_EQUALITY, .operator = .strict_eq },
        .op_strict_neq => .{ .precedence = PREC_EQUALITY, .operator = .strict_neq },
        .op_lt => .{ .precedence = PREC_RELATIONAL, .operator = .lt },
        .op_gt => .{ .precedence = PREC_RELATIONAL, .operator = .gt },
        .op_lte => .{ .precedence = PREC_RELATIONAL, .operator = .lte },
        .op_gte => .{ .precedence = PREC_RELATIONAL, .operator = .gte },
        .op_bit_and => .{ .precedence = PREC_BIT_AND, .operator = .bit_and },
        .op_bit_or => .{ .precedence = PREC_BIT_OR, .operator = .bit_or },
        .op_bit_xor => .{ .precedence = PREC_BIT_XOR, .operator = .bit_xor },
        .op_shl => .{ .precedence = PREC_SHIFT, .operator = .shl },
        .op_shr => .{ .precedence = PREC_SHIFT, .operator = .shr },
        .op_ushr => .{ .precedence = PREC_SHIFT, .operator = .ushr },
        .keyword_in => .{ .precedence = PREC_RELATIONAL, .operator = .in },
        .keyword_instanceof => .{ .precedence = PREC_RELATIONAL, .operator = .instanceof },
        else => null,
    };
}

pub fn logicalInfo(kind: Kind) ?LogicalInfo {
    return switch (kind) {
        .op_and_and => .{ .precedence = PREC_LOGICAL_AND, .operator = .and_ },
        .op_or_or => .{ .precedence = PREC_LOGICAL_OR, .operator = .or_ },
        .op_nullish => .{ .precedence = PREC_NULLISH, .operator = .nullish },
        else => null,
    };
}

pub fn precedenceOf(kind: Kind) ?u8 {
    if (binaryInfo(kind)) |info| return info.precedence;
    if (logicalInfo(kind)) |info| return info.precedence;
    return null;
}

pub fn isBinaryOperator(kind: Kind) bool {
    return binaryInfo(kind) != null;
}

pub fn isLogicalOperator(kind: Kind) bool {
    return logicalInfo(kind) != null;
}

pub fn isRightAssociative(kind: Kind) bool {
    if (binaryInfo(kind)) |info| return info.right_associative;
    return false;
}

pub fn isAssignmentOperator(kind: Kind) bool {
    return kind.isAssignment();
}

pub fn isUnaryOperator(kind: Kind) bool {
    return switch (kind) {
        .op_sub,
        .op_add,
        .op_not,
        .op_bit_not,
        .keyword_typeof,
        .keyword_void,
        .keyword_delete,
        => true,
        else => false,
    };
}

pub fn isUpdateOperator(kind: Kind) bool {
    return switch (kind) {
        .op_increment, .op_decrement => true,
        else => false,
    };
}

pub fn isUnaryPrecedence(prec: u8) bool {
    return prec == PREC_UNARY;
}

pub fn isExponentiation(kind: Kind) bool {
    return kind == .op_exp;
}

pub fn canBeUnaryOperand(kind: Kind) bool {
    return isUnaryOperator(kind) or isUpdateOperator(kind);
}

pub fn isInvalidExponentiationLHS(kind: Kind) bool {
    return isUnaryOperator(kind) and kind != .keyword_typeof and kind != .keyword_void and kind != .keyword_delete;
}

pub fn nullishMixAllowed(left_kind: Kind, right_kind: Kind) bool {
    const left_logical = logicalInfo(left_kind);
    const right_logical = logicalInfo(right_kind);

    if (left_logical == null or right_logical == null) return true;

    const left_op = left_logical.?.operator;
    const right_op = right_logical.?.operator;

    if (left_op == .nullish and right_op == .nullish) return true;
    if (left_op != .nullish and right_op != .nullish) return true;

    return false;
}

pub fn ternaryPrecedence() u8 {
    return PREC_CONDITIONAL;
}

pub fn assignmentPrecedence() u8 {
    return PREC_ASSIGN;
}

pub fn commaPrecedence() u8 {
    return PREC_COMMA;
}

pub fn minPrecedence() u8 {
    return PREC_COMMA;
}

pub fn maxPrecedence() u8 {
    return PREC_PRIMARY;
}

pub fn compare(a: u8, b: u8) std.math.Order {
    return std.math.order(a, b);
}

pub fn isHigher(a: u8, b: u8) bool {
    return a > b;
}

pub fn isLower(a: u8, b: u8) bool {
    return a < b;
}

test "precedence constants ordered" {
    try std.testing.expect(PREC_COMMA < PREC_ASSIGN);
    try std.testing.expect(PREC_ASSIGN < PREC_CONDITIONAL);
    try std.testing.expect(PREC_CONDITIONAL < PREC_NULLISH);
    try std.testing.expect(PREC_NULLISH < PREC_LOGICAL_OR);
    try std.testing.expect(PREC_LOGICAL_OR < PREC_LOGICAL_AND);
    try std.testing.expect(PREC_LOGICAL_AND < PREC_BIT_OR);
    try std.testing.expect(PREC_BIT_OR < PREC_BIT_XOR);
    try std.testing.expect(PREC_BIT_XOR < PREC_BIT_AND);
    try std.testing.expect(PREC_BIT_AND < PREC_EQUALITY);
    try std.testing.expect(PREC_EQUALITY < PREC_RELATIONAL);
    try std.testing.expect(PREC_RELATIONAL < PREC_SHIFT);
    try std.testing.expect(PREC_SHIFT < PREC_ADDITIVE);
    try std.testing.expect(PREC_ADDITIVE < PREC_MULTIPLICATIVE);
    try std.testing.expect(PREC_MULTIPLICATIVE < PREC_EXPONENT);
    try std.testing.expect(PREC_EXPONENT < PREC_UNARY);
    try std.testing.expect(PREC_UNARY < PREC_UPDATE);
    try std.testing.expect(PREC_UPDATE < PREC_CALL);
    try std.testing.expect(PREC_CALL < PREC_MEMBER);
    try std.testing.expect(PREC_MEMBER < PREC_PRIMARY);
}

test "binaryInfo add" {
    const info = binaryInfo(.op_add).?;
    try std.testing.expectEqual(PREC_ADDITIVE, info.precedence);
    try std.testing.expectEqual(BinaryOperator.add, info.operator);
    try std.testing.expect(!info.right_associative);
}

test "binaryInfo exp right associative" {
    const info = binaryInfo(.op_exp).?;
    try std.testing.expect(info.right_associative);
}

test "binaryInfo equality" {
    const info = binaryInfo(.op_strict_eq).?;
    try std.testing.expectEqual(PREC_EQUALITY, info.precedence);
    try std.testing.expectEqual(BinaryOperator.strict_eq, info.operator);
}

test "binaryInfo keyword in" {
    const info = binaryInfo(.keyword_in).?;
    try std.testing.expectEqual(BinaryOperator.in, info.operator);
}

test "binaryInfo keyword instanceof" {
    const info = binaryInfo(.keyword_instanceof).?;
    try std.testing.expectEqual(BinaryOperator.instanceof, info.operator);
}

test "binaryInfo non-operator returns null" {
    try std.testing.expect(binaryInfo(.identifier) == null);
    try std.testing.expect(binaryInfo(.op_and_and) == null);
}

test "logicalInfo and" {
    const info = logicalInfo(.op_and_and).?;
    try std.testing.expectEqual(PREC_LOGICAL_AND, info.precedence);
    try std.testing.expectEqual(LogicalOperator.and_, info.operator);
}

test "logicalInfo or" {
    const info = logicalInfo(.op_or_or).?;
    try std.testing.expectEqual(LogicalOperator.or_, info.operator);
}

test "logicalInfo nullish" {
    const info = logicalInfo(.op_nullish).?;
    try std.testing.expectEqual(LogicalOperator.nullish, info.operator);
}

test "precedenceOf binary" {
    try std.testing.expectEqual(PREC_ADDITIVE, precedenceOf(.op_add).?);
    try std.testing.expectEqual(PREC_MULTIPLICATIVE, precedenceOf(.op_mul).?);
}

test "precedenceOf logical" {
    try std.testing.expectEqual(PREC_LOGICAL_AND, precedenceOf(.op_and_and).?);
    try std.testing.expectEqual(PREC_LOGICAL_OR, precedenceOf(.op_or_or).?);
    try std.testing.expectEqual(PREC_NULLISH, precedenceOf(.op_nullish).?);
}

test "precedenceOf non-operator" {
    try std.testing.expect(precedenceOf(.identifier) == null);
}

test "isBinaryOperator" {
    try std.testing.expect(isBinaryOperator(.op_add));
    try std.testing.expect(isBinaryOperator(.keyword_in));
    try std.testing.expect(!isBinaryOperator(.op_and_and));
}

test "isLogicalOperator" {
    try std.testing.expect(isLogicalOperator(.op_and_and));
    try std.testing.expect(isLogicalOperator(.op_or_or));
    try std.testing.expect(isLogicalOperator(.op_nullish));
    try std.testing.expect(!isLogicalOperator(.op_add));
}

test "isRightAssociative" {
    try std.testing.expect(isRightAssociative(.op_exp));
    try std.testing.expect(!isRightAssociative(.op_add));
}

test "isAssignmentOperator" {
    try std.testing.expect(isAssignmentOperator(.op_assign));
    try std.testing.expect(isAssignmentOperator(.op_add_assign));
    try std.testing.expect(!isAssignmentOperator(.op_add));
}

test "isUnaryOperator" {
    try std.testing.expect(isUnaryOperator(.op_not));
    try std.testing.expect(isUnaryOperator(.op_sub));
    try std.testing.expect(isUnaryOperator(.keyword_typeof));
    try std.testing.expect(!isUnaryOperator(.op_add_assign));
}

test "isUpdateOperator" {
    try std.testing.expect(isUpdateOperator(.op_increment));
    try std.testing.expect(isUpdateOperator(.op_decrement));
    try std.testing.expect(!isUpdateOperator(.op_add));
}

test "isInvalidExponentiationLHS" {
    try std.testing.expect(isInvalidExponentiationLHS(.op_not));
    try std.testing.expect(isInvalidExponentiationLHS(.op_sub));
    try std.testing.expect(!isInvalidExponentiationLHS(.keyword_typeof));
    try std.testing.expect(!isInvalidExponentiationLHS(.keyword_void));
    try std.testing.expect(!isInvalidExponentiationLHS(.keyword_delete));
}

test "nullishMixAllowed" {
    try std.testing.expect(nullishMixAllowed(.op_nullish, .op_nullish));
    try std.testing.expect(nullishMixAllowed(.op_and_and, .op_or_or));
    try std.testing.expect(!nullishMixAllowed(.op_nullish, .op_and_and));
    try std.testing.expect(!nullishMixAllowed(.op_or_or, .op_nullish));
}

test "ternaryPrecedence" {
    try std.testing.expectEqual(PREC_CONDITIONAL, ternaryPrecedence());
}

test "compare precedences" {
    try std.testing.expectEqual(std.math.Order.lt, compare(PREC_ADDITIVE, PREC_MULTIPLICATIVE));
    try std.testing.expectEqual(std.math.Order.gt, compare(PREC_MULTIPLICATIVE, PREC_ADDITIVE));
    try std.testing.expectEqual(std.math.Order.eq, compare(PREC_ADDITIVE, PREC_ADDITIVE));
}

test "isHigher isLower" {
    try std.testing.expect(isHigher(PREC_MULTIPLICATIVE, PREC_ADDITIVE));
    try std.testing.expect(isLower(PREC_ADDITIVE, PREC_MULTIPLICATIVE));
}

test "minPrecedence maxPrecedence" {
    try std.testing.expectEqual(PREC_COMMA, minPrecedence());
    try std.testing.expectEqual(PREC_PRIMARY, maxPrecedence());
}
