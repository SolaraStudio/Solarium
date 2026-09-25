const std = @import("std");

pub fn popCount(x: anytype) u32 {
    return @popCount(x);
}

pub fn leadingZeros(x: anytype) u32 {
    return @intCast(@clz(x));
}

pub fn trailingZeros(x: anytype) u32 {
    return @intCast(@ctz(x));
}

pub fn rotateLeft(x: anytype, comptime n: std.math.Log2Int(@TypeOf(x))) @TypeOf(x) {
    return std.math.rotl(@TypeOf(x), x, n);
}

pub fn rotateRight(x: anytype, comptime n: std.math.Log2Int(@TypeOf(x))) @TypeOf(x) {
    return std.math.rotr(@TypeOf(x), x, n);
}

pub fn testBit(x: anytype, bit: anytype) bool {
    const T = @TypeOf(x);
    const Shift = std.math.Log2Int(T);
    const mask = @as(T, 1) << @as(Shift, @intCast(bit));
    return (x & mask) != 0;
}

pub fn setBit(x: anytype, bit: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const Shift = std.math.Log2Int(T);
    const mask = @as(T, 1) << @as(Shift, @intCast(bit));
    return x | mask;
}

pub fn clearBit(x: anytype, bit: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const Shift = std.math.Log2Int(T);
    const mask = @as(T, 1) << @as(Shift, @intCast(bit));
    return x & ~mask;
}

pub fn toggleBit(x: anytype, bit: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const Shift = std.math.Log2Int(T);
    const mask = @as(T, 1) << @as(Shift, @intCast(bit));
    return x ^ mask;
}

pub fn isPowerOfTwo(x: anytype) bool {
    if (@TypeOf(x) == comptime_int) {
        if (x <= 0) return false;
    } else {
        if (x <= 0) return false;
    }
    return (x & (x - 1)) == 0;
}

pub fn nextPowerOfTwo(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    if (x <= 1) return 1;
    return std.math.ceilPowerOfTwo(T, x) catch x;
}

pub fn previousPowerOfTwo(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    if (x <= 1) return 1;
    return @as(T, 1) << @as(std.math.Log2Int(T), @intCast(@bitSizeOf(T) - 1 - leadingZeros(x)));
}

pub fn alignUp(value: usize, alignment: usize) usize {
    std.debug.assert(isPowerOfTwo(alignment));
    return (value + alignment - 1) & ~(alignment - 1);
}

pub fn alignDown(value: usize, alignment: usize) usize {
    std.debug.assert(isPowerOfTwo(alignment));
    return value & ~(alignment - 1);
}

pub fn isAligned(value: usize, alignment: usize) bool {
    std.debug.assert(isPowerOfTwo(alignment));
    return (value & (alignment - 1)) == 0;
}

pub fn bytesForBits(bits: usize) usize {
    return (bits + 7) / 8;
}

pub fn bitsForBytes(bytes: usize) usize {
    return bytes * 8;
}

pub fn maskLowBits(comptime T: type, count: u32) T {
    if (count == 0) return 0;
    if (count >= @bitSizeOf(T)) return ~@as(T, 0);
    return (@as(T, 1) << @as(std.math.Log2Int(T), @intCast(count))) - 1;
}

pub fn maskHighBits(comptime T: type, count: u32) T {
    if (count == 0) return 0;
    if (count >= @bitSizeOf(T)) return ~@as(T, 0);
    const shift = @bitSizeOf(T) - count;
    return ~((@as(T, 1) << @as(std.math.Log2Int(T), @intCast(shift))) - 1);
}

pub fn countLeadingOnes(x: anytype) u32 {
    return leadingZeros(~x);
}

pub fn countTrailingOnes(x: anytype) u32 {
    return trailingZeros(~x);
}

pub fn reverseBits(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    var result: T = 0;
    var v = x;
    var i: u32 = 0;
    const bits = @bitSizeOf(T);
    while (i < bits) : (i += 1) {
        result = (result << 1) | (v & 1);
        v >>= 1;
    }
    return result;
}

pub fn swapBytes16(x: u16) u16 {
    return @byteSwap(x);
}

pub fn swapBytes32(x: u32) u32 {
    return @byteSwap(x);
}

pub fn swapBytes64(x: u64) u64 {
    return @byteSwap(x);
}

pub fn signExtend(comptime T: type, value: u64, bits: u32) T {
    const T_bits = @bitSizeOf(T);
    const U = std.meta.Int(.unsigned, T_bits);

    if (bits == 0 or bits >= T_bits) {
        const truncated: U = @truncate(value);
        return @bitCast(truncated);
    }

    const shift: u6 = @intCast(64 - bits);
    const wide = value << shift;
    const as_signed: i64 = @bitCast(wide);
    const sign_extended = as_signed >> shift;
    return @intCast(sign_extended);
}

