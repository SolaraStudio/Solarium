const std = @import("std");
const compiler = @import("compiler.zig");

pub const ExecError = error{
    OutOfMemory,
    StackOverflow,
    InvalidProgram,
};

pub const Options = struct {
    multiline: bool = false,
    dotall: bool = false,
    ignore_case: bool = false,
    unicode: bool = false,
    sticky: bool = false,
    global: bool = false,
};

pub const ExecResult = struct {
    start: usize,
    end: usize,
    groups: []Group,

    pub const Group = struct {
        start: ?usize,
        end: ?usize,

        pub fn matched(self: Group) bool {
            return self.start != null and self.end != null;
        }
    };

    pub fn deinit(self: *ExecResult, allocator: std.mem.Allocator) void {
        allocator.free(self.groups);
    }
};

pub const Executor = struct {
    program: *const compiler.Program,
    input: []const u8,
    options: Options,
    allocator: std.mem.Allocator,
    steps: u64,
    max_steps: u64,

    pub fn init(
        allocator: std.mem.Allocator,
        program: *const compiler.Program,
        input: []const u8,
        options: Options,
    ) Executor {
        return .{
            .program = program,
            .input = input,
            .options = options,
            .allocator = allocator,
            .steps = 0,
            .max_steps = 1_000_000,
        };
    }

    pub fn exec(self: *Executor, start: usize) ExecError!?ExecResult {
        const group_count = self.program.group_count;
        const slot_count = 2 + group_count * 2;

        const raw = try self.allocator.alloc(ExecResult.Group, slot_count);
        defer self.allocator.free(raw);

        for (raw) |*g| {
            g.* = .{ .start = null, .end = null };
        }

        self.steps = 0;

        if (!self.runProgram(start, raw, 0)) {
            return null;
        }

        const out = try self.allocator.alloc(ExecResult.Group, 1 + group_count);
        errdefer self.allocator.free(out);

        out[0] = .{ .start = raw[0].start, .end = raw[1].end };
        var i: usize = 0;
        while (i < group_count) : (i += 1) {
            out[i + 1] = .{
                .start = raw[2 + i * 2].start,
                .end = raw[3 + i * 2].end,
            };
        }

        const full_start = raw[0].start orelse start;
        const full_end = raw[1].end orelse start;

        return .{
            .start = full_start,
            .end = full_end,
            .groups = out,
        };
    }

    fn runProgram(
        self: *Executor,
        pos: usize,
        groups: []ExecResult.Group,
        pc: usize,
    ) bool {
        self.steps += 1;
        if (self.steps > self.max_steps) return false;

        const inst = self.program.insts[pc];

        switch (inst.op) {
            .char => {
                if (pos >= self.input.len) return false;
                if (inst.x > 0x7F) return false;
                const expected: u8 = @intCast(inst.x);
                const actual = self.input[pos];
                if (self.options.ignore_case) {
                    if (lowerAscii(actual) != lowerAscii(expected)) return false;
                } else {
                    if (actual != expected) return false;
                }
                return self.runProgram(pos + 1, groups, pc + 1);
            },
            .any => {
                if (pos >= self.input.len) return false;
                const c = self.input[pos];
                if (!self.options.dotall and (c == '\n' or c == '\r')) return false;
                return self.runProgram(pos + 1, groups, pc + 1);
            },
            .any_dotall => {
                if (pos >= self.input.len) return false;
                return self.runProgram(pos + 1, groups, pc + 1);
            },
            .class => {
                if (pos >= self.input.len) return false;
                const c = self.input[pos];
                const class = self.program.classes[inst.x];
                if (!matchClass(class, c)) return false;
                return self.runProgram(pos + 1, groups, pc + 1);
            },
            .start_anchor => {
                if (pos == 0) {
                    return self.runProgram(pos, groups, pc + 1);
                }
                if (self.options.multiline and pos > 0) {
                    const prev = self.input[pos - 1];
                    if (prev == '\n') {
                        return self.runProgram(pos, groups, pc + 1);
                    }
                }
                return false;
            },
            .end_anchor => {
                if (pos == self.input.len) {
                    return self.runProgram(pos, groups, pc + 1);
                }
                if (self.options.multiline and pos < self.input.len) {
                    const c = self.input[pos];
                    if (c == '\n') {
                        return self.runProgram(pos, groups, pc + 1);
                    }
                }
                return false;
            },
            .word_boundary => {
                if (!self.checkWordBoundary(pos)) return false;
                return self.runProgram(pos, groups, pc + 1);
            },
            .not_word_boundary => {
                if (self.checkWordBoundary(pos)) return false;
                return self.runProgram(pos, groups, pc + 1);
            },
            .split => {
                if (self.runProgram(pos, groups, inst.x)) return true;
                return self.runProgram(pos, groups, inst.y);
            },
            .jump => {
                return self.runProgram(pos, groups, inst.x);
            },
            .save_start => {
                const idx = inst.x;
                if (idx >= groups.len) return false;
                const old = groups[idx].start;
                groups[idx].start = pos;
                if (self.runProgram(pos, groups, pc + 1)) return true;
                groups[idx].start = old;
                return false;
            },
            .save_end => {
                const idx = inst.x;
                if (idx >= groups.len) return false;
                const old = groups[idx].end;
                groups[idx].end = pos;
                if (self.runProgram(pos, groups, pc + 1)) return true;
                groups[idx].end = old;
                return false;
            },
            .backreference => {
                const idx = inst.x;
                if (idx >= groups.len) return false;
                const g = groups[idx];
                if (!g.matched()) return true;
                const gs = g.start.?;
                const ge = g.end.?;
                const len = ge - gs;
                if (pos + len > self.input.len) return false;
                const captured = self.input[gs..ge];
                const candidate = self.input[pos .. pos + len];
                if (self.options.ignore_case) {
                    if (!eqlIgnoreCase(captured, candidate)) return false;
                } else {
                    if (!std.mem.eql(u8, captured, candidate)) return false;
                }
                return self.runProgram(pos + len, groups, pc + 1);
            },
            .assert_start => {
                return self.runProgram(pos, groups, pc + 1);
            },
            .assert_end => {
                return self.runProgram(pos, groups, pc + 1);
            },
            .match => return true,
        }
    }

    fn checkWordBoundary(self: *Executor, pos: usize) bool {
        const before = if (pos == 0) false else isWordChar(self.input[pos - 1]);
        const after = if (pos >= self.input.len) false else isWordChar(self.input[pos]);
        return before != after;
    }
};

