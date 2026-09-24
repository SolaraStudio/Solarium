const std = @import("std");
const parser = @import("parser.zig");
const compiler = @import("compiler.zig");
const exec = @import("exec.zig");
const match_mod = @import("match.zig");

pub const Match = match_mod.Match;
pub const Group = match_mod.Group;

pub const Error = error{
    OutOfMemory,
    SyntaxError,
    RuntimeError,
    NoMatch,
    TooManySteps,
};

pub const Flags = struct {
    global: bool = false,
    ignore_case: bool = false,
    multiline: bool = false,
    dotall: bool = false,
    unicode: bool = false,
    sticky: bool = false,

    pub fn parse(text: []const u8) Flags {
        var flags = Flags{};
        for (text) |c| {
            switch (c) {
                'g' => flags.global = true,
                'i' => flags.ignore_case = true,
                'm' => flags.multiline = true,
                's' => flags.dotall = true,
                'u' => flags.unicode = true,
                'y' => flags.sticky = true,
                else => {},
            }
        }
        return flags;
    }

    pub fn toString(self: Flags, buffer: []u8) []const u8 {
        var i: usize = 0;
        if (self.global and i < buffer.len) {
            buffer[i] = 'g';
            i += 1;
        }
        if (self.ignore_case and i < buffer.len) {
            buffer[i] = 'i';
            i += 1;
        }
        if (self.multiline and i < buffer.len) {
            buffer[i] = 'm';
            i += 1;
        }
        if (self.dotall and i < buffer.len) {
            buffer[i] = 's';
            i += 1;
        }
        if (self.unicode and i < buffer.len) {
            buffer[i] = 'u';
            i += 1;
        }
        if (self.sticky and i < buffer.len) {
            buffer[i] = 'y';
            i += 1;
        }
        return buffer[0..i];
    }
};

pub const Regex = struct {
    program: compiler.Program,
    source: []const u8,
    flags: Flags,
    allocator: std.mem.Allocator,
    last_index: usize,

    pub fn compile(allocator: std.mem.Allocator, pattern: []const u8, flags: Flags) Error!Regex {
        var parse_result = parser.parse(allocator, pattern) catch |err| {
            return switch (err) {
                error.OutOfMemory => Error.OutOfMemory,
                else => Error.SyntaxError,
            };
        };
        defer parse_result.deinit();

        var program = compiler.compile(allocator, parse_result.root, parse_result.group_count) catch |err| {
            return switch (err) {
                error.OutOfMemory => Error.OutOfMemory,
                else => Error.SyntaxError,
            };
        };

        return .{
            .program = program,
            .source = pattern,
            .flags = flags,
            .allocator = allocator,
            .last_index = 0,
        };
    }

    pub fn deinit(self: *Regex) void {
        self.program.deinit();
    }

    fn execOptions(self: Regex) exec.Options {
        return .{
            .multiline = self.flags.multiline,
            .dotall = self.flags.dotall,
            .ignore_case = self.flags.ignore_case,
            .unicode = self.flags.unicode,
            .sticky = self.flags.sticky,
            .global = self.flags.global,
        };
    }

    pub fn exec(self: *Regex, input: []const u8) Error!?Match {
        const start = if (self.flags.sticky) self.last_index else 0;
        return self.execAt(input, start);
    }

    pub fn execAt(self: *Regex, input: []const u8, start: usize) Error!?Match {
        if (start > input.len) return null;

        var i = start;
        while (i <= input.len) {
            const result = exec.execute(
                self.allocator,
                &self.program,
                input,
                self.execOptions(),
                i,
            ) catch {
                return Error.RuntimeError;
            };

            if (result) |r| {
                var m = Match.init(self.allocator, 1 + self.program.group_count) catch {
                    return Error.OutOfMemory;
                };
                m.start = r.start;
                m.end = r.end;
                for (r.groups, 0..) |g, idx| {
                    if (idx >= m.groups.len) break;
                    if (g.matched()) {
                        m.groups[idx] = .{ .start = g.start.?, .end = g.end.? };
                    } else {
                        m.groups[idx] = .{ .start = 0, .end = 0 };
                    }
                }
                self.last_index = r.end;
                return m;
            }

            if (self.flags.sticky) break;
            i += 1;
        }

        self.last_index = 0;
        return null;
    }

    pub fn test(self: *Regex, input: []const u8) Error!bool {
        const m = try self.exec(input);
        if (m) |match_result| {
            var mutable = match_result;
            mutable.deinit();
            return true;
        }
        return false;
    }

    pub fn reset(self: *Regex) void {
        self.last_index = 0;
    }

    pub fn getLastIndex(self: Regex) usize {
        return self.last_index;
    }

    pub fn setLastIndex(self: *Regex, index: usize) void {
        self.last_index = index;
    }

    pub fn groupCount(self: Regex) u32 {
        return self.program.group_count;
    }

    pub fn pattern(self: Regex) []const u8 {
        return self.source;
    }

    pub fn getFlags(self: Regex) Flags {
        return self.flags;
    }

    pub fn findAll(self: *Regex, allocator: std.mem.Allocator, input: []const u8) Error![]Match {
        var matches: std.ArrayList(Match) = .empty;
        errdefer {
            for (matches.items) |*m| {
                m.deinit();
            }
            matches.deinit(allocator);
        }

        var pos: usize = 0;
        while (pos <= input.len) {
            const m = try self.execAt(input, pos);
            if (m == null) break;
            var match_val = m.?;
            const end = match_val.end;
            try matches.append(allocator, match_val);
            if (end == pos) {
                pos += 1;
            } else {
                pos = end;
            }
            if (!self.flags.global) break;
        }

        return matches.toOwnedSlice(allocator);
    }
};

