const std = @import("std");
const token = @import("token.zig");
const position = @import("position.zig");
const unicode = @import("unicode.zig");
const scanner_mod = @import("scanner.zig");

pub const Token = token.Token;
pub const Kind = token.Kind;
pub const Position = position.Position;
pub const Span = position.Span;

pub const LexError = error{
    OutOfMemory,
    UnexpectedCharacter,
    UnterminatedString,
    UnterminatedTemplate,
    UnterminatedRegex,
    UnterminatedComment,
    InvalidEscape,
    InvalidNumericLiteral,
    InvalidUnicodeEscape,
    InvalidHexEscape,
    InvalidIdentifierStart,
    InvalidDecimalDigit,
    InvalidBigInt,
    LegacyOctalNotAllowed,
    OctalEscapeNotAllowed,
    IdentifierAfterNumericLiteral,
    MultipleDecimalPoints,
    UnexpectedToken,
};

pub const Options = struct {
    allow_templates: bool = true,
    allow_regex: bool = true,
    allow_bigint: bool = true,
    strict_mode: bool = false,
    jsx_mode: bool = false,
};

pub const Lexer = struct {
    scanner: scanner_mod.Scanner,
    options: Options,
    last_token_end: u32,
    newline_before: bool,
    allocator: std.mem.Allocator,
    temp_buf: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{
            .scanner = scanner_mod.Scanner.init(source),
            .options = .{},
            .last_token_end = 0,
            .newline_before = false,
            .allocator = allocator,
            .temp_buf = .empty,
        };
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        source: []const u8,
        options: Options,
    ) Lexer {
        return .{
            .scanner = scanner_mod.Scanner.init(source),
            .options = options,
            .last_token_end = 0,
            .newline_before = false,
            .allocator = allocator,
            .temp_buf = .empty,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.temp_buf.deinit(self.allocator);
    }

    pub fn next(self: *Lexer) LexError!Token {
        try self.skipTrivia();

        const start_pos = self.scanner.currentPosition();
        const start_index = self.scanner.index;

        if (self.scanner.atEnd()) {
            return self.makeToken(.eof, start_index, start_pos, self.newline_before);
        }

        const c = self.scanner.current();

        if (unicode.isIdentifierStart(c) and c < 0x80) {
            return self.scanIdentifier(start_index, start_pos);
        }

        if (c == '\\') {
            return self.scanIdentifierWithEscape(start_index, start_pos);
        }

        if (c >= '0' and c <= '9') {
            return self.scanNumber(start_index, start_pos);
        }

        if (c == '"' or c == '\'') {
            return self.scanString(start_index, start_pos, c);
        }

        if (c == '`') {
            if (!self.options.allow_templates) return LexError.UnexpectedCharacter;
            return self.scanTemplate(start_index, start_pos);
        }

        if (c == '#') {
            return self.scanPrivateIdentifier(start_index, start_pos);
        }

        return self.scanPunctuation(start_index, start_pos);
    }

    pub fn peek(self: *Lexer) LexError!Token {
        const saved_scanner = self.scanner;
        const saved_end = self.last_token_end;
        const saved_newline = self.newline_before;

        const tok = try self.next();

        self.scanner = saved_scanner;
        self.last_token_end = saved_end;
        self.newline_before = saved_newline;

        return tok;
    }

    pub fn reset(self: *Lexer) void {
        self.scanner.reset();
        self.last_token_end = 0;
        self.newline_before = false;
    }

    fn skipTrivia(self: *Lexer) LexError!void {
        self.newline_before = false;
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            switch (c) {
                ' ', '\t', 0x0B, 0x0C => {
                    _ = self.scanner.advance();
                },
                '\n', '\r' => {
                    self.newline_before = true;
                    self.scanner.advanceNewline();
                },
                '/' => {
                    const next = self.scanner.peekAt(1);
                    if (next == '/') {
                        self.scanner.skipInlineComment();
                    } else if (next == '*') {
                        const before_line = self.scanner.pos.line;
                        _ = self.scanner.skipBlockComment();
                        if (self.scanner.pos.line > before_line) {
                            self.newline_before = true;
                        }
                    } else {
                        return;
                    }
                },
                0xEF => {
                    if (self.scanner.peekAt(1) == 0xBB and self.scanner.peekAt(2) == 0xBF) {
                        self.scanner.advanceAscii(3);
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn makeToken(
        self: *Lexer,
        kind: Kind,
        start_index: u32,
        start_pos: Position,
        newline: bool,
    ) Token {
        _ = start_pos;
        const text = self.scanner.sourceSlice(start_index, self.scanner.index);
        var flags: u16 = 0;
        if (newline) flags |= token.NEWLINE_FLAG;
        const end_pos = self.scanner.currentPosition();
        const tok = Token{
            .kind = kind,
            .text = text,
            .line = end_pos.line,
            .column = end_pos.column,
            .offset = start_index,
            .flags = flags,
        };
        self.last_token_end = self.scanner.index;
        return tok;
    }

    fn makeTokenWithFlags(
        self: *Lexer,
        kind: Kind,
        start_index: u32,
        newline: bool,
        extra_flags: u16,
    ) Token {
        const text = self.scanner.sourceSlice(start_index, self.scanner.index);
        var flags: u16 = extra_flags;
        if (newline) flags |= token.NEWLINE_FLAG;
        const end_pos = self.scanner.currentPosition();
        const tok = Token{
            .kind = kind,
            .text = text,
            .line = end_pos.line,
            .column = end_pos.column,
            .offset = start_index,
            .flags = flags,
        };
        self.last_token_end = self.scanner.index;
        return tok;
    }

    fn scanIdentifier(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        _ = self.scanner.advance();
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c < 0x80) {
                if (unicode.isIdentifierContinue(c)) {
                    _ = self.scanner.advance();
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        const text = self.scanner.sourceSlice(start_index, self.scanner.index);

        if (token.lookupKeyword(text)) |kw| {
            return self.makeToken(kw, start_index, start_pos, self.newline_before);
        }

        if (token.lookupContextualKeyword(text)) |kw| {
            return self.makeToken(kw, start_index, start_pos, self.newline_before);
        }

        return self.makeToken(.identifier, start_index, start_pos, self.newline_before);
    }

    fn scanIdentifierWithEscape(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        _ = start_pos;
        const cp = try self.scanUnicodeEscape();
        if (!unicode.isIdentifierStart(cp)) return LexError.InvalidIdentifierStart;

        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c < 0x80) {
                if (unicode.isIdentifierContinue(c)) {
                    _ = self.scanner.advance();
                } else if (c == '\\') {
                    const next_cp = try self.scanUnicodeEscape();
                    if (!unicode.isIdentifierContinue(next_cp)) return LexError.InvalidIdentifierStart;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return self.makeTokenWithFlags(.identifier, start_index, self.newline_before, token.HAS_ESCAPE_FLAG);
    }

    fn scanPrivateIdentifier(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        _ = self.scanner.advance();
        if (self.scanner.atEnd()) return LexError.UnexpectedCharacter;
        const c = self.scanner.current();
        if (!unicode.isIdentifierStart(c) and c < 0x80) return LexError.InvalidIdentifierStart;

        while (!self.scanner.atEnd()) {
            const ch = self.scanner.current();
            if (ch < 0x80 and unicode.isIdentifierContinue(ch)) {
                _ = self.scanner.advance();
            } else {
                break;
            }
        }

        return self.makeToken(.private_identifier, start_index, start_pos, self.newline_before);
    }

    fn scanNumber(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        const first = self.scanner.current();

        if (first == '0') {
            const second = self.scanner.peekAt(1);
            if (second == 'x' or second == 'X') {
                return self.scanHexNumber(start_index, start_pos);
            }
            if (second == 'o' or second == 'O') {
                return self.scanOctalNumber(start_index, start_pos);
            }
            if (second == 'b' or second == 'B') {
                return self.scanBinaryNumber(start_index, start_pos);
            }
        }

        return self.scanDecimalNumber(start_index, start_pos);
    }

    fn scanHexNumber(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        self.scanner.advanceAscii(2);
        var has_digits = false;
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (unicode.isHexDigit(c)) {
                has_digits = true;
                _ = self.scanner.advance();
            } else if (c == '_') {
                _ = self.scanner.advance();
            } else {
                break;
            }
        }
        if (!has_digits) return LexError.InvalidNumericLiteral;

        if (self.scanner.peek() == 'n') {
            if (!self.options.allow_bigint) return LexError.InvalidBigInt;
            _ = self.scanner.advance();
            return self.makeToken(.bigint, start_index, start_pos, self.newline_before);
        }

        return self.makeToken(.number, start_index, start_pos, self.newline_before);
    }

    fn scanOctalNumber(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        self.scanner.advanceAscii(2);
        var has_digits = false;
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c >= '0' and c <= '7') {
                has_digits = true;
                _ = self.scanner.advance();
            } else if (c == '_') {
                _ = self.scanner.advance();
            } else {
                break;
            }
        }
        if (!has_digits) return LexError.InvalidNumericLiteral;

        if (self.scanner.peek() == 'n') {
            if (!self.options.allow_bigint) return LexError.InvalidBigInt;
            _ = self.scanner.advance();
            return self.makeToken(.bigint, start_index, start_pos, self.newline_before);
        }

        return self.makeToken(.number, start_index, start_pos, self.newline_before);
    }

    fn scanBinaryNumber(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        self.scanner.advanceAscii(2);
        var has_digits = false;
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c == '0' or c == '1') {
                has_digits = true;
                _ = self.scanner.advance();
            } else if (c == '_') {
                _ = self.scanner.advance();
            } else {
                break;
            }
        }
        if (!has_digits) return LexError.InvalidNumericLiteral;

        if (self.scanner.peek() == 'n') {
            if (!self.options.allow_bigint) return LexError.InvalidBigInt;
            _ = self.scanner.advance();
            return self.makeToken(.bigint, start_index, start_pos, self.newline_before);
        }

        return self.makeToken(.number, start_index, start_pos, self.newline_before);
    }

    fn scanDecimalNumber(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c >= '0' and c <= '9') {
                _ = self.scanner.advance();
            } else if (c == '_') {
                _ = self.scanner.advance();
            } else {
                break;
            }
        }

        if (self.scanner.peek() == '.') {
            _ = self.scanner.advance();
            while (!self.scanner.atEnd()) {
                const c = self.scanner.current();
                if (c >= '0' and c <= '9') {
                    _ = self.scanner.advance();
                } else if (c == '_') {
                    _ = self.scanner.advance();
                } else {
                    break;
                }
            }
        }

        const next_c = self.scanner.peek();
        if (next_c == 'e' or next_c == 'E') {
            _ = self.scanner.advance();
            const sign = self.scanner.peek();
            if (sign == '+' or sign == '-') {
                _ = self.scanner.advance();
            }
            var has_exp_digits = false;
            while (!self.scanner.atEnd()) {
                const c = self.scanner.current();
                if (c >= '0' and c <= '9') {
                    has_exp_digits = true;
                    _ = self.scanner.advance();
                } else if (c == '_') {
                    _ = self.scanner.advance();
                } else {
                    break;
                }
            }
            if (!has_exp_digits) return LexError.InvalidNumericLiteral;
        }

        if (self.scanner.peek() == 'n') {
            if (!self.options.allow_bigint) return LexError.InvalidBigInt;
            _ = self.scanner.advance();
            return self.makeToken(.bigint, start_index, start_pos, self.newline_before);
        }

        if (self.scanner.peekIsLetter()) {
            return LexError.IdentifierAfterNumericLiteral;
        }

        return self.makeToken(.number, start_index, start_pos, self.newline_before);
    }

    fn scanString(self: *Lexer, start_index: u32, start_pos: Position, quote: u8) LexError!Token {
        _ = self.scanner.advance();
        var has_escape = false;

        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c == quote) {
                _ = self.scanner.advance();
                const flags: u16 = if (has_escape) token.HAS_ESCAPE_FLAG else 0;
                return self.makeTokenWithFlags(.string, start_index, self.newline_before, flags);
            }
            if (c == '\\') {
                has_escape = true;
                _ = self.scanner.advance();
                if (self.scanner.atEnd()) return LexError.UnterminatedString;
                _ = self.scanner.advance();
                continue;
            }
            if (c == '\n' or c == '\r') {
                return LexError.UnterminatedString;
            }
            _ = self.scanner.advance();
        }

        return LexError.UnterminatedString;
    }

    fn scanTemplate(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        _ = self.scanner.advance();

        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c == '`') {
                _ = self.scanner.advance();
                return self.makeToken(.template_string, start_index, start_pos, self.newline_before);
            }
            if (c == '\\') {
                _ = self.scanner.advance();
                if (!self.scanner.atEnd()) _ = self.scanner.advance();
                continue;
            }
            if (c == '$' and self.scanner.peekAt(1) == '{') {
                self.scanner.advanceAscii(2);
                return self.makeToken(.template_head, start_index, start_pos, self.newline_before);
            }
            if (c == '\n' or c == '\r') {
                self.scanner.advanceNewline();
            } else {
                _ = self.scanner.advance();
            }
        }

        return LexError.UnterminatedTemplate;
    }

    fn scanUnicodeEscape(self: *Lexer) LexError!u21 {
        if (self.scanner.peek() != '\\') return LexError.InvalidUnicodeEscape;
        _ = self.scanner.advance();
        if (self.scanner.peek() != 'u') return LexError.InvalidUnicodeEscape;
        _ = self.scanner.advance();

        if (self.scanner.peek() == '{') {
            _ = self.scanner.advance();
            var value: u32 = 0;
            var count: u32 = 0;
            while (!self.scanner.atEnd()) {
                const c = self.scanner.current();
                if (c == '}') {
                    _ = self.scanner.advance();
                    if (count == 0) return LexError.InvalidUnicodeEscape;
                    if (value > 0x10FFFF) return LexError.InvalidUnicodeEscape;
                    return @intCast(value);
                }
                const digit = unicode.hexValue(c) orelse return LexError.InvalidHexEscape;
                value = value * 16 + digit;
                count += 1;
                if (count > 6) return LexError.InvalidUnicodeEscape;
                _ = self.scanner.advance();
            }
            return LexError.InvalidUnicodeEscape;
        }

        var value: u32 = 0;
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            const c = self.scanner.current();
            const digit = unicode.hexValue(c) orelse return LexError.InvalidHexEscape;
            value = value * 16 + digit;
            _ = self.scanner.advance();
        }
        return @intCast(value);
    }

    fn scanRegex(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        _ = self.scanner.advance();

        var in_class = false;
        while (!self.scanner.atEnd()) {
            const c = self.scanner.current();
            if (c == '\\') {
                _ = self.scanner.advance();
                if (!self.scanner.atEnd()) _ = self.scanner.advance();
                continue;
            }
            if (c == '\n' or c == '\r') return LexError.UnterminatedRegex;
            if (c == '[') in_class = true;
            if (c == ']') in_class = false;
            if (c == '/' and !in_class) {
                _ = self.scanner.advance();
                while (!self.scanner.atEnd()) {
                    const f = self.scanner.current();
                    if ((f >= 'a' and f <= 'z') or (f >= 'A' and f <= 'Z')) {
                        _ = self.scanner.advance();
                    } else {
                        break;
                    }
                }
                return self.makeToken(.regex, start_index, start_pos, self.newline_before);
            }
            _ = self.scanner.advance();
        }

        return LexError.UnterminatedRegex;
    }

    fn scanPunctuation(self: *Lexer, start_index: u32, start_pos: Position) LexError!Token {
        const c = self.scanner.current();

        switch (c) {
            '{' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_lbrace, start_index, start_pos, self.newline_before);
            },
            '}' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_rbrace, start_index, start_pos, self.newline_before);
            },
            '(' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_lparen, start_index, start_pos, self.newline_before);
            },
            ')' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_rparen, start_index, start_pos, self.newline_before);
            },
            '[' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_lbracket, start_index, start_pos, self.newline_before);
            },
            ']' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_rbracket, start_index, start_pos, self.newline_before);
            },
            ';' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_semicolon, start_index, start_pos, self.newline_before);
            },
            ',' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_comma, start_index, start_pos, self.newline_before);
            },
            ':' => {
                _ = self.scanner.advance();
                return self.makeToken(.punct_colon, start_index, start_pos, self.newline_before);
            },
            '~' => {
                _ = self.scanner.advance();
                return self.makeToken(.op_bit_not, start_index, start_pos, self.newline_before);
            },
            '.' => {
                if (self.scanner.peekAt(1) == '.' and self.scanner.peekAt(2) == '.') {
                    self.scanner.advanceAscii(3);
                    return self.makeToken(.punct_ellipsis, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.punct_dot, start_index, start_pos, self.newline_before);
            },
            '?' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '?') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_nullish_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_nullish, start_index, start_pos, self.newline_before);
                }
                if (n1 == '.') {
                    const n2 = self.scanner.peekAt(2);
                    if (n2 >= '0' and n2 <= '9') {
                        _ = self.scanner.advance();
                        return self.makeToken(.punct_question, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.punct_question_dot, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.punct_question, start_index, start_pos, self.newline_before);
            },
            '+' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '+') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_increment, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_add_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_add, start_index, start_pos, self.newline_before);
            },
            '-' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '-') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_decrement, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_sub_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_sub, start_index, start_pos, self.newline_before);
            },
            '*' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '*') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_exp_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_exp, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_mul_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_mul, start_index, start_pos, self.newline_before);
            },
            '/' => {
                if (self.scanner.peekAt(1) == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_div_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_div, start_index, start_pos, self.newline_before);
            },
            '%' => {
                if (self.scanner.peekAt(1) == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_mod_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_mod, start_index, start_pos, self.newline_before);
            },
            '=' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '=') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_strict_eq, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_eq, start_index, start_pos, self.newline_before);
                }
                if (n1 == '>') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.punct_arrow, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_assign, start_index, start_pos, self.newline_before);
            },
            '!' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '=') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_strict_neq, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_neq, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_not, start_index, start_pos, self.newline_before);
            },
            '<' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '<') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_shl_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_shl, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_lte, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_lt, start_index, start_pos, self.newline_before);
            },
            '>' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '>') {
                    const n2 = self.scanner.peekAt(2);
                    if (n2 == '>') {
                        if (self.scanner.peekAt(3) == '=') {
                            self.scanner.advanceAscii(4);
                            return self.makeToken(.op_ushr_assign, start_index, start_pos, self.newline_before);
                        }
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_ushr, start_index, start_pos, self.newline_before);
                    }
                    if (n2 == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_shr_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_shr, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_gte, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_gt, start_index, start_pos, self.newline_before);
            },
            '&' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '&') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_and_and_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_and_and, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_and_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_bit_and, start_index, start_pos, self.newline_before);
            },
            '|' => {
                const n1 = self.scanner.peekAt(1);
                if (n1 == '|') {
                    if (self.scanner.peekAt(2) == '=') {
                        self.scanner.advanceAscii(3);
                        return self.makeToken(.op_or_or_assign, start_index, start_pos, self.newline_before);
                    }
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_or_or, start_index, start_pos, self.newline_before);
                }
                if (n1 == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_or_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_bit_or, start_index, start_pos, self.newline_before);
            },
            '^' => {
                if (self.scanner.peekAt(1) == '=') {
                    self.scanner.advanceAscii(2);
                    return self.makeToken(.op_xor_assign, start_index, start_pos, self.newline_before);
                }
                _ = self.scanner.advance();
                return self.makeToken(.op_bit_xor, start_index, start_pos, self.newline_before);
            },
            else => return LexError.UnexpectedCharacter,
        }
    }
};

