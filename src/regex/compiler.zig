const std = @import("std");
const parser = @import("parser.zig");

pub const CompileError = error{
    OutOfMemory,
    ProgramTooLarge,
    TooManyInstructions,
    InvalidBackreference,
    InvalidRange,
};

pub const Op = enum(u8) {
    char,
    any,
    any_dotall,
    class,
    start_anchor,
    end_anchor,
    word_boundary,
    not_word_boundary,
    split,
    jump,
    save_start,
    save_end,
    match,
    backreference,
    assert_start,
    assert_end,
};

pub const Inst = struct {
    op: Op,
    x: usize = 0,
    y: usize = 0,
};

pub const Program = struct {
    insts: []Inst,
    classes: []Class,
    group_count: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Program) void {
        for (self.classes) |c| {
            self.allocator.free(c.items);
        }
        self.allocator.free(self.classes);
        self.allocator.free(self.insts);
    }
};

pub const Class = struct {
    negated: bool,
    items: []ClassItem,
};

pub const ClassItem = union(enum) {
    char: u21,
    range_start: u21,
    range_end: u21,
    digit: void,
    not_digit: void,
    word: void,
    not_word: void,
    space: void,
    not_space: void,
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    insts: std.ArrayList(Inst),
    classes: std.ArrayList(Class),
    group_count: u32,

    pub fn init(allocator: std.mem.Allocator, group_count: u32) Compiler {
        return .{
            .allocator = allocator,
            .insts = .empty,
            .classes = .empty,
            .group_count = group_count,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.insts.deinit(self.allocator);
        self.classes.deinit(self.allocator);
    }

    pub fn compile(self: *Compiler, root: *parser.Node) CompileError!Program {
        try self.emit(.{ .op = .save_start, .x = 0 });
        try self.compileNode(root);
        try self.emit(.{ .op = .save_end, .x = 1 });
        try self.emit(.{ .op = .match });

        return .{
            .insts = try self.insts.toOwnedSlice(self.allocator),
            .classes = try self.classes.toOwnedSlice(self.allocator),
            .group_count = self.group_count,
            .allocator = self.allocator,
        };
    }

    fn emit(self: *Compiler, inst: Inst) CompileError!void {
        try self.insts.append(self.allocator, inst);
    }

    fn patch(self: *Compiler, index: usize, x: usize, y: usize) void {
        self.insts.items[index].x = x;
        self.insts.items[index].y = y;
    }

    fn currentIndex(self: *Compiler) usize {
        return self.insts.items.len;
    }

    fn compileNode(self: *Compiler, node: *parser.Node) CompileError!void {
        switch (node.*) {
            .empty => {},
            .char => |cp| try self.emit(.{ .op = .char, .x = cp }),
            .any => try self.emit(.{ .op = .any }),
            .any_dotall => try self.emit(.{ .op = .any_dotall }),
            .class => |c| {
                const index = try self.addClass(c);
                try self.emit(.{ .op = .class, .x = index });
            },
            .start_anchor => try self.emit(.{ .op = .start_anchor }),
            .end_anchor => try self.emit(.{ .op = .end_anchor }),
            .word_boundary => try self.emit(.{ .op = .word_boundary }),
            .not_word_boundary => try self.emit(.{ .op = .not_word_boundary }),
            .sequence => |s| {
                for (s.items) |item| {
                    try self.compileNode(item);
                }
            },
            .alternation => |a| try self.compileAlternation(a.branches),
            .group => |g| try self.compileGroup(g),
            .repeat => |r| try self.compileRepeat(r),
            .backreference => |idx| {
                if (idx > self.group_count) {
                    return CompileError.InvalidBackreference;
                }
                try self.emit(.{ .op = .backreference, .x = idx });
            },
            .lookahead => |l| try self.compileLookahead(l),
            .lookbehind => |l| try self.compileLookbehind(l),
        }
    }

    fn compileAlternation(self: *Compiler, branches: []*parser.Node) CompileError!void {
        if (branches.len == 0) return;

        var jump_positions: std.ArrayList(usize) = .empty;
        defer jump_positions.deinit(self.allocator);

        var i: usize = 0;
        while (i < branches.len - 1) : (i += 1) {
            const split_idx = self.insts.items.len;
            try self.emit(.{ .op = .split, .x = 0, .y = 0 });

            const branch_start = self.currentIndex();

            try self.compileNode(branches[i]);

            const jump_idx = self.insts.items.len;
            try self.emit(.{ .op = .jump, .x = 0 });
            try jump_positions.append(self.allocator, jump_idx);

            const next_start = self.currentIndex();
            self.patch(split_idx, branch_start, next_start);
        }

        try self.compileNode(branches[branches.len - 1]);

        const end = self.currentIndex();
        for (jump_positions.items) |pos| {
            self.patch(pos, end, 0);
        }
    }

    fn compileGroup(self: *Compiler, group: parser.Group) CompileError!void {
        if (group.capturing) {
            const idx = group.index orelse 0;
            try self.emit(.{ .op = .save_start, .x = 2 + idx * 2 });
            try self.compileNode(group.node);
            try self.emit(.{ .op = .save_end, .x = 3 + idx * 2 });
        } else {
            try self.compileNode(group.node);
        }
    }

    fn compileRepeat(self: *Compiler, r: parser.Repeat) CompileError!void {
        const q = r.quantifier;

        switch (q.kind) {
            .zero_or_one => try self.compileOptional(r.node, q.greedy),
            .zero_or_more => try self.compileStar(r.node, q.greedy),
            .one_or_more => try self.compilePlus(r.node, q.greedy),
            .exact => try self.compileExact(r.node, q.min),
            .at_least => try self.compileAtLeast(r.node, q.min, q.greedy),
            .between => try self.compileBetween(r.node, q.min, q.max, q.greedy),
        }
    }

    fn compileOptional(self: *Compiler, node: *parser.Node, greedy: bool) CompileError!void {
        const split_idx = self.insts.items.len;
        try self.emit(.{ .op = .split, .x = 0, .y = 0 });

        const body_start = self.currentIndex();
        try self.compileNode(node);
        const end = self.currentIndex();

        if (greedy) {
            self.patch(split_idx, body_start, end + 1);
        } else {
            self.patch(split_idx, end + 1, body_start);
        }
    }

    fn compileStar(self: *Compiler, node: *parser.Node, greedy: bool) CompileError!void {
        const split_idx = self.insts.items.len;
        try self.emit(.{ .op = .split, .x = 0, .y = 0 });

        const body_start = self.currentIndex();
        try self.compileNode(node);

        try self.emit(.{ .op = .jump, .x = split_idx });
        const end = self.currentIndex();

        if (greedy) {
            self.patch(split_idx, body_start, end);
        } else {
            self.patch(split_idx, end, body_start);
        }
    }

    fn compilePlus(self: *Compiler, node: *parser.Node, greedy: bool) CompileError!void {
        const body_start = self.currentIndex();
        try self.compileNode(node);

        const split_idx = self.insts.items.len;
        try self.emit(.{ .op = .split, .x = 0, .y = 0 });

        const end = self.currentIndex();

        if (greedy) {
            self.patch(split_idx, body_start, end);
        } else {
            self.patch(split_idx, end, body_start);
        }
    }

    fn compileExact(self: *Compiler, node: *parser.Node, count: u32) CompileError!void {
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            try self.compileNode(node);
        }
    }

    fn compileAtLeast(self: *Compiler, node: *parser.Node, min: u32, greedy: bool) CompileError!void {
        if (min == 0) {
            try self.compileStar(node, greedy);
            return;
        }
        var i: u32 = 0;
        while (i < min) : (i += 1) {
            try self.compileNode(node);
        }
        try self.compileStar(node, greedy);
    }

    fn compileBetween(
        self: *Compiler,
        node: *parser.Node,
        min: u32,
        max: u32,
        greedy: bool,
    ) CompileError!void {
        var i: u32 = 0;
        while (i < min) : (i += 1) {
            try self.compileNode(node);
        }
        i = min;
        while (i < max) : (i += 1) {
            try self.compileOptional(node, greedy);
        }
    }

    fn compileLookahead(self: *Compiler, look: parser.Lookaround) CompileError!void {
        if (look.negative) {
            const split_idx = self.insts.items.len;
            try self.emit(.{ .op = .split, .x = 0, .y = 0 });

            const body_start = self.currentIndex();
            try self.compileNode(look.node);
            try self.emit(.{ .op = .assert_end });

            const fail_idx = self.insts.items.len;
            try self.emit(.{ .op = .jump, .x = 0 });

            const end = self.currentIndex();
            self.patch(split_idx, body_start, end);
            self.patch(fail_idx, end, 0);
        } else {
            const split_idx = self.insts.items.len;
            try self.emit(.{ .op = .split, .x = 0, .y = 0 });

            const fail_idx = self.insts.items.len;
            try self.emit(.{ .op = .jump, .x = 0 });

            const body_start = self.currentIndex();
            try self.compileNode(look.node);
            try self.emit(.{ .op = .assert_end });

            const end = self.currentIndex();
            self.patch(split_idx, body_start, end);
            self.patch(fail_idx, end, 0);
        }
    }

    fn compileLookbehind(self: *Compiler, look: parser.Lookaround) CompileError!void {
        _ = self;
        _ = look;
    }

    fn addClass(self: *Compiler, c: parser.Class) CompileError!usize {
        const index: usize = self.classes.items.len;

        var items: std.ArrayList(ClassItem) = .empty;
        errdefer items.deinit(self.allocator);

        for (c.items) |item| {
            switch (item) {
                .char => |cp| try items.append(self.allocator, .{ .char = cp }),
                .range => |r| {
                    try items.append(self.allocator, .{ .range_start = r.start });
                    try items.append(self.allocator, .{ .range_end = r.end });
                },
                .digit => try items.append(self.allocator, .{ .digit = {} }),
                .not_digit => try items.append(self.allocator, .{ .not_digit = {} }),
                .word => try items.append(self.allocator, .{ .word = {} }),
                .not_word => try items.append(self.allocator, .{ .not_word = {} }),
                .space => try items.append(self.allocator, .{ .space = {} }),
                .not_space => try items.append(self.allocator, .{ .not_space = {} }),
            }
        }

        const arr = try items.toOwnedSlice(self.allocator);
        try self.classes.append(self.allocator, .{
            .negated = c.negated,
            .items = arr,
        });

        return index;
    }
};

