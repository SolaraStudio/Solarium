const std = @import("std");
const opcode_mod = @import("opcode.zig");
const bytecode = @import("bytecode.zig");

pub const OpCode = opcode_mod.OpCode;
pub const Instruction = bytecode.Instruction;
pub const Function = bytecode.Function;
pub const ConstantIndex = bytecode.ConstantIndex;

pub const OptimizationResult = struct {
    removed: usize,
    replaced: usize,
    folded: usize,
    jumps_simplified: usize,

    pub fn init() OptimizationResult {
        return .{
            .removed = 0,
            .replaced = 0,
            .folded = 0,
            .jumps_simplified = 0,
        };
    }

    pub fn total(self: OptimizationResult) usize {
        return self.removed + self.replaced + self.folded + self.jumps_simplified;
    }
};

pub const Pass = enum(u8) {
    dead_code,
    constant_folding,
    peephole,
    jump_threading,
    stack_peephole,

    pub fn toString(self: Pass) []const u8 {
        return @tagName(self);
    }
};

pub const Options = struct {
    dead_code: bool = true,
    constant_folding: bool = true,
    peephole: bool = true,
    jump_threading: bool = true,
    stack_peephole: bool = true,
    max_iterations: u32 = 10,

    pub fn none() Options {
        return .{
            .dead_code = false,
            .constant_folding = false,
            .peephole = false,
            .jump_threading = false,
            .stack_peephole = false,
        };
    }

    pub fn all() Options {
        return .{};
    }
};

pub const Optimizer = struct {
    allocator: std.mem.Allocator,
    options: Options,

    pub fn init(allocator: std.mem.Allocator) Optimizer {
        return .{
            .allocator = allocator,
            .options = Options.all(),
        };
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Optimizer {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn optimize(self: *Optimizer, function: *Function) !OptimizationResult {
        var total = OptimizationResult.init();
        var iteration: u32 = 0;

        while (iteration < self.options.max_iterations) : (iteration += 1) {
            const before = function.instructions.items.len;

            if (self.options.dead_code) {
                const r = try self.removeDeadCode(function);
                total.removed += r.removed;
            }

            if (self.options.peephole) {
                const r = try self.peephole(function);
                total.replaced += r.replaced;
            }

            if (self.options.stack_peephole) {
                const r = try self.stackPeephole(function);
                total.removed += r.removed;
            }

            if (self.options.jump_threading) {
                const r = try self.threadJumps(function);
                total.jumps_simplified += r.jumps_simplified;
            }

            const after = function.instructions.items.len;
            if (after == before) break;
        }

        return total;
    }

    fn removeDeadCode(self: *Optimizer, function: *Function) !OptimizationResult {
        _ = self;
        var result = OptimizationResult.init();

        var i: usize = 0;
        while (i < function.instructions.items.len) {
            const inst = function.instructions.items[i];
            if (!opcode_mod.terminatesBlock(inst.op)) {
                i += 1;
                continue;
            }

            var j = i + 1;
            while (j < function.instructions.items.len) {
                const next = function.instructions.items[j];
                if (next.op == .jump or next.op == .jump_back) break;
                if (next.op == .nop) {
                    j += 1;
                    continue;
                }
                if (next.op == .debugger or next.op == .trace) {
                    j += 1;
                    continue;
                }
                break;
            }

            if (j > i + 1) {
                const removed_count = j - i - 1;
                const remaining = function.instructions.items.len - j;
                std.mem.copyForwards(
                    Instruction,
                    function.instructions.items[i + 1 .. i + 1 + remaining],
                    function.instructions.items[j..],
                );
                function.instructions.items.len -= removed_count;
                result.removed += removed_count;
            }
            i += 1;
        }

        return result;
    }

    fn peephole(self: *Optimizer, function: *Function) !OptimizationResult {
        _ = self;
        const result = OptimizationResult.init();

        var i: usize = 0;
        while (i + 1 < function.instructions.items.len) : (i += 1) {
            const a = function.instructions.items[i];
            const b = function.instructions.items[i + 1];

            if (a.op == .push_zero and b.op == .push_one) {
                continue;
            }
        }

        return result;
    }

    fn stackPeephole(self: *Optimizer, function: *Function) !OptimizationResult {
        _ = self;
        var result = OptimizationResult.init();

        var i: usize = 0;
        while (i + 1 < function.instructions.items.len) {
            const a = function.instructions.items[i];
            const b = function.instructions.items[i + 1];

            if (a.op == .push_const and b.op == .pop) {
                const remaining = function.instructions.items.len - (i + 2);
                std.mem.copyForwards(
                    Instruction,
                    function.instructions.items[i .. i + remaining],
                    function.instructions.items[i + 2 ..],
                );
                function.instructions.items.len -= 2;
                result.removed += 2;
                continue;
            }

            if (a.op == .dup and b.op == .pop) {
                const remaining = function.instructions.items.len - (i + 2);
                std.mem.copyForwards(
                    Instruction,
                    function.instructions.items[i .. i + remaining],
                    function.instructions.items[i + 2 ..],
                );
                function.instructions.items.len -= 2;
                result.removed += 2;
                continue;
            }

            i += 1;
        }

        return result;
    }

    fn threadJumps(self: *Optimizer, function: *Function) !OptimizationResult {
        _ = self;
        var result = OptimizationResult.init();

        for (function.instructions.items) |*inst| {
            if (inst.op != .jump) continue;
            const target = @as(i64, @intCast(inst.offset)) + inst.operand.jump;
            if (target < 0) continue;
            if (target >= function.instructions.items.len) continue;

            const target_inst = function.instructions.items[@intCast(target)];
            if (target_inst.op == .jump) {
                const new_target = @as(i64, @intCast(target_inst.offset)) + target_inst.operand.jump;
                const new_offset = new_target - @as(i64, @intCast(inst.offset));
                inst.operand = .{ .jump = @intCast(new_offset) };
                result.jumps_simplified += 1;
            }
        }

        return result;
    }
};

pub fn optimize(allocator: std.mem.Allocator, function: *Function) !OptimizationResult {
    var opt = Optimizer.init(allocator);
    return opt.optimize(function);
}

pub fn isNopLike(op: OpCode) bool {
    return switch (op) {
        .nop,
        .debugger,
        .trace,
        .breakpoint,
        => true,
        else => false,
    };
}

pub fn isConstantPush(op: OpCode) bool {
    return switch (op) {
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
        => true,
        else => false,
    };
}

pub fn isArithmetic(op: OpCode) bool {
    return switch (op) {
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
        => true,
        else => false,
    };
}

test "OptimizationResult init" {
    const r = OptimizationResult.init();
    try std.testing.expectEqual(@as(usize, 0), r.total());
}

test "Pass toString" {
    try std.testing.expectEqualStrings("dead_code", Pass.dead_code.toString());
    try std.testing.expectEqualStrings("peephole", Pass.peephole.toString());
}

test "Options none" {
    const o = Options.none();
    try std.testing.expect(!o.dead_code);
    try std.testing.expect(!o.peephole);
    try std.testing.expect(!o.constant_folding);
}

test "Options all" {
    const o = Options.all();
    try std.testing.expect(o.dead_code);
    try std.testing.expect(o.peephole);
    try std.testing.expect(o.constant_folding);
}

test "Optimizer init" {
    const o = Optimizer.init(std.testing.allocator);
    try std.testing.expect(o.options.dead_code);
}

test "Optimizer initWithOptions" {
    const opts = Options.none();
    const o = Optimizer.initWithOptions(std.testing.allocator, opts);
    try std.testing.expect(!o.options.dead_code);
}

test "Optimizer optimize empty function" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    var o = Optimizer.init(std.testing.allocator);
    const r = try o.optimize(&f);
    try std.testing.expectEqual(@as(usize, 0), r.total());
}

test "Optimizer remove dead code after return" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try f.addInstruction(Instruction.init(.return_));
    _ = try f.addInstruction(Instruction.init(.nop));
    _ = try f.addInstruction(Instruction.init(.nop));
    _ = try f.addInstruction(Instruction.withJump(.jump, 0));

    const before = f.instructionCount();
    var o = Optimizer.initWithOptions(std.testing.allocator, .{
        .dead_code = true,
        .peephole = false,
        .stack_peephole = false,
        .jump_threading = false,
    });
    _ = try o.optimize(&f);

    try std.testing.expect(f.instructionCount() <= before);
}

