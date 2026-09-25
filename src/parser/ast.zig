const std = @import("std");

pub const NodeId = u32;
pub const NO_NODE: NodeId = 0xFFFFFFFF;

pub const Position = struct {
    offset: u32,
    line: u32,
    column: u32,
};

pub const Span = struct {
    start: Position,
    end: Position,
};

pub const NodeTag = enum(u8) {
    program,
    identifier,
    private_identifier,

    number_literal,
    string_literal,
    boolean_literal,
    null_literal,
    regex_literal,
    bigint_literal,
    template_literal,

    array_literal,
    object_literal,
    property,
    spread_element,

    function_declaration,
    function_expression,
    arrow_function,
    parameter,

    class_declaration,
    class_expression,
    class_body,
    method_definition,
    property_definition,
    static_block,

    call_expression,
    new_expression,
    member_expression,
    optional_member_expression,
    optional_call_expression,
    tagged_template,

    binary_expression,
    logical_expression,
    unary_expression,
    update_expression,
    assignment_expression,
    conditional_expression,
    sequence_expression,
    yield_expression,
    await_expression,
    chain_expression,

    this_expression,
    super_expression,
    meta_property,
    import_expression,

    block_statement,
    empty_statement,
    expression_statement,
    if_statement,
    while_statement,
    do_while_statement,
    for_statement,
    for_in_statement,
    for_of_statement,
    return_statement,
    break_statement,
    continue_statement,
    switch_statement,
    switch_case,
    try_statement,
    catch_clause,
    throw_statement,
    labeled_statement,
    with_statement,
    debugger_statement,

    variable_declaration,
    variable_declarator,
    import_declaration,
    import_specifier,
    export_named_declaration,
    export_default_declaration,
    export_all_declaration,
    export_specifier,

    module_specifier,
};

pub const BinaryOperator = enum(u8) {
    add,
    sub,
    mul,
    div,
    mod,
    exp,
    eq,
    neq,
    strict_eq,
    strict_neq,
    lt,
    gt,
    lte,
    gte,
    bit_and,
    bit_or,
    bit_xor,
    shl,
    shr,
    ushr,
    in,
    instanceof,
};

pub const LogicalOperator = enum(u8) {
    and_,
    or_,
    nullish,
};

pub const UnaryOperator = enum(u8) {
    neg,
    pos,
    not,
    bit_not,
    typeof,
    void_,
    delete,
};

pub const UpdateOperator = enum(u8) {
    increment,
    decrement,
    prefix_increment,
    prefix_decrement,
};

pub const AssignmentOperator = enum(u8) {
    assign,
    add_assign,
    sub_assign,
    mul_assign,
    div_assign,
    mod_assign,
    exp_assign,
    and_assign,
    or_assign,
    xor_assign,
    shl_assign,
    shr_assign,
    ushr_assign,
    logical_and_assign,
    logical_or_assign,
    logical_nullish_assign,
};

pub const FunctionKind = enum(u8) {
    normal,
    generator,
    async,
    async_generator,
    arrow,
    method,
    getter,
    setter,
    constructor,
};

pub const VariableKind = enum(u8) {
    var_,
    let_,
    const_,
};

pub const Program = struct {
    body: []NodeId,
    strict: bool,
    source_type: SourceType,
};

pub const SourceType = enum(u8) {
    script,
    module,
};

pub const Identifier = struct {
    name: []const u8,
};

pub const NumberLiteral = struct {
    raw: []const u8,
    value: f64,
};

pub const StringLiteral = struct {
    raw: []const u8,
    value: []const u8,
};

pub const BooleanLiteral = struct {
    value: bool,
};

pub const RegexLiteral = struct {
    pattern: []const u8,
    flags: []const u8,
};

pub const BigIntLiteral = struct {
    raw: []const u8,
};

pub const TemplateElement = struct {
    raw: []const u8,
    cooked: []const u8,
};

pub const TemplateLiteral = struct {
    quasis: []NodeId,
    expressions: []NodeId,
};

pub const ArrayLiteral = struct {
    elements: []NodeId,
};

pub const PropertyKind = enum(u8) {
    init,
    get,
    set,
    method,
    spread,
};

pub const Property = struct {
    key: NodeId,
    value: NodeId,
    kind: PropertyKind,
    computed: bool,
    shorthand: bool,
};

pub const ObjectLiteral = struct {
    properties: []NodeId,
};

pub const Parameter = struct {
    pattern: NodeId,
    default_value: NodeId,
    rest: bool,
};

pub const FunctionNode = struct {
    id: NodeId,
    params: []NodeId,
    body: NodeId,
    kind: FunctionKind,
    strict: bool,
    generator: bool,
    async_: bool,
    expression: bool,
};

