const std = @import("std");
const ast = @import("../parser/ast.zig");
const parser_ast = @import("../parser/ast.zig");
const opcode_mod = @import("opcode.zig");
const bytecode = @import("bytecode.zig");
const emitter_mod = @import("emitter.zig");
const opt_mod = @import("optimizer.zig");
const scope_mod = @import("scope.zig");

pub const NodeId = parser_ast.NodeId;
pub const NO_NODE = parser_ast.NO_NODE;
pub const NodeTag = parser_ast.NodeTag;
pub const Ast = parser_ast.Ast;
pub const OpCode = opcode_mod.OpCode;
pub const Instruction = bytecode.Instruction;
pub const Function = bytecode.Function;
pub const Module = bytecode.Module;
pub const Emitter = emitter_mod.Emitter;
pub const OptimizationResult = opt_mod.OptimizationResult;

pub const CompileError = error{
    OutOfMemory,
    UnsupportedNode,
    UndefinedIdentifier,
    InvalidAssignment,
    TooManyLocals,
    TooManyConstants,
    TooManyUpvalues,
    InvalidJump,
    NoCurrentFunction,
    InvalidOperand,
    AlreadyDefined,
    UndefinedLocal,
};

pub const Options = struct {
    strict: bool = false,
    is_module: bool = false,
    optimize: bool = true,
    debug_info: bool = false,

    pub fn default() Options {
        return .{};
    }

    pub fn module() Options {
        return .{
            .strict = true,
            .is_module = true,
        };
    }
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    ast: *const Ast,
    module: *Module,
    current_function: *Function,
    current_emitter: *Emitter,
    scopes: *scope_mod.ScopeStack,
    options: Options,
    errors: std.ArrayList([]const u8),

    pub fn init(
        allocator: std.mem.Allocator,
        ast_ref: *const Ast,
        options: Options,
    ) !Compiler {
        const module = try bytecode.createModule(allocator);
        errdefer bytecode.destroyModule(module);

        const main_fn = try bytecode.createFunction(allocator, "main");
        errdefer {
            main_fn.deinit();
            allocator.destroy(main_fn);
        }

        _ = try module.addFunction(main_fn);

        const emitter = try allocator.create(Emitter);
        emitter.* = Emitter.init(allocator, main_fn);

        const scopes = try allocator.create(scope_mod.ScopeStack);
        scopes.* = scope_mod.ScopeStack.init(allocator);
        _ = try scopes.push(.global);

        return .{
            .allocator = allocator,
            .ast = ast_ref,
            .module = module,
            .current_function = main_fn,
            .current_emitter = emitter,
            .scopes = scopes,
            .options = options,
            .errors = .empty,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.current_emitter.deinit();
        self.allocator.destroy(self.current_emitter);
        self.scopes.deinit();
        self.allocator.destroy(self.scopes);
        self.errors.deinit(self.allocator);
    }

    pub fn takeModule(self: *Compiler) *Module {
        return self.module;
    }

    pub fn compile(self: *Compiler, program_id: NodeId) CompileError!void {
        const program_node = self.ast.get(program_id);
        if (program_node.tag != .program) {
            return CompileError.UnsupportedNode;
        }

        for (program_node.data.program.body) |stmt_id| {
            if (stmt_id == NO_NODE) continue;
            try self.compileStatement(stmt_id);
        }

        _ = try self.current_emitter.emitReturnUndefined();

        if (self.options.optimize) {
            var opt = opt_mod.Optimizer.init(self.allocator);
            _ = try opt.optimize(self.current_function);
        }
    }

    fn compileStatement(self: *Compiler, node_id: NodeId) CompileError!void {
        const node = self.ast.get(node_id);
        return switch (node.tag) {
            .empty_statement => {},
            .expression_statement => self.compileExpressionStatement(node),
            .block_statement => self.compileBlock(node),
            .variable_declaration => self.compileVariableDeclaration(node),
            .if_statement => self.compileIf(node),
            .return_statement => self.compileReturn(node),
            .break_statement => self.compileBreak(),
            .continue_statement => self.compileContinue(),
            .function_declaration => self.compileFunctionDeclaration(node, node_id),
            else => CompileError.UnsupportedNode,
        };
    }

    fn compileExpressionStatement(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const e = node.data.expression_statement.expression;
        if (e == NO_NODE) return;
        try self.compileExpression(e);
        _ = try self.current_emitter.emit(.pop);
    }

    fn compileBlock(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const body = node.data.block_statement.body;
        for (body) |stmt_id| {
            if (stmt_id == NO_NODE) continue;
            try self.compileStatement(stmt_id);
        }
    }

    fn compileVariableDeclaration(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const decl = node.data.variable_declaration;

        for (decl.declarations) |decl_id| {
            if (decl_id == NO_NODE) continue;
            const decl_node = self.ast.get(decl_id);
            const id_node = self.ast.get(decl_node.data.variable_declarator.id);
            const name = id_node.data.identifier.name;

            if (decl_node.data.variable_declarator.init != NO_NODE) {
                try self.compileExpression(decl_node.data.variable_declarator.init);
            } else {
                _ = try self.current_emitter.pushUndefined();
            }

            const kind: scope_mod.BindingKind = switch (decl.kind) {
                .var_ => .var_,
                .let_ => .let_,
                .const_ => .const_,
            };

            if (self.scopes.resolve(name)) |existing| {
                if (decl.kind == .var_) {
                    _ = try self.current_emitter.emitStoreLocal(existing.register);
                } else {
                    return CompileError.AlreadyDefined;
                }
            } else {
                const reg = try self.current_emitter.defineLocal(name, @intCast(self.scopes.depth()));
                _ = try self.current_emitter.emitStoreLocal(reg);
                if (self.scopes.ownScope()) |scope| {
                    _ = try scope.addLocal(name, kind, reg);
                }
            }
        }
    }

    fn compileIf(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const if_data = node.data.if_statement;

        try self.compileExpression(if_data.test_expr);

        const else_jump = try self.current_emitter.emitJump(.jump_if_false);

        try self.compileStatement(if_data.consequent);

        var end_jump: ?usize = null;
        if (if_data.alternate != NO_NODE) {
            end_jump = try self.current_emitter.emitJump(.jump);
        }

        try self.current_emitter.patchJump(else_jump);

        if (if_data.alternate != NO_NODE) {
            try self.compileStatement(if_data.alternate);
            if (end_jump) |ej| {
                try self.current_emitter.patchJump(ej);
            }
        }
    }

    fn compileReturn(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const arg = node.data.return_statement.argument;
        if (arg != NO_NODE) {
            try self.compileExpression(arg);
            _ = try self.current_emitter.emitReturn();
        } else {
            _ = try self.current_emitter.emitReturnUndefined();
        }
    }

    fn compileBreak(self: *Compiler) CompileError!void {
        try self.current_emitter.emitBreak();
    }

    fn compileContinue(self: *Compiler) CompileError!void {
        try self.current_emitter.emitContinue();
    }

    fn compileFunctionDeclaration(
        self: *Compiler,
        node: *const parser_ast.Node,
        node_id: NodeId,
    ) CompileError!void {
        _ = self;
        _ = node;
        _ = node_id;
    }

    pub fn compileExpression(self: *Compiler, node_id: NodeId) CompileError!void {
        if (node_id == NO_NODE) {
            _ = try self.current_emitter.pushUndefined();
            return;
        }

        const node = self.ast.get(node_id);
        return switch (node.tag) {
            .number_literal => self.compileNumber(node),
            .string_literal => self.compileString(node),
            .boolean_literal => self.compileBoolean(node),
            .null_literal => self.compileNull(),
            .bigint_literal => self.compileBigInt(node),
            .identifier => self.compileIdentifier(node),
            .this_expression => self.compileThis(),
            .binary_expression => self.compileBinary(node),
            .logical_expression => self.compileLogical(node),
            .unary_expression => self.compileUnary(node),
            .update_expression => self.compileUpdate(node),
            .assignment_expression => self.compileAssignment(node),
            .conditional_expression => self.compileConditional(node),
            .call_expression => self.compileCall(node),
            .member_expression => self.compileMember(node),
            else => CompileError.UnsupportedNode,
        };
    }

    fn compileNumber(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const raw = node.data.number_literal.raw;
        const value = std.fmt.parseFloat(f64, raw) catch 0.0;
        _ = try self.current_emitter.pushNumber(value);
    }

    fn compileString(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const raw = node.data.string_literal.raw;
        const inner = stripQuotes(raw);
        _ = try self.current_emitter.pushString(inner);
    }

    fn compileBoolean(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        _ = try self.current_emitter.pushBoolean(node.data.boolean_literal.value);
    }

    fn compileNull(self: *Compiler) CompileError!void {
        _ = try self.current_emitter.pushNull();
    }

    fn compileBigInt(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const raw = node.data.bigint_literal.raw;
        const inner = if (raw.len > 0 and raw[raw.len - 1] == 'n') raw[0 .. raw.len - 1] else raw;
        const idx = try self.current_emitter.addStringConstant(inner);
        _ = try self.current_emitter.emitConstant(.push_bigint, idx);
    }

    fn compileIdentifier(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const name = node.data.identifier.name;
        const scope = self.scopes.ownScope() orelse return CompileError.UndefinedIdentifier;

        if (scope.find(name)) |b| {
            _ = try self.current_emitter.emitLoadLocal(b.register);
            return;
        }

        const idx = try self.current_emitter.addStringConstant(name);
        _ = try self.current_emitter.emitLoadGlobal(idx);
    }

    fn compileThis(self: *Compiler) CompileError!void {
        _ = try self.current_emitter.emit(.load_this);
    }

    fn compileBinary(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const bin = node.data.binary_expression;
        try self.compileExpression(bin.left);
        try self.compileExpression(bin.right);

        const op: OpCode = switch (bin.operator) {
            .add => .add,
            .sub => .sub,
            .mul => .mul,
            .div => .div,
            .mod => .mod,
            .exp => .exp,
            .eq => .eq,
            .neq => .neq,
            .strict_eq => .strict_eq,
            .strict_neq => .strict_neq,
            .lt => .lt,
            .gt => .gt,
            .lte => .lte,
            .gte => .gte,
            .bit_and => .bit_and,
            .bit_or => .bit_or,
            .bit_xor => .bit_xor,
            .shl => .shl,
            .shr => .shr,
            .ushr => .ushr,
            .in => .in,
            .instanceof => .instanceof,
        };
        _ = try self.current_emitter.emit(op);
    }

    fn compileLogical(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const log = node.data.logical_expression;
        try self.compileExpression(log.left);

        const jump_op: OpCode = switch (log.operator) {
            .and_ => .jump_if_false,
            .or_ => .jump_if_true,
            .nullish => .jump_if_not_null,
        };
        const jump_idx = try self.current_emitter.emitJump(jump_op);

        _ = try self.current_emitter.emit(.pop);
        try self.compileExpression(log.right);

        try self.current_emitter.patchJump(jump_idx);
    }

    fn compileUnary(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const un = node.data.unary_expression;
        try self.compileExpression(un.operand);

        const op: OpCode = switch (un.operator) {
            .neg => .neg,
            .pos => .pos,
            .not => .not,
            .bit_not => .bit_not,
            .typeof => .typeof_,
            .void_ => .void_,
            .delete => .delete_,
        };
        _ = try self.current_emitter.emit(op);
    }

    fn compileUpdate(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const up = node.data.update_expression;
        try self.compileExpression(up.operand);

        const op: OpCode = switch (up.operator) {
            .increment, .prefix_increment => .inc,
            .decrement, .prefix_decrement => .dec,
        };
        _ = try self.current_emitter.emit(op);
    }

    fn compileAssignment(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const assign = node.data.assignment_expression;
        try self.compileExpression(assign.right);

        const left_node = self.ast.get(assign.left);
        if (left_node.tag == .identifier) {
            const name = left_node.data.identifier.name;
            if (self.scopes.resolve(name)) |b| {
                _ = try self.current_emitter.emitStoreLocal(b.register);
            } else {
                const idx = try self.current_emitter.addStringConstant(name);
                _ = try self.current_emitter.emitStoreGlobal(idx);
            }
            return;
        }
        return CompileError.InvalidAssignment;
    }

    fn compileConditional(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const cond = node.data.conditional_expression;
        try self.compileExpression(cond.test_expr);

        const else_jump = try self.current_emitter.emitJump(.jump_if_false);
        try self.compileExpression(cond.consequent);

        const end_jump = try self.current_emitter.emitJump(.jump);
        try self.current_emitter.patchJump(else_jump);

        try self.compileExpression(cond.alternate);
        try self.current_emitter.patchJump(end_jump);
    }

    fn compileCall(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const call = node.data.call_expression;
        try self.compileExpression(call.callee);

        for (call.arguments) |arg_id| {
            try self.compileExpression(arg_id);
        }

        const argc: u8 = @intCast(call.arguments.len);
        _ = try self.current_emitter.emitCall(argc);
    }

    fn compileMember(self: *Compiler, node: *const parser_ast.Node) CompileError!void {
        const mem = node.data.member_expression;
        try self.compileExpression(mem.object);

        if (mem.computed) {
            try self.compileExpression(mem.property);
            _ = try self.current_emitter.emit(.get_element);
            return;
        }

        const prop_node = self.ast.get(mem.property);
        const name = prop_node.data.identifier.name;
        const name_idx = try self.current_emitter.addStringConstant(name);
        _ = try self.current_emitter.emitGetProperty(name_idx);
    }
};

fn stripQuotes(raw: []const u8) []const u8 {
    if (raw.len < 2) return raw;
    const first = raw[0];
    const last = raw[raw.len - 1];
    if ((first == '"' and last == '"') or (first == '\'' and last == '\'')) {
        return raw[1 .. raw.len - 1];
    }
    return raw;
}

pub fn compileProgram(
    allocator: std.mem.Allocator,
    ast_ref: *const Ast,
    program_id: NodeId,
) !*Module {
    var c = try Compiler.init(allocator, ast_ref, Options.default());
    defer c.deinit();

    try c.compile(program_id);

    return c.takeModule();
}

pub fn compileProgramWithOptions(
    allocator: std.mem.Allocator,
    ast_ref: *const Ast,
    program_id: NodeId,
    options: Options,
) !*Module {
    var c = try Compiler.init(allocator, ast_ref, options);
    defer c.deinit();

    try c.compile(program_id);

    return c.takeModule();
}

test "Options default" {
    const o = Options.default();
    try std.testing.expect(!o.strict);
    try std.testing.expect(!o.is_module);
}

test "Options module" {
    const o = Options.module();
    try std.testing.expect(o.strict);
    try std.testing.expect(o.is_module);
}

test "Compiler init" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try std.testing.expectEqual(@as(usize, 1), c.module.functionCount());
}