test "popCount basics" {
    try std.testing.expectEqual(@as(u32, 0), popCount(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 1), popCount(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 8), popCount(@as(u32, 0xFF)));
    try std.testing.expectEqual(@as(u32, 32), popCount(@as(u32, 0xFFFFFFFF)));
}

test "leadingZeros basics" {
    try std.testing.expectEqual(@as(u32, 32), leadingZeros(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 31), leadingZeros(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 0), leadingZeros(@as(u32, 0x80000000)));
    try std.testing.expectEqual(@as(u32, 24), leadingZeros(@as(u32, 0x80)));
}

test "trailingZeros basics" {
    try std.testing.expectEqual(@as(u32, 32), trailingZeros(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 0), trailingZeros(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 31), trailingZeros(@as(u32, 0x80000000)));
    try std.testing.expectEqual(@as(u32, 3), trailingZeros(@as(u32, 8)));
}

test "rotateLeft and rotateRight" {
    try std.testing.expectEqual(@as(u32, 2), rotateLeft(@as(u32, 1), 1));
    try std.testing.expectEqual(@as(u32, 0x80000000), rotateLeft(@as(u32, 1), 31));
    try std.testing.expectEqual(@as(u32, 0x80000000), rotateRight(@as(u32, 1), 1));
    try std.testing.expectEqual(@as(u32, 1), rotateRight(@as(u32, 2), 1));
}

test "testBit" {
    const v: u32 = 0b1010;
    try std.testing.expect(!testBit(v, 0));
    try std.testing.expect(testBit(v, 1));
    try std.testing.expect(!testBit(v, 2));
    try std.testing.expect(testBit(v, 3));
    try std.testing.expect(!testBit(v, 4));
}

test "setBit" {
    try std.testing.expectEqual(@as(u32, 1), setBit(@as(u32, 0), 0));
    try std.testing.expectEqual(@as(u32, 32), setBit(@as(u32, 0), 5));
    try std.testing.expectEqual(@as(u32, 0x1FF), setBit(@as(u32, 0xFF), 8));
}

test "clearBit" {
    try std.testing.expectEqual(@as(u32, 0xFE), clearBit(@as(u32, 0xFF), 0));
    try std.testing.expectEqual(@as(u32, 0xFE), clearBit(@as(u32, 0xFF), 0));
    try std.testing.expectEqual(@as(u32, 0xF7), clearBit(@as(u32, 0xFF), 3));
}

test "toggleBit" {
    try std.testing.expectEqual(@as(u32, 1), toggleBit(@as(u32, 0), 0));
    try std.testing.expectEqual(@as(u32, 0), toggleBit(@as(u32, 1), 0));
    try std.testing.expectEqual(@as(u32, 0xF7), toggleBit(@as(u32, 0xFF), 3));
}

test "isPowerOfTwo" {
    try std.testing.expect(!isPowerOfTwo(@as(u32, 0)));
    try std.testing.expect(isPowerOfTwo(@as(u32, 1)));
    try std.testing.expect(isPowerOfTwo(@as(u32, 2)));
    try std.testing.expect(!isPowerOfTwo(@as(u32, 3)));
    try std.testing.expect(isPowerOfTwo(@as(u32, 4)));
    try std.testing.expect(!isPowerOfTwo(@as(u32, 5)));
    try std.testing.expect(isPowerOfTwo(@as(u32, 1024)));
}

test "nextPowerOfTwo" {
    try std.testing.expectEqual(@as(u32, 1), nextPowerOfTwo(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 1), nextPowerOfTwo(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 2), nextPowerOfTwo(@as(u32, 2)));
    try std.testing.expectEqual(@as(u32, 4), nextPowerOfTwo(@as(u32, 3)));
    try std.testing.expectEqual(@as(u32, 4), nextPowerOfTwo(@as(u32, 4)));
    try std.testing.expectEqual(@as(u32, 8), nextPowerOfTwo(@as(u32, 5)));
    try std.testing.expectEqual(@as(u32, 1024), nextPowerOfTwo(@as(u32, 1023)));
}

test "previousPowerOfTwo" {
    try std.testing.expectEqual(@as(u32, 1), previousPowerOfTwo(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 2), previousPowerOfTwo(@as(u32, 2)));
    try std.testing.expectEqual(@as(u32, 2), previousPowerOfTwo(@as(u32, 3)));
    try std.testing.expectEqual(@as(u32, 4), previousPowerOfTwo(@as(u32, 4)));
    try std.testing.expectEqual(@as(u32, 4), previousPowerOfTwo(@as(u32, 7)));
    try std.testing.expectEqual(@as(u32, 512), previousPowerOfTwo(@as(u32, 1023)));
}