pub const ClassNode = struct {
    id: NodeId,
    super_class: NodeId,
    body: NodeId,
};

pub const ClassBody = struct {
    elements: []NodeId,
};

pub const MethodDefinition = struct {
    key: NodeId,
    value: NodeId,
    kind: FunctionKind,
    computed: bool,
    static_: bool,
};

pub const PropertyDefinition = struct {
    key: NodeId,
    value: NodeId,
    computed: bool,
    static_: bool,
};

pub const CallExpression = struct {
    callee: NodeId,
    arguments: []NodeId,
    optional: bool,
};

pub const NewExpression = struct {
    callee: NodeId,
    arguments: []NodeId,
};

pub const MemberExpression = struct {
    object: NodeId,
    property: NodeId,
    computed: bool,
    optional: bool,
};

pub const TaggedTemplate = struct {
    tag: NodeId,
    quasi: NodeId,
};

pub const BinaryExpression = struct {
    left: NodeId,
    right: NodeId,
    operator: BinaryOperator,
};

pub const LogicalExpression = struct {
    left: NodeId,
    right: NodeId,
    operator: LogicalOperator,
};

pub const UnaryExpression = struct {
    operand: NodeId,
    operator: UnaryOperator,
};

pub const UpdateExpression = struct {
    operand: NodeId,
    operator: UpdateOperator,
};

pub const AssignmentExpression = struct {
    left: NodeId,
    right: NodeId,
    operator: AssignmentOperator,
};

pub const ConditionalExpression = struct {
    test_expr: NodeId,
    consequent: NodeId,
    alternate: NodeId,
};

pub const SequenceExpression = struct {
    expressions: []NodeId,
};

pub const YieldExpression = struct {
    argument: NodeId,
    delegate: bool,
};

pub const AwaitExpression = struct {
    argument: NodeId,
};

pub const ChainExpression = struct {
    expression: NodeId,
};

pub const MetaProperty = struct {
    meta: NodeId,
    property: NodeId,
};

pub const ImportExpression = struct {
    source: NodeId,
    options: NodeId,
};

pub const BlockStatement = struct {
    body: []NodeId,
};

pub const ExpressionStatement = struct {
    expression: NodeId,
    directive: ?[]const u8,
};

pub const IfStatement = struct {
    test_expr: NodeId,
    consequent: NodeId,
    alternate: NodeId,
};

pub const WhileStatement = struct {
    test_expr: NodeId,
    body: NodeId,
};

pub const DoWhileStatement = struct {
    body: NodeId,
    test_expr: NodeId,
};

pub const ForStatement = struct {
    init: NodeId,
    test_expr: NodeId,
    update: NodeId,
    body: NodeId,
};

pub const ForInStatement = struct {
    left: NodeId,
    right: NodeId,
    body: NodeId,
};

pub const ForOfStatement = struct {
    left: NodeId,
    right: NodeId,
    body: NodeId,
    await_: bool,
};

pub const ReturnStatement = struct {
    argument: NodeId,
};

pub const BreakStatement = struct {
    label: NodeId,
};

pub const ContinueStatement = struct {
    label: NodeId,
};

pub const SwitchStatement = struct {
    discriminant: NodeId,
    cases: []NodeId,
};

pub const SwitchCase = struct {
    test_expr: NodeId,
    consequent: []NodeId,
};

pub const TryStatement = struct {
    block: NodeId,
    handler: NodeId,
    finalizer: NodeId,
};

pub const CatchClause = struct {
    param: NodeId,
    body: NodeId,
};

pub const ThrowStatement = struct {
    argument: NodeId,
};

pub const LabeledStatement = struct {
    label: NodeId,
    body: NodeId,
};

pub const WithStatement = struct {
    object: NodeId,
    body: NodeId,
};

pub const VariableDeclaration = struct {
    kind: VariableKind,
    declarations: []NodeId,
};

pub const VariableDeclarator = struct {
    id: NodeId,
    init: NodeId,
};

pub const ImportDeclaration = struct {
    specifiers: []NodeId,
    source: NodeId,
};

pub const ImportSpecifier = struct {
    imported: NodeId,
    local: NodeId,
    is_default: bool,
    is_namespace: bool,
};

pub const ExportNamedDeclaration = struct {
    declaration: NodeId,
    specifiers: []NodeId,
    source: NodeId,
};

pub const ExportDefaultDeclaration = struct {
    declaration: NodeId,
};

pub const ExportAllDeclaration = struct {
    source: NodeId,
    exported: NodeId,
};