test "Compiler compile empty program" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const body = try std.testing.allocator.alloc(NodeId, 0);
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile number literal" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const num = try a.add(.number_literal, ast.nullSpan(), .{
        .number_literal = .{ .raw = "42", .value = 42.0 },
    });
    const expr_stmt = try a.add(.expression_statement, ast.nullSpan(), .{
        .expression_statement = .{ .expression = num, .directive = null },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = expr_stmt;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile boolean" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const b = try a.add(.boolean_literal, ast.nullSpan(), .{
        .boolean_literal = .{ .value = true },
    });
    const es = try a.add(.expression_statement, ast.nullSpan(), .{
        .expression_statement = .{ .expression = b, .directive = null },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = es;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile null" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const n = try a.add(.null_literal, ast.nullSpan(), .{ .null_literal = {} });
    const es = try a.add(.expression_statement, ast.nullSpan(), .{
        .expression_statement = .{ .expression = n, .directive = null },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = es;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
}

test "Compiler compile binary expression" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const l = try a.add(.number_literal, ast.nullSpan(), .{
        .number_literal = .{ .raw = "1", .value = 1.0 },
    });
    const r = try a.add(.number_literal, ast.nullSpan(), .{
        .number_literal = .{ .raw = "2", .value = 2.0 },
    });
    const bin = try a.add(.binary_expression, ast.nullSpan(), .{
        .binary_expression = .{ .left = l, .right = r, .operator = .add },
    });
    const es = try a.add(.expression_statement, ast.nullSpan(), .{
        .expression_statement = .{ .expression = bin, .directive = null },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = es;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile variable declaration" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const id = try a.add(.identifier, ast.nullSpan(), .{
        .identifier = .{ .name = "x" },
    });
    const num = try a.add(.number_literal, ast.nullSpan(), .{
        .number_literal = .{ .raw = "42", .value = 42.0 },
    });
    const decl = try a.add(.variable_declarator, ast.nullSpan(), .{
        .variable_declarator = .{ .id = id, .init = num },
    });
    const decls = try std.testing.allocator.alloc(NodeId, 1);
    decls[0] = decl;
    const vd = try a.add(.variable_declaration, ast.nullSpan(), .{
        .variable_declaration = .{ .kind = .var_, .declarations = decls },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = vd;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile if statement" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const cond = try a.add(.boolean_literal, ast.nullSpan(), .{
        .boolean_literal = .{ .value = true },
    });
    const empty1 = try a.add(.empty_statement, ast.nullSpan(), .{ .empty_statement = {} });
    const empty2 = try a.add(.empty_statement, ast.nullSpan(), .{ .empty_statement = {} });
    const if_stmt = try a.add(.if_statement, ast.nullSpan(), .{
        .if_statement = .{ .test_expr = cond, .consequent = empty1, .alternate = empty2 },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = if_stmt;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
    try std.testing.expect(c.current_function.instructionCount() >= 1);
}

test "Compiler compile return statement" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const num = try a.add(.number_literal, ast.nullSpan(), .{
        .number_literal = .{ .raw = "42", .value = 42.0 },
    });
    const ret = try a.add(.return_statement, ast.nullSpan(), .{
        .return_statement = .{ .argument = num },
    });
    const body = try std.testing.allocator.alloc(NodeId, 1);
    body[0] = ret;
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    var c = try Compiler.init(std.testing.allocator, &a, Options.default());
    defer c.deinit();
    defer bytecode.destroyModule(c.module);

    try c.compile(prog);
}

test "stripQuotes" {
    try std.testing.expectEqualStrings("hello", stripQuotes("\"hello\""));
    try std.testing.expectEqualStrings("hello", stripQuotes("'hello'"));
    try std.testing.expectEqualStrings("hello", stripQuotes("hello"));
    try std.testing.expectEqualStrings("", stripQuotes("\"\""));
}

test "compileProgram helper" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const body = try std.testing.allocator.alloc(NodeId, 0);
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    const m = try compileProgram(std.testing.allocator, &a, prog);
    defer bytecode.destroyModule(m);

    try std.testing.expectEqual(@as(usize, 1), m.functionCount());
}

test "compileProgramWithOptions helper" {
    var a = ast.Ast.init(std.testing.allocator);
    defer a.deinit();

    const body = try std.testing.allocator.alloc(NodeId, 0);
    const prog = try a.add(.program, ast.nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });

    const m = try compileProgramWithOptions(
        std.testing.allocator,
        &a,
        prog,
        Options.module(),
    );
    defer bytecode.destroyModule(m);

    try std.testing.expectEqual(@as(usize, 1), m.functionCount());
}