pub fn tokenizeAll(
    allocator: std.mem.Allocator,
    source: []const u8,
) LexError![]Token {
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    var list: std.ArrayList(Token) = .empty;
    errdefer list.deinit(allocator);

    while (true) {
        const tok = try lexer.next();
        try list.append(allocator, tok);
        if (tok.kind == .eof) break;
    }

    return list.toOwnedSlice(allocator);
}

test "Lexer empty source" {
    var lexer = Lexer.init(std.testing.allocator, "");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.eof, tok.kind);
}

test "Lexer whitespace only" {
    var lexer = Lexer.init(std.testing.allocator, "   ");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.eof, tok.kind);
}

test "Lexer simple identifier" {
    var lexer = Lexer.init(std.testing.allocator, "foo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
    try std.testing.expectEqualStrings("foo", tok.text);
}

test "Lexer identifier with underscore" {
    var lexer = Lexer.init(std.testing.allocator, "_foo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
    try std.testing.expectEqualStrings("_foo", tok.text);
}

test "Lexer identifier with dollar" {
    var lexer = Lexer.init(std.testing.allocator, "$x");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
}

test "Lexer keyword" {
    var lexer = Lexer.init(std.testing.allocator, "function");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.keyword_function, tok.kind);
}

test "Lexer number integer" {
    var lexer = Lexer.init(std.testing.allocator, "42");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.number, tok.kind);
    try std.testing.expectEqualStrings("42", tok.text);
}