pub fn compile(allocator: std.mem.Allocator, pattern: []const u8) Error!Regex {
    return Regex.compile(allocator, pattern, .{});
}

pub fn compileWithFlags(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    flags: Flags,
) Error!Regex {
    return Regex.compile(allocator, pattern, flags);
}

pub fn test(allocator: std.mem.Allocator, pattern: []const u8, input: []const u8) Error!bool {
    var regex = try Regex.compile(allocator, pattern, .{});
    defer regex.deinit();
    return regex.test(input);
}

test "regex compile simple" {
    var regex = try Regex.compile(std.testing.allocator, "abc", .{});
    defer regex.deinit();
    try std.testing.expectEqual(@as(u32, 0), regex.groupCount());
}

test "regex match literal" {
    var regex = try Regex.compile(std.testing.allocator, "abc", .{});
    defer regex.deinit();

    const m = try regex.exec("xabcy");
    try std.testing.expect(m != null);
    if (m) |match_result| {
        var mutable = match_result;
        defer mutable.deinit();
        try std.testing.expectEqual(@as(usize, 1), mutable.start);
        try std.testing.expectEqual(@as(usize, 4), mutable.end);
    }
}

test "regex no match" {
    var regex = try Regex.compile(std.testing.allocator, "xyz", .{});
    defer regex.deinit();

    const m = try regex.exec("abc");
    try std.testing.expect(m == null);
}

test "regex test helper" {
    var regex = try Regex.compile(std.testing.allocator, "\\d+", .{});
    defer regex.deinit();

    try std.testing.expect(try regex.test("abc123"));
    try std.testing.expect(!try regex.test("abcdef"));
}

test "regex groups" {
    var regex = try Regex.compile(std.testing.allocator, "(\\d+)-(\\d+)", .{});
    defer regex.deinit();

    const m = try regex.exec("10-20");
    if (m) |match_result| {
        var mutable = match_result;
        defer mutable.deinit();
        try std.testing.expectEqual(@as(usize, 2), regex.groupCount());
        const source = "10-20";
        try std.testing.expectEqualStrings("10", mutable.groupText(source, 1).?);
        try std.testing.expectEqualStrings("20", mutable.groupText(source, 2).?);
    } else {
        try std.testing.expect(false);
    }
}

test "regex flags parse" {
    const f = Flags.parse("gimsuy");
    try std.testing.expect(f.global);
    try std.testing.expect(f.ignore_case);
    try std.testing.expect(f.multiline);
    try std.testing.expect(f.dotall);
    try std.testing.expect(f.unicode);
    try std.testing.expect(f.sticky);
}

test "regex flags toString" {
    const f = Flags{ .global = true, .ignore_case = true };
    var buf: [8]u8 = undefined;
    const s = f.toString(&buf);
    try std.testing.expectEqualStrings("gi", s);
}

test "regex ignore case" {
    var regex = try Regex.compile(std.testing.allocator, "ABC", .{ .ignore_case = true });
    defer regex.deinit();

    const m = try regex.exec("abcdef");
    try std.testing.expect(m != null);
    if (m) |match_result| {
        var mutable = match_result;
        mutable.deinit();
    }
}

test "regex findAll" {
    var regex = try Regex.compile(std.testing.allocator, "\\d+", .{ .global = true });
    defer regex.deinit();

    const matches = try regex.findAll(std.testing.allocator, "a1b2c3");
    defer {
        for (matches) |*m| {
            m.deinit();
        }
        std.testing.allocator.free(matches);
    }

    try std.testing.expectEqual(@as(usize, 3), matches.len);
}

test "regex last index" {
    var regex = try Regex.compile(std.testing.allocator, "\\d", .{ .global = true });
    defer regex.deinit();

    const m = try regex.exec("123");
    if (m) |match_result| {
        var mutable = match_result;
        mutable.deinit();
        try std.testing.expectEqual(@as(usize, 1), regex.getLastIndex());
    }
}

test "regex reset" {
    var regex = try Regex.compile(std.testing.allocator, "a", .{ .global = true });
    defer regex.deinit();

    const m = try regex.exec("abc");
    if (m) |match_result| {
        var mutable = match_result;
        mutable.deinit();
    }
    regex.reset();
    try std.testing.expectEqual(@as(usize, 0), regex.getLastIndex());
}

test "regex syntax error" {
    try std.testing.expectError(Error.SyntaxError, Regex.compile(std.testing.allocator, "(abc", .{}));
}

test "regex shorthand classes" {
    var regex = try Regex.compile(std.testing.allocator, "\\w+", .{});
    defer regex.deinit();

    const m = try regex.exec("hello_world123");
    try std.testing.expect(m != null);
    if (m) |match_result| {
        var mutable = match_result;
        mutable.deinit();
    }
}

test "regex quantifiers" {
    var regex = try Regex.compile(std.testing.allocator, "a{2,4}", .{});
    defer regex.deinit();

    const m = try regex.exec("aaaaa");
    try std.testing.expect(m != null);
    if (m) |match_result| {
        var mutable = match_result;
        mutable.deinit();
        try std.testing.expectEqual(@as(usize, 4), mutable.end);
    }
}

test "regex compile helper" {
    var regex = try compile(std.testing.allocator, "test");
    defer regex.deinit();
    try std.testing.expectEqualStrings("test", regex.pattern());
}

test "regex test function" {
    const result = try test(std.testing.allocator, "\\d+", "abc123");
    try std.testing.expect(result);
}
