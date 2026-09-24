const std = @import("std");

pub fn isWhitespace(cp: u21) bool {
    return switch (cp) {
        0x0009, 0x000B, 0x000C, 0x0020, 0x00A0, 0xFEFF => true,
        0x1680 => true,
        0x2000...0x200A => true,
        0x202F => true,
        0x205F => true,
        0x3000 => true,
        else => false,
    };
}

pub fn isLineTerminator(cp: u21) bool {
    return switch (cp) {
        0x000A, 0x000D, 0x2028, 0x2029 => true,
        else => false,
    };
}

pub fn isDecimalDigit(cp: u21) bool {
    return cp >= '0' and cp <= '9';
}

pub fn isBinaryDigit(cp: u21) bool {
    return cp == '0' or cp == '1';
}

pub fn isOctalDigit(cp: u21) bool {
    return cp >= '0' and cp <= '7';
}

pub fn isHexDigit(cp: u21) bool {
    return (cp >= '0' and cp <= '9') or
        (cp >= 'a' and cp <= 'f') or
        (cp >= 'A' and cp <= 'F');
}

pub fn hexValue(cp: u21) ?u8 {
    if (cp >= '0' and cp <= '9') return @intCast(cp - '0');
    if (cp >= 'a' and cp <= 'f') return @intCast(cp - 'a' + 10);
    if (cp >= 'A' and cp <= 'F') return @intCast(cp - 'A' + 10);
    return null;
}

pub fn isAsciiLetter(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z');
}

pub fn isIdentifierStart(cp: u21) bool {
    if (isAsciiLetter(cp)) return true;
    if (cp == '$' or cp == '_') return true;
    if (cp < 0x80) return false;

    if (cp >= 0x00AA and cp <= 0x00AA) return true;
    if (cp >= 0x00B5 and cp <= 0x00B5) return true;
    if (cp >= 0x00BA and cp <= 0x00BA) return true;
    if (cp >= 0x00C0 and cp <= 0x00D6) return true;
    if (cp >= 0x00D8 and cp <= 0x00F6) return true;
    if (cp >= 0x00F8 and cp <= 0x02FF) return true;
    if (cp >= 0x0370 and cp <= 0x167F) return true;
    if (cp >= 0x1681 and cp <= 0x180D) return true;
    if (cp >= 0x180F and cp <= 0x1FFF) return true;
    if (cp >= 0x200B and cp <= 0x200D) return true;
    if (cp >= 0x202A and cp <= 0x202E) return true;
    if (cp >= 0x203F and cp <= 0x2040) return true;
    if (cp >= 0x2054 and cp <= 0x2054) return true;
    if (cp >= 0x2060 and cp <= 0x206F) return true;
    if (cp >= 0x2070 and cp <= 0x218F) return true;
    if (cp >= 0x2460 and cp <= 0x24FF) return true;
    if (cp >= 0x2776 and cp <= 0x2793) return true;
    if (cp >= 0x2C00 and cp <= 0x2DFF) return true;
    if (cp >= 0x2E80 and cp <= 0x2FFF) return true;
    if (cp >= 0x3004 and cp <= 0x3007) return true;
    if (cp >= 0x3021 and cp <= 0x302F) return true;
    if (cp >= 0x3031 and cp <= 0x303F) return true;
    if (cp >= 0x3040 and cp <= 0xD7FF) return true;
    if (cp >= 0xF900 and cp <= 0xFD3D) return true;
    if (cp >= 0xFD40 and cp <= 0xFDCF) return true;
    if (cp >= 0xFDF0 and cp <= 0xFE1F) return true;
    if (cp >= 0xFE30 and cp <= 0xFE44) return true;
    if (cp >= 0xFE47 and cp <= 0xFFFD) return true;
    if (cp >= 0x10000 and cp <= 0x1FFFD) return true;
    if (cp >= 0x20000 and cp <= 0x2FFFD) return true;
    if (cp >= 0x30000 and cp <= 0x3FFFD) return true;
    if (cp >= 0x40000 and cp <= 0x4FFFD) return true;
    if (cp >= 0x50000 and cp <= 0x5FFFD) return true;
    if (cp >= 0x60000 and cp <= 0x6FFFD) return true;
    if (cp >= 0x70000 and cp <= 0x7FFFD) return true;
    if (cp >= 0x80000 and cp <= 0x8FFFD) return true;
    if (cp >= 0x90000 and cp <= 0x9FFFD) return true;
    if (cp >= 0xA0000 and cp <= 0xAFFFD) return true;
    if (cp >= 0xB0000 and cp <= 0xBFFFD) return true;
    if (cp >= 0xC0000 and cp <= 0xCFFFD) return true;
    if (cp >= 0xD0000 and cp <= 0xDFFFD) return true;
    if (cp >= 0xE0000 and cp <= 0xEFFFD) return true;
    return false;
}