test "Lexer number float" {
    var lexer = Lexer.init(std.testing.allocator, "3.14");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.number, tok.kind);
    try std.testing.expectEqualStrings("3.14", tok.text);
}

test "Lexer number hex" {
    var lexer = Lexer.init(std.testing.allocator, "0xff");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.number, tok.kind);
}

test "Lexer number exponent" {
    var lexer = Lexer.init(std.testing.allocator, "1e10");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.number, tok.kind);
}

test "Lexer bigint" {
    var lexer = Lexer.init(std.testing.allocator, "42n");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.bigint, tok.kind);
}

test "Lexer string single quotes" {
    var lexer = Lexer.init(std.testing.allocator, "'hello'");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.string, tok.kind);
    try std.testing.expectEqualStrings("'hello'", tok.text);
}

test "Lexer string double quotes" {
    var lexer = Lexer.init(std.testing.allocator, "\"world\"");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.string, tok.kind);
}

test "Lexer template string" {
    var lexer = Lexer.init(std.testing.allocator, "`simple`");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.template_string, tok.kind);
}

test "Lexer template head" {
    var lexer = Lexer.init(std.testing.allocator, "`hello ${");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.template_head, tok.kind);
}

test "Lexer punctuation lbrace" {
    var lexer = Lexer.init(std.testing.allocator, "{");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.punct_lbrace, tok.kind);
}

