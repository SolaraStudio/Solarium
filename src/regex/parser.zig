const std = @import("std");

pub const ParseError = error{
    OutOfMemory,
    UnexpectedEnd,
    UnmatchedParen,
    UnmatchedBracket,
    InvalidEscape,
    InvalidQuantifier,
    NothingToRepeat,
    InvalidCharacterClass,
    InvalidGroupName,
    DuplicateGroupName,
    InvalidBackreference,
    InvalidRange,
    TooManyGroups,
};

pub const QuantifierKind = enum {
    zero_or_one,
    zero_or_more,
    one_or_more,
    exact,
    at_least,
    between,
};

pub const Quantifier = struct {
    kind: QuantifierKind,
    min: u32 = 0,
    max: u32 = 0,
    greedy: bool = true,
};

pub const CharRange = struct {
    start: u21,
    end: u21,

    pub fn contains(self: CharRange, cp: u21) bool {
        return cp >= self.start and cp <= self.end;
    }
};

pub const ClassItem = union(enum) {
    char: u21,
    range: CharRange,
    digit: void,
    not_digit: void,
    word: void,
    not_word: void,
    space: void,
    not_space: void,
    unicode_prop: []const u8,
};

pub const Node = union(enum) {
    empty: void,
    char: u21,
    any: void,
    any_dotall: void,
    class: Class,
    start_anchor: void,
    end_anchor: void,
    word_boundary: void,
    not_word_boundary: void,
    group: Group,
    alternation: Alternation,
    sequence: Sequence,
    repeat: Repeat,
    backreference: u32,
    lookahead: Lookaround,
    lookbehind: Lookaround,
};

pub const Lookaround = struct {
    negative: bool,
    node: *Node,
};

pub const Class = struct {
    negated: bool,
    items: []ClassItem,
};

pub const Group = struct {
    index: ?u32,
    name: ?[]const u8,
    node: *Node,
    capturing: bool,
};

pub const Alternation = struct {
    branches: []*Node,
};

pub const Sequence = struct {
    items: []*Node,
};

pub const Repeat = struct {
    node: *Node,
    quantifier: Quantifier,
};

pub const GroupInfo = struct {
    index: u32,
    name: ?[]const u8,
};

pub const ParseResult = struct {
    root: *Node,
    group_count: u32,
    groups: []GroupInfo,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ParseResult) void {
        self.allocator.free(self.groups);
    }
};