pub fn isIdentifierContinue(cp: u21) bool {
    if (isIdentifierStart(cp)) return true;
    if (isDecimalDigit(cp)) return true;

    if (cp == 0x200C or cp == 0x200D) return true;
    if (cp >= 0x0300 and cp <= 0x036F) return true;
    if (cp >= 0x0483 and cp <= 0x0487) return true;
    if (cp >= 0x0591 and cp <= 0x05BD) return true;
    if (cp == 0x05BF) return true;
    if (cp >= 0x05C1 and cp <= 0x05C2) return true;
    if (cp >= 0x05C4 and cp <= 0x05C5) return true;
    if (cp == 0x05C7) return true;
    if (cp >= 0x0610 and cp <= 0x061A) return true;
    if (cp >= 0x064B and cp <= 0x0669) return true;
    if (cp >= 0x0670 and cp <= 0x0670) return true;
    if (cp >= 0x06D6 and cp <= 0x06DC) return true;
    if (cp >= 0x06DF and cp <= 0x06E4) return true;
    if (cp >= 0x06E7 and cp <= 0x06E8) return true;
    if (cp >= 0x06EA and cp <= 0x06ED) return true;
    if (cp >= 0x0711 and cp <= 0x0711) return true;
    if (cp >= 0x0730 and cp <= 0x074A) return true;
    if (cp >= 0x07A6 and cp <= 0x07B0) return true;
    if (cp >= 0x07EB and cp <= 0x07F3) return true;
    if (cp >= 0x0816 and cp <= 0x0819) return true;
    if (cp >= 0x081B and cp <= 0x0823) return true;
    if (cp >= 0x0825 and cp <= 0x0827) return true;
    if (cp >= 0x0829 and cp <= 0x082D) return true;
    if (cp >= 0x0859 and cp <= 0x085B) return true;
    if (cp >= 0x08E3 and cp <= 0x0903) return true;
    if (cp >= 0x093A and cp <= 0x093C) return true;
    if (cp >= 0x093E and cp <= 0x094F) return true;
    if (cp >= 0x0951 and cp <= 0x0957) return true;
    if (cp >= 0x0962 and cp <= 0x0963) return true;
    if (cp >= 0x0981 and cp <= 0x0983) return true;
    if (cp >= 0x09BC and cp <= 0x09BC) return true;
    if (cp >= 0x09BE and cp <= 0x09C4) return true;
    if (cp >= 0x09C7 and cp <= 0x09C8) return true;
    if (cp >= 0x09CB and cp <= 0x09CD) return true;
    if (cp >= 0x09D7 and cp <= 0x09D7) return true;
    if (cp >= 0x09E2 and cp <= 0x09E3) return true;
    if (cp >= 0x0A01 and cp <= 0x0A03) return true;
    if (cp >= 0x0A3C and cp <= 0x0A3C) return true;
    if (cp >= 0x0A3E and cp <= 0x0A42) return true;
    if (cp >= 0x0A47 and cp <= 0x0A48) return true;
    if (cp >= 0x0A4B and cp <= 0x0A4D) return true;
    if (cp >= 0x0A51 and cp <= 0x0A51) return true;
    if (cp >= 0x0A70 and cp <= 0x0A71) return true;
    if (cp >= 0x0A75 and cp <= 0x0A75) return true;
    if (cp >= 0x0A81 and cp <= 0x0A83) return true;
    if (cp >= 0x0ABC and cp <= 0x0ABC) return true;
    if (cp >= 0x0ABE and cp <= 0x0AC5) return true;
    if (cp >= 0x0AC7 and cp <= 0x0AC9) return true;
    if (cp >= 0x0ACB and cp <= 0x0ACD) return true;
    if (cp >= 0x0AE2 and cp <= 0x0AE3) return true;
    if (cp >= 0x0B01 and cp <= 0x0B03) return true;
    if (cp >= 0x0B3C and cp <= 0x0B3C) return true;
    if (cp >= 0x0B3E and cp <= 0x0B44) return true;
    if (cp >= 0x0B47 and cp <= 0x0B48) return true;
    if (cp >= 0x0B4B and cp <= 0x0B4D) return true;
    if (cp >= 0x0B56 and cp <= 0x0B57) return true;
    if (cp >= 0x0B62 and cp <= 0x0B63) return true;
    if (cp >= 0x0B82 and cp <= 0x0B82) return true;
    if (cp >= 0x0BBE and cp <= 0x0BC2) return true;
    if (cp >= 0x0BC6 and cp <= 0x0BC8) return true;
    if (cp >= 0x0BCA and cp <= 0x0BCD) return true;
    if (cp >= 0x0BD7 and cp <= 0x0BD7) return true;
    if (cp >= 0x0C00 and cp <= 0x0C03) return true;
    if (cp >= 0x0C3E and cp <= 0x0C44) return true;
    if (cp >= 0x0C46 and cp <= 0x0C48) return true;
    if (cp >= 0x0C4A and cp <= 0x0C4D) return true;
    if (cp >= 0x0C55 and cp <= 0x0C56) return true;
    if (cp >= 0x0C62 and cp <= 0x0C63) return true;
    if (cp >= 0x0C81 and cp <= 0x0C83) return true;
    if (cp >= 0x0CBC and cp <= 0x0CBC) return true;
    if (cp >= 0x0CBE and cp <= 0x0CC4) return true;
    if (cp >= 0x0CC6 and cp <= 0x0CC8) return true;
    if (cp >= 0x0CCA and cp <= 0x0CCD) return true;
    if (cp >= 0x0CD5 and cp <= 0x0CD6) return true;
    if (cp >= 0x0CE2 and cp <= 0x0CE3) return true;
    if (cp >= 0x0D01 and cp <= 0x0D03) return true;
    if (cp >= 0x0D3E and cp <= 0x0D44) return true;
    if (cp >= 0x0D46 and cp <= 0x0D48) return true;
    if (cp >= 0x0D4A and cp <= 0x0D4D) return true;
    if (cp >= 0x0D57 and cp <= 0x0D57) return true;
    if (cp >= 0x0D62 and cp <= 0x0D63) return true;
    if (cp >= 0x0D82 and cp <= 0x0D83) return true;
    if (cp >= 0x0DCA and cp <= 0x0DCA) return true;
    if (cp >= 0x0DCF and cp <= 0x0DD4) return true;
    if (cp >= 0x0DD6 and cp <= 0x0DD6) return true;
    if (cp >= 0x0DD8 and cp <= 0x0DDF) return true;
    if (cp >= 0x0DF2 and cp <= 0x0DF3) return true;
    if (cp >= 0x0E31 and cp <= 0x0E31) return true;
    if (cp >= 0x0E34 and cp <= 0x0E3A) return true;
    if (cp >= 0x0E47 and cp <= 0x0E4E) return true;
    if (cp >= 0x0EB1 and cp <= 0x0EB1) return true;
    if (cp >= 0x0EB4 and cp <= 0x0EB9) return true;
    if (cp >= 0x0EBB and cp <= 0x0EBC) return true;
    if (cp >= 0x0EC8 and cp <= 0x0ECD) return true;
    if (cp >= 0x0F18 and cp <= 0x0F19) return true;
    if (cp == 0x0F35) return true;
    if (cp == 0x0F37) return true;
    if (cp == 0x0F39) return true;
    if (cp >= 0x0F3E and cp <= 0x0F3F) return true;
    if (cp >= 0x0F71 and cp <= 0x0F84) return true;
    if (cp >= 0x0F86 and cp <= 0x0F87) return true;
    if (cp >= 0x0F8D and cp <= 0x0F97) return true;
    if (cp >= 0x0F99 and cp <= 0x0FBC) return true;
    if (cp == 0x0FC6) return true;
    if (cp >= 0x102B and cp <= 0x103E) return true;
    if (cp >= 0x1056 and cp <= 0x1059) return true;
    if (cp >= 0x105E and cp <= 0x1060) return true;
    if (cp >= 0x1062 and cp <= 0x1064) return true;
    if (cp >= 0x1067 and cp <= 0x106D) return true;
    if (cp >= 0x1071 and cp <= 0x1074) return true;
    if (cp >= 0x1082 and cp <= 0x108D) return true;
    if (cp == 0x108F) return true;
    if (cp >= 0x109A and cp <= 0x109D) return true;
    if (cp >= 0x135D and cp <= 0x135F) return true;
    if (cp >= 0x1712 and cp <= 0x1714) return true;
    if (cp >= 0x1732 and cp <= 0x1734) return true;
    if (cp >= 0x1752 and cp <= 0x1753) return true;
    if (cp >= 0x1772 and cp <= 0x1773) return true;
    if (cp >= 0x17B4 and cp <= 0x17D3) return true;
    if (cp == 0x17DD) return true;
    if (cp >= 0x180B and cp <= 0x180D) return true;
    if (cp == 0x18A9) return true;
    if (cp >= 0x1920 and cp <= 0x192B) return true;
    if (cp >= 0x1930 and cp <= 0x193B) return true;
    if (cp >= 0x1A17 and cp <= 0x1A1B) return true;
    if (cp >= 0x1A55 and cp <= 0x1A5E) return true;
    if (cp >= 0x1A60 and cp <= 0x1A7C) return true;
    if (cp >= 0x1A7F and cp <= 0x1A7F) return true;
    if (cp >= 0x1AB0 and cp <= 0x1ABE) return true;
    if (cp >= 0x1B00 and cp <= 0x1B04) return true;
    if (cp >= 0x1B34 and cp <= 0x1B44) return true;
    if (cp >= 0x1B6B and cp <= 0x1B73) return true;
    if (cp >= 0x1B80 and cp <= 0x1B82) return true;
    if (cp >= 0x1BA1 and cp <= 0x1BAD) return true;
    if (cp >= 0x1BE6 and cp <= 0x1BF3) return true;
    if (cp >= 0x1C24 and cp <= 0x1C37) return true;
    if (cp >= 0x1CD0 and cp <= 0x1CD2) return true;
    if (cp >= 0x1CD4 and cp <= 0x1CE8) return true;
    if (cp == 0x1CED) return true;
    if (cp == 0x1CF4) return true;
    if (cp >= 0x1CF8 and cp <= 0x1CF9) return true;
    if (cp >= 0x1DC0 and cp <= 0x1DF5) return true;
    if (cp >= 0x1DFC and cp <= 0x1DFF) return true;
    if (cp >= 0x20D0 and cp <= 0x20F0) return true;
    if (cp >= 0x2CEF and cp <= 0x2CF1) return true;
    if (cp >= 0x2D7F and cp <= 0x2D7F) return true;
    if (cp >= 0x2DE0 and cp <= 0x2DFF) return true;
    if (cp >= 0x302A and cp <= 0x302F) return true;
    if (cp >= 0x3099 and cp <= 0x309A) return true;
    if (cp >= 0xA66F and cp <= 0xA672) return true;
    if (cp >= 0xA674 and cp <= 0xA67D) return true;
    if (cp >= 0xA69E and cp <= 0xA69F) return true;
    if (cp >= 0xA6F0 and cp <= 0xA6F1) return true;
    if (cp >= 0xA802 and cp <= 0xA802) return true;
    if (cp >= 0xA806 and cp <= 0xA806) return true;
    if (cp >= 0xA80B and cp <= 0xA80B) return true;
    if (cp >= 0xA823 and cp <= 0xA827) return true;
    if (cp >= 0xA880 and cp <= 0xA881) return true;
    if (cp >= 0xA8B4 and cp <= 0xA8C4) return true;
    if (cp >= 0xA8E0 and cp <= 0xA8F1) return true;
    if (cp >= 0xA926 and cp <= 0xA92D) return true;
    if (cp >= 0xA947 and cp <= 0xA953) return true;
    if (cp >= 0xA980 and cp <= 0xA983) return true;
    if (cp >= 0xA9B3 and cp <= 0xA9C0) return true;
    if (cp >= 0xA9E5 and cp <= 0xA9E5) return true;
    if (cp >= 0xAA29 and cp <= 0xAA36) return true;
    if (cp >= 0xAA43 and cp <= 0xAA43) return true;
    if (cp >= 0xAA4C and cp <= 0xAA4D) return true;
    if (cp >= 0xAA7B and cp <= 0xAA7D) return true;
    if (cp >= 0xAAB0 and cp <= 0xAAB0) return true;
    if (cp >= 0xAAB2 and cp <= 0xAAB4) return true;
    if (cp >= 0xAAB7 and cp <= 0xAAB8) return true;
    if (cp >= 0xAABE and cp <= 0xAABF) return true;
    if (cp >= 0xAAC1 and cp <= 0xAAC1) return true;
    if (cp >= 0xAAEB and cp <= 0xAAEF) return true;
    if (cp >= 0xAAF5 and cp <= 0xAAF6) return true;
    if (cp >= 0xABE3 and cp <= 0xABEA) return true;
    if (cp >= 0xABEC and cp <= 0xABED) return true;
    if (cp >= 0xFB1E and cp <= 0xFB1E) return true;
    if (cp >= 0xFE00 and cp <= 0xFE0F) return true;
    if (cp >= 0xFE20 and cp <= 0xFE2F) return true;
    return false;
}