test "Lexer punctuation semicolon" {
    var lexer = Lexer.init(std.testing.allocator, ";");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.punct_semicolon, tok.kind);
}

test "Lexer operator add" {
    var lexer = Lexer.init(std.testing.allocator, "+");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.op_add, tok.kind);
}

test "Lexer operator increment" {
    var lexer = Lexer.init(std.testing.allocator, "++");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.op_increment, tok.kind);
}

test "Lexer operator strict eq" {
    var lexer = Lexer.init(std.testing.allocator, "===");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.op_strict_eq, tok.kind);
}

test "Lexer operator nullish" {
    var lexer = Lexer.init(std.testing.allocator, "??");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.op_nullish, tok.kind);
}

test "Lexer operator nullish assign" {
    var lexer = Lexer.init(std.testing.allocator, "??=");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.op_nullish_assign, tok.kind);
}

test "Lexer operator arrow" {
    var lexer = Lexer.init(std.testing.allocator, "=>");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.punct_arrow, tok.kind);
}

test "Lexer operator optional chaining" {
    var lexer = Lexer.init(std.testing.allocator, "?.");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.punct_question_dot, tok.kind);
}

test "Lexer operator spread" {
    var lexer = Lexer.init(std.testing.allocator, "...");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.punct_ellipsis, tok.kind);
}