pub const Parser = struct {
    pattern: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,
    group_count: u32,
    group_names: std.StringHashMap(u32),
    group_infos: std.ArrayList(GroupInfo),

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8) Parser {
        return .{
            .pattern = pattern,
            .pos = 0,
            .allocator = allocator,
            .group_count = 0,
            .group_names = std.StringHashMap(u32).init(allocator),
            .group_infos = .empty,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.group_names.deinit();
        self.group_infos.deinit(self.allocator);
    }

    pub fn parse(self: *Parser) ParseError!ParseResult {
        const root = try self.parseAlternation();

        if (self.pos < self.pattern.len) {
            return ParseError.UnmatchedParen;
        }

        const groups = try self.group_infos.toOwnedSlice(self.allocator);

        return .{
            .root = root,
            .group_count = self.group_count,
            .groups = groups,
            .allocator = self.allocator,
        };
    }

    fn current(self: *Parser) ?u8 {
        if (self.pos >= self.pattern.len) return null;
        return self.pattern[self.pos];
    }

    fn peekAt(self: *Parser, offset: usize) ?u8 {
        const p = self.pos + offset;
        if (p >= self.pattern.len) return null;
        return self.pattern[p];
    }

    fn advance(self: *Parser) ?u8 {
        const c = self.current() orelse return null;
        self.pos += 1;
        return c;
    }

    fn match(self: *Parser, c: u8) bool {
        if (self.current() == c) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn atEnd(self: *Parser) bool {
        return self.pos >= self.pattern.len;
    }

    fn makeNode(self: *Parser, node: Node) ParseError!*Node {
        const ptr = try self.allocator.create(Node);
        ptr.* = node;
        return ptr;
    }

    fn parseAlternation(self: *Parser) ParseError!*Node {
        var branches: std.ArrayList(*Node) = .empty;
        errdefer branches.deinit(self.allocator);

        const first = try self.parseSequence();
        try branches.append(self.allocator, first);

        while (self.current() == '|') {
            self.pos += 1;
            const branch = try self.parseSequence();
            try branches.append(self.allocator, branch);
        }

        if (branches.items.len == 1) {
            const result = branches.items[0];
            branches.deinit(self.allocator);
            return result;
        }

        const arr = try branches.toOwnedSlice(self.allocator);
        return self.makeNode(.{ .alternation = .{ .branches = arr } });
    }

    fn parseSequence(self: *Parser) ParseError!*Node {
        var items: std.ArrayList(*Node) = .empty;
        errdefer items.deinit(self.allocator);

        while (self.current()) |c| {
            if (c == '|' or c == ')') break;
            const item = try self.parseTerm();
            try items.append(self.allocator, item);
        }

        if (items.items.len == 0) {
            items.deinit(self.allocator);
            return self.makeNode(.{ .empty = {} });
        }

        if (items.items.len == 1) {
            const single = items.items[0];
            items.deinit(self.allocator);
            return single;
        }

        const arr = try items.toOwnedSlice(self.allocator);
        return self.makeNode(.{ .sequence = .{ .items = arr } });
    }

    fn parseTerm(self: *Parser) ParseError!*Node {
        const atom = try self.parseAtom();
        return try self.parseQuantifier(atom);
    }

    fn parseQuantifier(self: *Parser, atom: *Node) ParseError!*Node {
        const c = self.current() orelse return atom;

        var quant: Quantifier = undefined;
        var is_quantifier = false;

        switch (c) {
            '*' => {
                self.pos += 1;
                quant = .{ .kind = .zero_or_more };
                is_quantifier = true;
            },
            '+' => {
                self.pos += 1;
                quant = .{ .kind = .one_or_more };
                is_quantifier = true;
            },
            '?' => {
                self.pos += 1;
                quant = .{ .kind = .zero_or_one };
                is_quantifier = true;
            },
            '{' => {
                const saved = self.pos;
                self.pos += 1;
                if (try self.parseBracedQuantifier()) |q| {
                    quant = q;
                    is_quantifier = true;
                } else {
                    self.pos = saved;
                }
            },
            else => return atom,
        }

        if (!is_quantifier) return atom;

        if (self.current() == '?') {
            self.pos += 1;
            quant.greedy = false;
        }

        return self.makeNode(.{ .repeat = .{ .node = atom, .quantifier = quant } });
    }

    fn parseBracedQuantifier(self: *Parser) ParseError!?Quantifier {
        const min = self.parseDigits() orelse return null;

        if (self.current() == '}') {
            self.pos += 1;
            return Quantifier{ .kind = .exact, .min = min, .max = min };
        }

        if (self.current() != ',') return null;
        self.pos += 1;

        if (self.current() == '}') {
            self.pos += 1;
            return Quantifier{ .kind = .at_least, .min = min, .max = std.math.maxInt(u32) };
        }

        const max = self.parseDigits() orelse return null;

        if (self.current() != '}') return null;
        self.pos += 1;

        if (max < min) return ParseError.InvalidRange;

        return Quantifier{ .kind = .between, .min = min, .max = max };
    }

    fn parseDigits(self: *Parser) ?u32 {
        var value: u32 = 0;
        var has_digits = false;
        while (self.current()) |c| {
            if (c < '0' or c > '9') break;
            value = value * 10 + (c - '0');
            has_digits = true;
            self.pos += 1;
        }
        if (!has_digits) return null;
        return value;
    }

    fn parseAtom(self: *Parser) ParseError!*Node {
        const c = self.current() orelse return ParseError.UnexpectedEnd;

        switch (c) {
            '(' => return self.parseGroup(),
            '[' => return self.parseCharClass(),
            '.' => {
                self.pos += 1;
                return self.makeNode(.{ .any = {} });
            },
            '^' => {
                self.pos += 1;
                return self.makeNode(.{ .start_anchor = {} });
            },
            '$' => {
                self.pos += 1;
                return self.makeNode(.{ .end_anchor = {} });
            },
            '\\' => return self.parseEscape(),
            '*', '+', '?' => return ParseError.NothingToRepeat,
            ')' => return ParseError.UnmatchedParen,
            else => {
                self.pos += 1;
                return self.makeNode(.{ .char = c });
            },
        }
    }

    fn parseGroup(self: *Parser) ParseError!*Node {
        self.pos += 1;

        var capturing = true;
        var group_name: ?[]const u8 = null;

        if (self.current() == '?') {
            self.pos += 1;
            const kind = self.advance() orelse return ParseError.UnexpectedEnd;
            switch (kind) {
                ':' => {
                    capturing = false;
                },
                '=' => {
                    const inner = try self.parseAlternation();
                    if (!self.match(')')) return ParseError.UnmatchedParen;
                    const look = try self.makeNode(.{ .lookahead = .{ .negative = false, .node = inner } });
                    return look;
                },
                '!' => {
                    const inner = try self.parseAlternation();
                    if (!self.match(')')) return ParseError.UnmatchedParen;
                    const look = try self.makeNode(.{ .lookahead = .{ .negative = true, .node = inner } });
                    return look;
                },
                '<' => {
                    const next = self.advance() orelse return ParseError.UnexpectedEnd;
                    if (next == '=') {
                        const inner = try self.parseAlternation();
                        if (!self.match(')')) return ParseError.UnmatchedParen;
                        return self.makeNode(.{ .lookbehind = .{ .negative = false, .node = inner } });
                    }
                    if (next == '!') {
                        const inner = try self.parseAlternation();
                        if (!self.match(')')) return ParseError.UnmatchedParen;
                        return self.makeNode(.{ .lookbehind = .{ .negative = true, .node = inner } });
                    }
                    const name_start = self.pos - 1;
                    while (self.current()) |nc| {
                        if (nc == '>') break;
                        self.pos += 1;
                    }
                    if (!self.match('>')) return ParseError.InvalidGroupName;
                    group_name = self.pattern[name_start .. self.pos - 1];
                },
                else => return ParseError.InvalidGroupName,
            }
        }

        var group_index: ?u32 = null;
        if (capturing) {
            group_index = self.group_count;
            self.group_count += 1;
            try self.group_infos.append(self.allocator, .{
                .index = group_index.?,
                .name = group_name,
            });
            if (group_name) |name| {
                if (self.group_names.contains(name)) {
                    return ParseError.DuplicateGroupName;
                }
                try self.group_names.put(name, group_index.?);
            }
        }

        const inner = try self.parseAlternation();

        if (!self.match(')')) return ParseError.UnmatchedParen;

        return self.makeNode(.{ .group = .{
            .index = group_index,
            .name = group_name,
            .node = inner,
            .capturing = capturing,
        } });
    }

    fn parseCharClass(self: *Parser) ParseError!*Node {
        self.pos += 1;

        var negated = false;
        if (self.current() == '^') {
            negated = true;
            self.pos += 1;
        }

        var items: std.ArrayList(ClassItem) = .empty;
        errdefer items.deinit(self.allocator);

        var first = true;
        while (self.current()) |c| {
            if (c == ']' and !first) break;
            first = false;

            if (c == '\\') {
                self.pos += 1;
                const item = try self.parseClassEscape();
                try items.append(self.allocator, item);
                continue;
            }

            self.pos += 1;

            if (self.current() == '-' and self.peekAt(1) != ']' and self.peekAt(1) != null) {
                self.pos += 1;
                const end_c = self.advance() orelse return ParseError.UnexpectedEnd;
                if (end_c < c) return ParseError.InvalidRange;
                try items.append(self.allocator, .{ .range = .{ .start = c, .end = end_c } });
            } else {
                try items.append(self.allocator, .{ .char = c });
            }
        }

        if (!self.match(']')) return ParseError.UnmatchedBracket;

        const arr = try items.toOwnedSlice(self.allocator);
        return self.makeNode(.{ .class = .{ .negated = negated, .items = arr } });
    }

    fn parseClassEscape(self: *Parser) ParseError!ClassItem {
        const c = self.advance() orelse return ParseError.UnexpectedEnd;

        switch (c) {
            'd' => return .{ .digit = {} },
            'D' => return .{ .not_digit = {} },
            'w' => return .{ .word = {} },
            'W' => return .{ .not_word = {} },
            's' => return .{ .space = {} },
            'S' => return .{ .not_space = {} },
            'n' => return .{ .char = '\n' },
            'r' => return .{ .char = '\r' },
            't' => return .{ .char = '\t' },
            'f' => return .{ .char = 0x0C },
            'v' => return .{ .char = 0x0B },
            '0' => return .{ .char = 0 },
            'x' => {
                const cp = try self.parseHexEscape(2);
                return .{ .char = cp };
            },
            'u' => {
                const cp = try self.parseUnicodeEscape();
                return .{ .char = cp };
            },
            else => return .{ .char = c },
        }
    }

    fn parseEscape(self: *Parser) ParseError!*Node {
        self.pos += 1;
        const c = self.advance() orelse return ParseError.InvalidEscape;

        switch (c) {
            'd' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .digit = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            'D' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .not_digit = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            'w' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .word = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            'W' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .not_word = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            's' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .space = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            'S' => {
                const items = try self.allocator.alloc(ClassItem, 1);
                items[0] = .{ .not_space = {} };
                return self.makeNode(.{ .class = .{ .negated = false, .items = items } });
            },
            'b' => return self.makeNode(.{ .word_boundary = {} }),
            'B' => return self.makeNode(.{ .not_word_boundary = {} }),
            'n' => return self.makeNode(.{ .char = '\n' }),
            'r' => return self.makeNode(.{ .char = '\r' }),
            't' => return self.makeNode(.{ .char = '\t' }),
            'f' => return self.makeNode(.{ .char = 0x0C }),
            'v' => return self.makeNode(.{ .char = 0x0B }),
            '0' => return self.makeNode(.{ .char = 0 }),
            'x' => {
                const cp = try self.parseHexEscape(2);
                return self.makeNode(.{ .char = cp });
            },
            'u' => {
                const cp = try self.parseUnicodeEscape();
                return self.makeNode(.{ .char = cp });
            },
            '1'...'9' => {
                const start = self.pos - 1;
                while (self.current()) |nc| {
                    if (nc < '0' or nc > '9') break;
                    self.pos += 1;
                }
                const num_str = self.pattern[start..self.pos];
                const index = std.fmt.parseInt(u32, num_str, 10) catch return ParseError.InvalidBackreference;
                return self.makeNode(.{ .backreference = index });
            },
            else => return self.makeNode(.{ .char = c }),
        }
    }

    fn parseHexEscape(self: *Parser, count: u32) ParseError!u21 {
        var value: u21 = 0;
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const c = self.advance() orelse return ParseError.UnexpectedEnd;
            const digit = hexValue(c) orelse return ParseError.InvalidEscape;
            value = value * 16 + digit;
        }
        return value;
    }

    fn parseUnicodeEscape(self: *Parser) ParseError!u21 {
        if (self.current() == '{') {
            self.pos += 1;
            var value: u21 = 0;
            var count: u32 = 0;
            while (self.current()) |c| {
                if (c == '}') {
                    self.pos += 1;
                    if (count == 0) return ParseError.InvalidEscape;
                    return value;
                }
                const digit = hexValue(c) orelse return ParseError.InvalidEscape;
                value = value * 16 + digit;
                count += 1;
                if (count > 6) return ParseError.InvalidEscape;
                self.pos += 1;
            }
            return ParseError.UnexpectedEnd;
        }
        return try self.parseHexEscape(4);
    }

    fn hexValue(c: u8) ?u21 {
        if (c >= '0' and c <= '9') return c - '0';
        if (c >= 'a' and c <= 'f') return c - 'a' + 10;
        if (c >= 'A' and c <= 'F') return c - 'A' + 10;
        return null;
    }
};