pub const ExportSpecifier = struct {
    local: NodeId,
    exported: NodeId,
};

pub const ModuleSpecifier = struct {
    value: []const u8,
};

pub const Data = union(enum) {
    program: Program,
    identifier: Identifier,
    private_identifier: Identifier,
    number_literal: NumberLiteral,
    string_literal: StringLiteral,
    boolean_literal: BooleanLiteral,
    null_literal: void,
    regex_literal: RegexLiteral,
    bigint_literal: BigIntLiteral,
    template_literal: TemplateLiteral,
    array_literal: ArrayLiteral,
    object_literal: ObjectLiteral,
    property: Property,
    spread_element: NodeId,
    function: FunctionNode,
    parameter: Parameter,
    class: ClassNode,
    class_body: ClassBody,
    method_definition: MethodDefinition,
    property_definition: PropertyDefinition,
    static_block: BlockStatement,
    call_expression: CallExpression,
    new_expression: NewExpression,
    member_expression: MemberExpression,
    tagged_template: TaggedTemplate,
    binary_expression: BinaryExpression,
    logical_expression: LogicalExpression,
    unary_expression: UnaryExpression,
    update_expression: UpdateExpression,
    assignment_expression: AssignmentExpression,
    conditional_expression: ConditionalExpression,
    sequence_expression: SequenceExpression,
    yield_expression: YieldExpression,
    await_expression: AwaitExpression,
    chain_expression: ChainExpression,
    this_expression: void,
    super_expression: void,
    meta_property: MetaProperty,
    import_expression: ImportExpression,
    block_statement: BlockStatement,
    empty_statement: void,
    expression_statement: ExpressionStatement,
    if_statement: IfStatement,
    while_statement: WhileStatement,
    do_while_statement: DoWhileStatement,
    for_statement: ForStatement,
    for_in_statement: ForInStatement,
    for_of_statement: ForOfStatement,
    return_statement: ReturnStatement,
    break_statement: BreakStatement,
    continue_statement: ContinueStatement,
    switch_statement: SwitchStatement,
    switch_case: SwitchCase,
    try_statement: TryStatement,
    catch_clause: CatchClause,
    throw_statement: ThrowStatement,
    labeled_statement: LabeledStatement,
    with_statement: WithStatement,
    debugger_statement: void,
    variable_declaration: VariableDeclaration,
    variable_declarator: VariableDeclarator,
    import_declaration: ImportDeclaration,
    import_specifier: ImportSpecifier,
    export_named_declaration: ExportNamedDeclaration,
    export_default_declaration: ExportDefaultDeclaration,
    export_all_declaration: ExportAllDeclaration,
    export_specifier: ExportSpecifier,
    module_specifier: ModuleSpecifier,
};

pub const Node = struct {
    tag: NodeTag,
    span: Span,
    data: Data,
};

pub const Ast = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator) Ast {
        return .{
            .allocator = allocator,
            .nodes = .empty,
        };
    }

    pub fn deinit(self: *Ast) void {
        for (self.nodes.items) |*node| {
            freeData(self.allocator, &node.data);
        }
        self.nodes.deinit(self.allocator);
    }

    pub fn reserve(self: *Ast) !NodeId {
        const id: NodeId = @intCast(self.nodes.items.len);
        try self.nodes.append(self.allocator, undefined);
        return id;
    }

    pub fn add(self: *Ast, tag: NodeTag, span: Span, data: Data) !NodeId {
        const id: NodeId = @intCast(self.nodes.items.len);
        try self.nodes.append(self.allocator, .{
            .tag = tag,
            .span = span,
            .data = data,
        });
        return id;
    }

    pub fn get(self: Ast, id: NodeId) *const Node {
        return &self.nodes.items[id];
    }

    pub fn getMut(self: *Ast, id: NodeId) *Node {
        return &self.nodes.items[id];
    }

    pub fn count(self: Ast) usize {
        return self.nodes.items.len;
    }

    pub fn set(self: *Ast, id: NodeId, node: Node) void {
        self.nodes.items[id] = node;
    }

    pub fn isNull(id: NodeId) bool {
        return id == NO_NODE;
    }

    pub fn tagOf(self: Ast, id: NodeId) NodeTag {
        return self.nodes.items[id].tag;
    }
};