pub fn isUnicodeEscape(cp: u21) bool {
    return cp == 'u';
}

pub fn isOctalEscape(cp: u21) bool {
    return cp >= '0' and cp <= '7';
}

pub fn utf16Length(cp: u21) u2 {
    if (cp < 0x10000) return 1;
    return 2;
}

test "isWhitespace space" {
    try std.testing.expect(isWhitespace(0x20));
    try std.testing.expect(isWhitespace(0x09));
    try std.testing.expect(isWhitespace(0x0A));
    try std.testing.expect(!isWhitespace(0x0A + 100));
}

test "isWhitespace unicode" {
    try std.testing.expect(isWhitespace(0x00A0));
    try std.testing.expect(isWhitespace(0xFEFF));
    try std.testing.expect(isWhitespace(0x3000));
    try std.testing.expect(!isWhitespace(0x41));
}

test "isLineTerminator" {
    try std.testing.expect(isLineTerminator(0x000A));
    try std.testing.expect(isLineTerminator(0x000D));
    try std.testing.expect(isLineTerminator(0x2028));
    try std.testing.expect(isLineTerminator(0x2029));
    try std.testing.expect(!isLineTerminator(0x41));
}

test "isDecimalDigit" {
    try std.testing.expect(isDecimalDigit('0'));
    try std.testing.expect(isDecimalDigit('9'));
    try std.testing.expect(!isDecimalDigit('a'));
}