pub fn parse(allocator: std.mem.Allocator, pattern: []const u8) ParseError!ParseResult {
    var parser = Parser.init(allocator, pattern);
    defer parser.deinit();
    return parser.parse();
}

fn isWordChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '_';
}

test "parse literal" {
    var result = try parse(std.testing.allocator, "abc");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 0), result.group_count);
}

test "parse empty" {
    var result = try parse(std.testing.allocator, "");
    defer result.deinit();
}

test "parse group captures" {
    var result = try parse(std.testing.allocator, "(abc)");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 1), result.group_count);
}

test "parse multiple groups" {
    var result = try parse(std.testing.allocator, "(a)(b)(c)");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 3), result.group_count);
}

test "parse non-capturing group" {
    var result = try parse(std.testing.allocator, "(?:abc)");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 0), result.group_count);
}

test "parse named group" {
    var result = try parse(std.testing.allocator, "(?<name>abc)");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 1), result.group_count);
    try std.testing.expectEqualStrings("name", result.groups[0].name.?);
}

test "parse alternation" {
    var result = try parse(std.testing.allocator, "a|b|c");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 0), result.group_count);
}

test "parse quantifiers" {
    const patterns = [_][]const u8{
        "a*", "a+", "a?", "a{3}", "a{2,}", "a{1,5}",
        "a*?", "a+?", "a??",
    };
    for (patterns) |p| {
        var result = try parse(std.testing.allocator, p);
        defer result.deinit();
    }
}

