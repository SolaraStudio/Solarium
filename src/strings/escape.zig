const std = @import("std");

pub const EscapeError = error{
    InvalidEscape,
    UnterminatedEscape,
    InvalidHexDigit,
    InvalidCodePoint,
    BufferTooSmall,
};

pub fn escapeSingle(allocator: std.mem.Allocator, c: u8, out: *std.ArrayList(u8)) !void {
    switch (c) {
        '"' => try out.appendSlice(allocator, "\\\""),
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        0x08 => try out.appendSlice(allocator, "\\b"),
        0x0C => try out.appendSlice(allocator, "\\f"),
        0x0B => try out.appendSlice(allocator, "\\v"),
        0x00 => try out.appendSlice(allocator, "\\0"),
        0x1B => try out.appendSlice(allocator, "\\e"),
        else => {
            if (c < 0x20 or c == 0x7F) {
                var buf: [8]u8 = undefined;
                const s = try std.fmt.bufPrint(&buf, "\\x{x:0>2}", .{c});
                try out.appendSlice(allocator, s);
            } else {
                try out.append(allocator, c);
            }
        },
    }
}

pub fn escape(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.append(allocator, '"');
    for (input) |c| {
        try escapeSingle(allocator, c, &out);
    }
    try out.append(allocator, '"');

    return out.toOwnedSlice(allocator);
}

pub fn escapeNoQuotes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (input) |c| {
        try escapeSingle(allocator, c, &out);
    }

    return out.toOwnedSlice(allocator);
}

pub fn unescape(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        if (c != '\\') {
            try out.append(allocator, c);
            i += 1;
            continue;
        }

        if (i + 1 >= input.len) return EscapeError.UnterminatedEscape;
        const next = input[i + 1];
        i += 2;

        switch (next) {
            '"' => try out.append(allocator, '"'),
            '\'' => try out.append(allocator, '\''),
            '\\' => try out.append(allocator, '\\'),
            '/' => try out.append(allocator, '/'),
            'n' => try out.append(allocator, '\n'),
            'r' => try out.append(allocator, '\r'),
            't' => try out.append(allocator, '\t'),
            'b' => try out.append(allocator, 0x08),
            'f' => try out.append(allocator, 0x0C),
            'v' => try out.append(allocator, 0x0B),
            '0' => try out.append(allocator, 0x00),
            'e' => try out.append(allocator, 0x1B),
            'x' => {
                if (i + 1 >= input.len) return EscapeError.InvalidEscape;
                const hex = input[i .. i + 2];
                const value = std.fmt.parseInt(u8, hex, 16) catch return EscapeError.InvalidHexDigit;
                try out.append(allocator, value);
                i += 2;
            },
            'u' => {
                if (i + 3 >= input.len) return EscapeError.InvalidEscape;
                if (input[i] == '{') {
                    const end = std.mem.indexOfScalar(u8, input[i..], '}') orelse return EscapeError.InvalidEscape;
                    const hex = input[i + 1 .. i + end];
                    const cp = std.fmt.parseInt(u21, hex, 16) catch return EscapeError.InvalidHexDigit;
                    if (cp > 0x10FFFF) return EscapeError.InvalidCodePoint;
                    try appendUtf8(allocator, &out, cp);
                    i += end + 1;
                } else {
                    const hex = input[i .. i + 4];
                    const cp = std.fmt.parseInt(u21, hex, 16) catch return EscapeError.InvalidHexDigit;
                    try appendUtf8(allocator, &out, cp);
                    i += 4;
                }
            },
            else => return EscapeError.InvalidEscape,
        }
    }

    return out.toOwnedSlice(allocator);
}

fn appendUtf8(allocator: std.mem.Allocator, out: *std.ArrayList(u8), cp: u21) !void {
    const utf8 = @import("utf8.zig");
    var buf: [4]u8 = undefined;
    const n = utf8.encode(cp, &buf) orelse return EscapeError.InvalidCodePoint;
    try out.appendSlice(allocator, buf[0..n]);
}

pub fn escapeHtml(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '<' => try out.appendSlice(allocator, "&lt;"),
            '>' => try out.appendSlice(allocator, "&gt;"),
            '&' => try out.appendSlice(allocator, "&amp;"),
            '"' => try out.appendSlice(allocator, "&quot;"),
            '\'' => try out.appendSlice(allocator, "&#39;"),
            else => try out.append(allocator, c),
        }
    }

    return out.toOwnedSlice(allocator);
}