fn matchClass(class: compiler.Class, c: u8) bool {
    var matched = false;

    var i: usize = 0;
    while (i < class.items.len) : (i += 1) {
        const item = class.items[i];
        switch (item) {
            .char => |cp| {
                if (cp <= 0x7F and @as(u8, @intCast(cp)) == c) {
                    matched = true;
                    break;
                }
            },
            .range_start => |start| {
                if (i + 1 < class.items.len) {
                    const end_item = class.items[i + 1];
                    if (end_item == .range_end) {
                        const end = end_item.range_end;
                        if (c >= start and c <= end) {
                            matched = true;
                            break;
                        }
                        i += 1;
                    }
                }
            },
            .digit => {
                if (c >= '0' and c <= '9') {
                    matched = true;
                    break;
                }
            },
            .not_digit => {
                if (!(c >= '0' and c <= '9')) {
                    matched = true;
                    break;
                }
            },
            .word => {
                if (isWordChar(c)) {
                    matched = true;
                    break;
                }
            },
            .not_word => {
                if (!isWordChar(c)) {
                    matched = true;
                    break;
                }
            },
            .space => {
                if (isSpaceChar(c)) {
                    matched = true;
                    break;
                }
            },
            .not_space => {
                if (!isSpaceChar(c)) {
                    matched = true;
                    break;
                }
            },
            .range_end => {},
        }
    }

    if (class.negated) return !matched;
    return matched;
}