test "parse character class" {
    var result = try parse(std.testing.allocator, "[a-z]");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 0), result.group_count);
}

test "parse negated character class" {
    var result = try parse(std.testing.allocator, "[^a-z]");
    defer result.deinit();
}

test "parse class with multiple ranges" {
    var result = try parse(std.testing.allocator, "[a-zA-Z0-9_]");
    defer result.deinit();
}

test "parse escape sequences" {
    const patterns = [_][]const u8{
        "\\d", "\\D", "\\w", "\\W", "\\s", "\\S",
        "\\n", "\\r", "\\t", "\\b", "\\B",
    };
    for (patterns) |p| {
        var result = try parse(std.testing.allocator, p);
        defer result.deinit();
    }
}

test "parse hex escape" {
    var result = try parse(std.testing.allocator, "\\x41");
    defer result.deinit();
}

test "parse unicode escape" {
    var result = try parse(std.testing.allocator, "\\u0041");
    defer result.deinit();
}

test "parse unicode braced escape" {
    var result = try parse(std.testing.allocator, "\\u{1F600}");
    defer result.deinit();
}

test "parse anchors" {
    var r1 = try parse(std.testing.allocator, "^abc$");
    defer r1.deinit();
    var r2 = try parse(std.testing.allocator, "\\bfoo\\B");
    defer r2.deinit();
}