test "isBinaryDigit" {
    try std.testing.expect(isBinaryDigit('0'));
    try std.testing.expect(isBinaryDigit('1'));
    try std.testing.expect(!isBinaryDigit('2'));
}

test "isOctalDigit" {
    try std.testing.expect(isOctalDigit('0'));
    try std.testing.expect(isOctalDigit('7'));
    try std.testing.expect(!isOctalDigit('8'));
}

test "isHexDigit" {
    try std.testing.expect(isHexDigit('0'));
    try std.testing.expect(isHexDigit('9'));
    try std.testing.expect(isHexDigit('a'));
    try std.testing.expect(isHexDigit('f'));
    try std.testing.expect(isHexDigit('A'));
    try std.testing.expect(isHexDigit('F'));
    try std.testing.expect(!isHexDigit('g'));
}

test "hexValue" {
    try std.testing.expectEqual(@as(?u8, 0), hexValue('0'));
    try std.testing.expectEqual(@as(?u8, 9), hexValue('9'));
    try std.testing.expectEqual(@as(?u8, 10), hexValue('a'));
    try std.testing.expectEqual(@as(?u8, 15), hexValue('F'));
    try std.testing.expect(hexValue('g') == null);
}

test "isAsciiLetter" {
    try std.testing.expect(isAsciiLetter('a'));
    try std.testing.expect(isAsciiLetter('z'));
    try std.testing.expect(isAsciiLetter('A'));
    try std.testing.expect(isAsciiLetter('Z'));
    try std.testing.expect(!isAsciiLetter('0'));
    try std.testing.expect(!isAsciiLetter('_'));
}