pub fn execute(
    allocator: std.mem.Allocator,
    program: *const compiler.Program,
    input: []const u8,
    options: Options,
    start: usize,
) ExecError!?ExecResult {
    var exec = Executor.init(allocator, program, input, options);
    return exec.exec(start);
}

fn lowerAscii(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (lowerAscii(x) != lowerAscii(y)) return false;
    }
    return true;
}

fn isWordChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '_';
}

fn isSpaceChar(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0B or c == 0x0C;
}

test "exec literal" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "abc");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "abcdef", .{}, 0);
    if (m) |*match| {
        defer match.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), match.start);
        try std.testing.expectEqual(@as(usize, 3), match.end);
    } else {
        try std.testing.expect(false);
    }
}

test "exec literal no match" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "xyz");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    const m = try execute(std.testing.allocator, &program, "abcdef", .{}, 0);
    try std.testing.expect(m == null);
}

test "exec alternation" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "cat|dog");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m1 = try execute(std.testing.allocator, &program, "cat", .{}, 0);
    try std.testing.expect(m1 != null);
    if (m1) |*x| x.deinit(std.testing.allocator);

    var m2 = try execute(std.testing.allocator, &program, "dog", .{}, 0);
    try std.testing.expect(m2 != null);
    if (m2) |*x| x.deinit(std.testing.allocator);

    const m3 = try execute(std.testing.allocator, &program, "fish", .{}, 0);
    try std.testing.expect(m3 == null);
}

test "exec star" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "a*");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "aaab", .{}, 0);
    if (m) |*match| {
        defer match.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), match.start);
        try std.testing.expectEqual(@as(usize, 3), match.end);
    } else {
        try std.testing.expect(false);
    }
}

test "exec plus" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "a+");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "aaab", .{}, 0);
    if (m) |*match| {
        defer match.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 3), match.end);
    }
}

test "exec anchors" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "^abc$");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m1 = try execute(std.testing.allocator, &program, "abc", .{}, 0);
    try std.testing.expect(m1 != null);
    if (m1) |*x| x.deinit(std.testing.allocator);

    const m2 = try execute(std.testing.allocator, &program, "abcd", .{}, 0);
    try std.testing.expect(m2 == null);
}

test "exec character class" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "[a-z]+");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "abcdef", .{}, 0);
    try std.testing.expect(m != null);
    if (m) |*x| x.deinit(std.testing.allocator);
}

test "exec capture group" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "(abc)");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "abcdef", .{}, 0);
    if (m) |*match| {
        defer match.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), match.start);
        try std.testing.expectEqual(@as(usize, 3), match.end);
        try std.testing.expectEqual(@as(usize, 0), match.groups[1].start.?);
        try std.testing.expectEqual(@as(usize, 3), match.groups[1].end.?);
    } else {
        try std.testing.expect(false);
    }
}

test "exec digit class" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "\\d+");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m = try execute(std.testing.allocator, &program, "123abc", .{}, 0);
    if (m) |*match| {
        defer match.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 3), match.end);
    }
}

test "exec word boundary" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "\\bfoo\\b");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m1 = try execute(std.testing.allocator, &program, "foo bar", .{}, 0);
    try std.testing.expect(m1 != null);
    if (m1) |*x| x.deinit(std.testing.allocator);

    const m2 = try execute(std.testing.allocator, &program, "foobar", .{}, 0);
    try std.testing.expect(m2 == null);
}

test "exec optional" {
    const parser = @import("parser.zig");
    var result = try parser.parse(std.testing.allocator, "ab?c");
    defer result.deinit();

    var program = try compiler.compile(std.testing.allocator, result.root, result.group_count);
    defer program.deinit();

    var m1 = try execute(std.testing.allocator, &program, "abc", .{}, 0);
    try std.testing.expect(m1 != null);
    if (m1) |*x| x.deinit(std.testing.allocator);

    var m2 = try execute(std.testing.allocator, &program, "ac", .{}, 0);
    try std.testing.expect(m2 != null);
    if (m2) |*x| x.deinit(std.testing.allocator);
}