test "parse lookahead" {
    var r1 = try parse(std.testing.allocator, "(?=abc)");
    defer r1.deinit();
    var r2 = try parse(std.testing.allocator, "(?!abc)");
    defer r2.deinit();
}

test "parse lookbehind" {
    var r1 = try parse(std.testing.allocator, "(?<=abc)");
    defer r1.deinit();
    var r2 = try parse(std.testing.allocator, "(?<!abc)");
    defer r2.deinit();
}

test "parse backreference" {
    var result = try parse(std.testing.allocator, "(a)\\1");
    defer result.deinit();
    try std.testing.expectEqual(@as(u32, 1), result.group_count);
}

test "parse dot" {
    var result = try parse(std.testing.allocator, "a.b");
    defer result.deinit();
}

test "parse unmatched paren" {
    try std.testing.expectError(ParseError.UnmatchedParen, parse(std.testing.allocator, "(abc"));
    try std.testing.expectError(ParseError.UnmatchedParen, parse(std.testing.allocator, "abc)"));
}

test "parse unmatched bracket" {
    try std.testing.expectError(ParseError.UnmatchedBracket, parse(std.testing.allocator, "[abc"));
}

test "parse nothing to repeat" {
    try std.testing.expectError(ParseError.NothingToRepeat, parse(std.testing.allocator, "*abc"));
}

test "parse invalid range" {
    try std.testing.expectError(ParseError.InvalidRange, parse(std.testing.allocator, "[z-a]"));
}

test "parse duplicate group name" {
    try std.testing.expectError(ParseError.DuplicateGroupName, parse(std.testing.allocator, "(?<x>a)(?<x>b)"));
}