pub fn unescapeHtml(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] != '&') {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        }

        const end = std.mem.indexOfScalar(u8, input[i..], ';') orelse {
            try out.append(allocator, input[i]);
            i += 1;
            continue;
        };

        const entity = input[i + 1 .. i + end];
        i += end + 1;

        if (std.mem.eql(u8, entity, "lt")) {
            try out.append(allocator, '<');
        } else if (std.mem.eql(u8, entity, "gt")) {
            try out.append(allocator, '>');
        } else if (std.mem.eql(u8, entity, "amp")) {
            try out.append(allocator, '&');
        } else if (std.mem.eql(u8, entity, "quot")) {
            try out.append(allocator, '"');
        } else if (std.mem.eql(u8, entity, "apos")) {
            try out.append(allocator, '\'');
        } else if (std.mem.eql(u8, entity, "nbsp")) {
            try out.append(allocator, 0xA0);
        } else if (entity.len > 0 and entity[0] == '#') {
            const hex = entity[1..];
            if (hex.len > 0 and (hex[0] == 'x' or hex[0] == 'X')) {
                const cp = std.fmt.parseInt(u21, hex[1..], 16) catch return EscapeError.InvalidHexDigit;
                try appendUtf8(allocator, &out, cp);
            } else {
                const cp = std.fmt.parseInt(u21, hex, 10) catch return EscapeError.InvalidCodePoint;
                try appendUtf8(allocator, &out, cp);
            }
        } else {
            try out.append(allocator, '&');
            try out.appendSlice(allocator, entity);
            try out.append(allocator, ';');
        }
    }

    return out.toOwnedSlice(allocator);
}

pub fn isEscaped(input: []const u8, index: usize) bool {
    if (index == 0) return false;
    var count: usize = 0;
    var i = index;
    while (i > 0) {
        i -= 1;
        if (input[i] == '\\') {
            count += 1;
        } else {
            break;
        }
    }
    return (count % 2) == 1;
}

test "escape basic" {
    const allocator = std.testing.allocator;
    const out = try escape(allocator, "hello");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"hello\"", out);
}

test "escape with quotes" {
    const allocator = std.testing.allocator;
    const out = try escape(allocator, "he\"llo");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"he\\\"llo\"", out);
}

test "escape with newline" {
    const allocator = std.testing.allocator;
    const out = try escape(allocator, "a\nb");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"a\\nb\"", out);
}

test "escape with tab" {
    const allocator = std.testing.allocator;
    const out = try escape(allocator, "a\tb");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"a\\tb\"", out);
}

test "escape with backslash" {
    const allocator = std.testing.allocator;
    const out = try escape(allocator, "a\\b");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"a\\\\b\"", out);
}

test "escape control char" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 0x01, 0x02 };
    const out = try escape(allocator, &input);
    defer allocator.free(out);
    try std.testing.expectEqualStrings("\"\\x01\\x02\"", out);
}

test "escapeNoQuotes" {
    const allocator = std.testing.allocator;
    const out = try escapeNoQuotes(allocator, "a\nb");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("a\\nb", out);
}

test "unescape basic" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "hello");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("hello", out);
}

test "unescape newline" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "a\\nb");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("a\nb", out);
}

test "unescape quote" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "a\\\"b");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("a\"b", out);
}

test "unescape hex" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "\\x41");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("A", out);
}

test "unescape unicode" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "\\u0041");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("A", out);
}

test "unescape unicode braced" {
    const allocator = std.testing.allocator;
    const out = try unescape(allocator, "\\u{1F600}");
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 4), out.len);
}

test "unescape error unterminated" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(EscapeError.UnterminatedEscape, unescape(allocator, "\\"));
}

test "unescape error invalid escape" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(EscapeError.InvalidEscape, unescape(allocator, "\\q"));
}

test "escapeHtml" {
    const allocator = std.testing.allocator;
    const out = try escapeHtml(allocator, "<script>");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("&lt;script&gt;", out);
}

test "escapeHtml ampersand" {
    const allocator = std.testing.allocator;
    const out = try escapeHtml(allocator, "a & b");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("a &amp; b", out);
}

test "escapeHtml quotes" {
    const allocator = std.testing.allocator;
    const out = try escapeHtml(allocator, "\"quoted\"");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("&quot;quoted&quot;", out);
}

test "unescapeHtml basic" {
    const allocator = std.testing.allocator;
    const out = try unescapeHtml(allocator, "&lt;script&gt;");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("<script>", out);
}

test "unescapeHtml ampersand" {
    const allocator = std.testing.allocator;
    const out = try unescapeHtml(allocator, "a &amp; b");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("a & b", out);
}

test "unescapeHtml numeric" {
    const allocator = std.testing.allocator;
    const out = try unescapeHtml(allocator, "&#65;");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("A", out);
}

test "unescapeHtml hex numeric" {
    const allocator = std.testing.allocator;
    const out = try unescapeHtml(allocator, "&#x41;");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("A", out);
}

test "unescapeHtml unknown entity preserved" {
    const allocator = std.testing.allocator;
    const out = try unescapeHtml(allocator, "&unknown;");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("&unknown;", out);
}

test "isEscaped" {
    try std.testing.expect(!isEscaped("a", 0));
    try std.testing.expect(!isEscaped("ab", 1));
    try std.testing.expect(isEscaped("a\\b", 2));
    try std.testing.expect(!isEscaped("a\\\\b", 3));
}

test "round trip escape/unescape" {
    const allocator = std.testing.allocator;
    const original = "hello\nworld\t\"quoted\"";
    const escaped = try escapeNoQuotes(allocator, original);
    defer allocator.free(escaped);
    const back = try unescape(allocator, escaped);
    defer allocator.free(back);
    try std.testing.expectEqualStrings(original, back);
}