test "isIdentifierStart ascii" {
    try std.testing.expect(isIdentifierStart('a'));
    try std.testing.expect(isIdentifierStart('Z'));
    try std.testing.expect(isIdentifierStart('$'));
    try std.testing.expect(isIdentifierStart('_'));
    try std.testing.expect(!isIdentifierStart('0'));
    try std.testing.expect(!isIdentifierStart('-'));
}

test "isIdentifierStart unicode" {
    try std.testing.expect(isIdentifierStart(0x00C0));
    try std.testing.expect(isIdentifierStart(0x0391));
    try std.testing.expect(isIdentifierStart(0x4E00));
    try std.testing.expect(!isIdentifierStart(0x0020));
}

test "isIdentifierContinue ascii" {
    try std.testing.expect(isIdentifierContinue('a'));
    try std.testing.expect(isIdentifierContinue('0'));
    try std.testing.expect(isIdentifierContinue('_'));
    try std.testing.expect(isIdentifierContinue('$'));
    try std.testing.expect(!isIdentifierContinue('-'));
}

test "isIdentifierContinue combining" {
    try std.testing.expect(isIdentifierContinue(0x0300));
    try std.testing.expect(isIdentifierContinue(0x200C));
    try std.testing.expect(isIdentifierContinue(0x200D));
}

test "utf16Length" {
    try std.testing.expectEqual(@as(u2, 1), utf16Length('A'));
    try std.testing.expectEqual(@as(u2, 2), utf16Length(0x1F600));
}