test "alignUp and alignDown" {
    try std.testing.expectEqual(@as(usize, 8), alignUp(5, 4));
    try std.testing.expectEqual(@as(usize, 8), alignUp(8, 4));
    try std.testing.expectEqual(@as(usize, 4), alignDown(5, 4));
    try std.testing.expectEqual(@as(usize, 8), alignDown(8, 4));
    try std.testing.expectEqual(@as(usize, 16), alignUp(9, 16));
}

test "isAligned" {
    try std.testing.expect(isAligned(0, 4));
    try std.testing.expect(isAligned(4, 4));
    try std.testing.expect(isAligned(8, 4));
    try std.testing.expect(!isAligned(5, 4));
    try std.testing.expect(!isAligned(7, 4));
}

test "bytesForBits" {
    try std.testing.expectEqual(@as(usize, 0), bytesForBits(0));
    try std.testing.expectEqual(@as(usize, 1), bytesForBits(1));
    try std.testing.expectEqual(@as(usize, 1), bytesForBits(8));
    try std.testing.expectEqual(@as(usize, 2), bytesForBits(9));
    try std.testing.expectEqual(@as(usize, 2), bytesForBits(16));
    try std.testing.expectEqual(@as(usize, 3), bytesForBits(17));
}

test "bitsForBytes" {
    try std.testing.expectEqual(@as(usize, 0), bitsForBytes(0));
    try std.testing.expectEqual(@as(usize, 8), bitsForBytes(1));
    try std.testing.expectEqual(@as(usize, 64), bitsForBytes(8));
}

test "maskLowBits" {
    try std.testing.expectEqual(@as(u32, 0), maskLowBits(u32, 0));
    try std.testing.expectEqual(@as(u32, 1), maskLowBits(u32, 1));
    try std.testing.expectEqual(@as(u32, 3), maskLowBits(u32, 2));
    try std.testing.expectEqual(@as(u32, 0xFF), maskLowBits(u32, 8));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskLowBits(u32, 32));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskLowBits(u32, 100));
}

test "maskHighBits" {
    try std.testing.expectEqual(@as(u32, 0), maskHighBits(u32, 0));
    try std.testing.expectEqual(@as(u32, 0x80000000), maskHighBits(u32, 1));
    try std.testing.expectEqual(@as(u32, 0xC0000000), maskHighBits(u32, 2));
    try std.testing.expectEqual(@as(u32, 0xFF000000), maskHighBits(u32, 8));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskHighBits(u32, 32));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), maskHighBits(u32, 100));
}

test "countLeadingOnes" {
    try std.testing.expectEqual(@as(u32, 0), countLeadingOnes(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 32), countLeadingOnes(@as(u32, 0xFFFFFFFF)));
    try std.testing.expectEqual(@as(u32, 4), countLeadingOnes(@as(u32, 0xF0000000)));
}

test "countTrailingOnes" {
    try std.testing.expectEqual(@as(u32, 0), countTrailingOnes(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 32), countTrailingOnes(@as(u32, 0xFFFFFFFF)));
    try std.testing.expectEqual(@as(u32, 4), countTrailingOnes(@as(u32, 0x0000000F)));
}

test "reverseBits" {
    try std.testing.expectEqual(@as(u32, 0), reverseBits(@as(u32, 0)));
    try std.testing.expectEqual(@as(u32, 0x80000000), reverseBits(@as(u32, 1)));
    try std.testing.expectEqual(@as(u32, 1), reverseBits(@as(u32, 0x80000000)));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), reverseBits(@as(u32, 0xFFFFFFFF)));
}

test "swapBytes" {
    try std.testing.expectEqual(@as(u16, 0x3412), swapBytes16(0x1234));
    try std.testing.expectEqual(@as(u32, 0x78563412), swapBytes32(0x12345678));
    try std.testing.expectEqual(@as(u64, 0xEFCDAB8967452301), swapBytes64(0x0123456789ABCDEF));
}

test "signExtend positive" {
    const v = signExtend(i32, 0b0111, 4);
    try std.testing.expectEqual(@as(i32, 7), v);
}

test "signExtend negative" {
    const v = signExtend(i32, 0b1111, 4);
    try std.testing.expectEqual(@as(i32, -1), v);
    const v2 = signExtend(i32, 0b1000, 4);
    try std.testing.expectEqual(@as(i32, -8), v2);
}

test "signExtend full width" {
    const v = signExtend(i32, 0xFFFFFFFF, 32);
    try std.testing.expectEqual(@as(i32, -1), v);
}

test "signExtend zero bits" {
    const v = signExtend(i32, 42, 0);
    try std.testing.expectEqual(@as(i32, 42), v);
}