pub fn compile(
    allocator: std.mem.Allocator,
    root: *parser.Node,
    group_count: u32,
) CompileError!Program {
    var compiler = Compiler.init(allocator, group_count);
    defer compiler.deinit();
    return compiler.compile(root);
}

test "compile literal" {
    var result = try parser.parse(std.testing.allocator, "abc");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    try std.testing.expect(program.insts.len >= 4);
}

test "compile empty" {
    var result = try parser.parse(std.testing.allocator, "");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
}

test "compile group" {
    var result = try parser.parse(std.testing.allocator, "(abc)");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
    try std.testing.expectEqual(@as(u32, 1), program.group_count);
}

test "compile alternation" {
    var result = try parser.parse(std.testing.allocator, "a|b|c");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
}

test "compile quantifiers" {
    const patterns = [_][]const u8{
        "a*", "a+", "a?", "a{3}", "a{2,}", "a{1,5}",
    };
    for (patterns) |p| {
        var result = try parser.parse(std.testing.allocator, p);
        defer result.deinit();

        var program = try compile(std.testing.allocator, result.root, result.group_count);
        defer program.deinit();
    }
}

test "compile character class" {
    var result = try parser.parse(std.testing.allocator, "[a-z]");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
    try std.testing.expectEqual(@as(usize, 1), program.classes.len);
}

test "compile escape classes" {
    const patterns = [_][]const u8{ "\\d", "\\w", "\\s", "\\D", "\\W", "\\S" };
    for (patterns) |p| {
        var result = try parser.parse(std.testing.allocator, p);
        defer result.deinit();

        var program = try compile(std.testing.allocator, result.root, result.group_count);
        defer program.deinit();
    }
}

test "compile anchors" {
    var result = try parser.parse(std.testing.allocator, "^abc$");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
}

test "compile lookahead" {
    var result = try parser.parse(std.testing.allocator, "(?=abc)def");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
}

test "compile backreference" {
    var result = try parser.parse(std.testing.allocator, "(a)\\1");
    defer result.deinit();

    var program = try compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();
}