fn freeData(allocator: std.mem.Allocator, data: *Data) void {
    switch (data.*) {
        .program => |p| allocator.free(p.body),
        .template_literal => |t| {
            allocator.free(t.quasis);
            allocator.free(t.expressions);
        },
        .array_literal => |a| allocator.free(a.elements),
        .object_literal => |o| allocator.free(o.properties),
        .function => |f| {
            allocator.free(f.params);
        },
        .class_body => |c| allocator.free(c.elements),
        .call_expression => |c| allocator.free(c.arguments),
        .new_expression => |n| allocator.free(n.arguments),
        .sequence_expression => |s| allocator.free(s.expressions),
        .block_statement => |b| allocator.free(b.body),
        .switch_statement => |s| allocator.free(s.cases),
        .switch_case => |c| allocator.free(c.consequent),
        .variable_declaration => |v| allocator.free(v.declarations),
        .import_declaration => |i| allocator.free(i.specifiers),
        .export_named_declaration => |e| {
            allocator.free(e.specifiers);
        },
        else => {},
    }
}

pub fn nullSpan() Span {
    const p = Position{ .offset = 0, .line = 0, .column = 0 };
    return .{ .start = p, .end = p };
}

test "Ast init" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();
    try std.testing.expectEqual(@as(usize, 0), ast.count());
}

test "Ast add identifier" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const id = try ast.add(.identifier, nullSpan(), .{ .identifier = .{ .name = "x" } });
    try std.testing.expectEqual(@as(usize, 1), ast.count());
    try std.testing.expectEqual(NodeTag.identifier, ast.tagOf(id));
}

test "Ast get returns node" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const id = try ast.add(.null_literal, nullSpan(), .{ .null_literal = {} });
    const node = ast.get(id);
    try std.testing.expectEqual(NodeTag.null_literal, node.tag);
}

test "Ast getMut allows modification" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const id = try ast.add(.identifier, nullSpan(), .{ .identifier = .{ .name = "old" } });
    const node = ast.getMut(id);
    node.data.identifier.name = "new";
    try std.testing.expectEqualStrings("new", ast.get(id).data.identifier.name);
}

test "isNull" {
    try std.testing.expect(Ast.isNull(NO_NODE));
    try std.testing.expect(!Ast.isNull(0));
}

test "nullSpan is zero" {
    const s = nullSpan();
    try std.testing.expectEqual(@as(u32, 0), s.start.offset);
    try std.testing.expectEqual(@as(u32, 0), s.end.offset);
}

test "Ast add program frees body" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const body = try std.testing.allocator.alloc(NodeId, 0);
    _ = try ast.add(.program, nullSpan(), .{
        .program = .{ .body = body, .strict = false, .source_type = .script },
    });
}

test "Ast add binary expression" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const left = try ast.add(.number_literal, nullSpan(), .{
        .number_literal = .{ .raw = "1", .value = 1.0 },
    });
    const right = try ast.add(.number_literal, nullSpan(), .{
        .number_literal = .{ .raw = "2", .value = 2.0 },
    });
    const id = try ast.add(.binary_expression, nullSpan(), .{
        .binary_expression = .{
            .left = left,
            .right = right,
            .operator = .add,
        },
    });
    try std.testing.expectEqual(NodeTag.binary_expression, ast.tagOf(id));
}

test "Ast add block statement" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const body = try std.testing.allocator.alloc(NodeId, 2);
    body[0] = NO_NODE;
    body[1] = NO_NODE;

    const id = try ast.add(.block_statement, nullSpan(), .{
        .block_statement = .{ .body = body },
    });
    try std.testing.expectEqual(@as(usize, 2), ast.get(id).data.block_statement.body.len);
}

test "Ast set replaces node" {
    var ast = Ast.init(std.testing.allocator);
    defer ast.deinit();

    const id = try ast.add(.identifier, nullSpan(), .{ .identifier = .{ .name = "x" } });
    ast.set(id, .{
        .tag = .null_literal,
        .span = nullSpan(),
        .data = .{ .null_literal = {} },
    });
    try std.testing.expectEqual(NodeTag.null_literal, ast.tagOf(id));
}

test "FunctionKind enum" {
    try std.testing.expectEqual(@as(usize, 9), @typeInfo(FunctionKind).@"enum".fields.len);
}

test "VariableKind enum" {
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(VariableKind).@"enum".fields.len);
}

test "BinaryOperator enum" {
    try std.testing.expectEqual(@as(usize, 22), @typeInfo(BinaryOperator).@"enum".fields.len);
}

test "LogicalOperator enum" {
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(LogicalOperator).@"enum".fields.len);
}

test "UnaryOperator enum" {
    try std.testing.expectEqual(@as(usize, 7), @typeInfo(UnaryOperator).@"enum".fields.len);
}

test "AssignmentOperator enum" {
    try std.testing.expectEqual(@as(usize, 16), @typeInfo(AssignmentOperator).@"enum".fields.len);
}