test "Lexer whitespace skipped" {
    var lexer = Lexer.init(std.testing.allocator, "   foo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
    try std.testing.expectEqualStrings("foo", tok.text);
}

test "Lexer newline flag" {
    var lexer = Lexer.init(std.testing.allocator, "\nfoo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expect(tok.hasNewlineBefore());
}

test "Lexer line comment" {
    var lexer = Lexer.init(std.testing.allocator, "// comment\nfoo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
    try std.testing.expect(tok.hasNewlineBefore());
}

test "Lexer block comment" {
    var lexer = Lexer.init(std.testing.allocator, "/* comment */ foo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
}

test "Lexer multiple tokens" {
    var lexer = Lexer.init(std.testing.allocator, "let x = 42;");
    defer lexer.deinit();

    const t1 = try lexer.next();
    try std.testing.expectEqual(Kind.keyword_let, t1.kind);

    const t2 = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, t2.kind);

    const t3 = try lexer.next();
    try std.testing.expectEqual(Kind.op_assign, t3.kind);

    const t4 = try lexer.next();
    try std.testing.expectEqual(Kind.number, t4.kind);

    const t5 = try lexer.next();
    try std.testing.expectEqual(Kind.punct_semicolon, t5.kind);

    const t6 = try lexer.next();
    try std.testing.expectEqual(Kind.eof, t6.kind);
}

test "Lexer unterminated string" {
    var lexer = Lexer.init(std.testing.allocator, "\"hello");
    defer lexer.deinit();
    try std.testing.expectError(LexError.UnterminatedString, lexer.next());
}

test "Lexer unexpected character" {
    var lexer = Lexer.init(std.testing.allocator, "@");
    defer lexer.deinit();
    try std.testing.expectError(LexError.UnexpectedCharacter, lexer.next());
}

test "Lexer peek does not advance" {
    var lexer = Lexer.init(std.testing.allocator, "foo bar");
    defer lexer.deinit();

    const peeked = try lexer.peek();
    try std.testing.expectEqual(Kind.identifier, peeked.kind);
    try std.testing.expectEqualStrings("foo", peeked.text);

    const actual = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, actual.kind);
    try std.testing.expectEqualStrings("foo", actual.text);
}

test "Lexer tokenizeAll" {
    const toks = try tokenizeAll(std.testing.allocator, "let x = 1;");
    defer std.testing.allocator.free(toks);

    try std.testing.expectEqual(@as(usize, 6), toks.len);
    try std.testing.expectEqual(Kind.keyword_let, toks[0].kind);
    try std.testing.expectEqual(Kind.eof, toks[5].kind);
}

test "Lexer string with escape flag" {
    var lexer = Lexer.init(std.testing.allocator, "'a\\nb'");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expect(tok.hasEscape());
}

test "Lexer identifier escapes" {
    var lexer = Lexer.init(std.testing.allocator, "\\u0061bc");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.identifier, tok.kind);
    try std.testing.expect(tok.hasEscape());
}

test "Lexer private identifier" {
    var lexer = Lexer.init(std.testing.allocator, "#foo");
    defer lexer.deinit();
    const tok = try lexer.next();
    try std.testing.expectEqual(Kind.private_identifier, tok.kind);
}

test "Lexer operators all" {
    const cases = [_]struct { []const u8, Kind }{
        .{ "+", .op_add },
        .{ "-", .op_sub },
        .{ "*", .op_mul },
        .{ "/", .op_div },
        .{ "%", .op_mod },
        .{ "**", .op_exp },
        .{ "=", .op_assign },
        .{ "==", .op_eq },
        .{ "===", .op_strict_eq },
        .{ "!=", .op_neq },
        .{ "!==", .op_strict_neq },
        .{ "<", .op_lt },
        .{ ">", .op_gt },
        .{ "<=", .op_lte },
        .{ ">=", .op_gte },
        .{ "&&", .op_and_and },
        .{ "||", .op_or_or },
        .{ "??", .op_nullish },
        .{ "!", .op_not },
        .{ "&", .op_bit_and },
        .{ "|", .op_bit_or },
        .{ "^", .op_bit_xor },
        .{ "~", .op_bit_not },
        .{ "<<", .op_shl },
        .{ ">>", .op_shr },
        .{ ">>>", .op_ushr },
        .{ "+=", .op_add_assign },
        .{ "-=", .op_sub_assign },
        .{ "*=", .op_mul_assign },
        .{ "/=", .op_div_assign },
        .{ "%=", .op_mod_assign },
        .{ "**=", .op_exp_assign },
        .{ "&=", .op_and_assign },
        .{ "|=", .op_or_assign },
        .{ "^=", .op_xor_assign },
        .{ "<<=", .op_shl_assign },
        .{ ">>=", .op_shr_assign },
        .{ ">>>=", .op_ushr_assign },
        .{ "&&=", .op_and_and_assign },
        .{ "||=", .op_or_or_assign },
        .{ "??=", .op_nullish_assign },
    };

    for (cases) |case| {
        var lexer = Lexer.init(std.testing.allocator, case[0]);
        defer lexer.deinit();
        const tok = try lexer.next();
        try std.testing.expectEqual(case[1], tok.kind);
    }
}