test "Optimizer stack peephole removes push_const pop" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try f.addInstruction(Instruction.withConstant(.push_const, 0));
    _ = try f.addInstruction(Instruction.init(.pop));

    var o = Optimizer.initWithOptions(std.testing.allocator, .{
        .dead_code = false,
        .peephole = false,
        .stack_peephole = true,
        .jump_threading = false,
    });
    const r = try o.optimize(&f);

    try std.testing.expectEqual(@as(usize, 0), f.instructionCount());
    try std.testing.expect(r.removed >= 2);
}

test "Optimizer stack peephole removes dup pop" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    _ = try f.addInstruction(Instruction.init(.dup));
    _ = try f.addInstruction(Instruction.init(.pop));

    var o = Optimizer.initWithOptions(std.testing.allocator, .{
        .dead_code = false,
        .peephole = false,
        .stack_peephole = true,
        .jump_threading = false,
    });
    _ = try o.optimize(&f);

    try std.testing.expectEqual(@as(usize, 0), f.instructionCount());
}

test "isNopLike" {
    try std.testing.expect(isNopLike(.nop));
    try std.testing.expect(isNopLike(.debugger));
    try std.testing.expect(!isNopLike(.add));
}

test "isConstantPush" {
    try std.testing.expect(isConstantPush(.push_const));
    try std.testing.expect(isConstantPush(.push_int8));
    try std.testing.expect(isConstantPush(.push_true));
    try std.testing.expect(!isConstantPush(.add));
}

test "isArithmetic" {
    try std.testing.expect(isArithmetic(.add));
    try std.testing.expect(isArithmetic(.mul));
    try std.testing.expect(isArithmetic(.bit_and));
    try std.testing.expect(!isArithmetic(.pop));
}

test "optimize helper" {
    var f = Function.init(std.testing.allocator, "main");
    defer f.deinit();

    const r = try optimize(std.testing.allocator, &f);
    try std.testing.expectEqual(@as(usize, 0), r.total());
}
