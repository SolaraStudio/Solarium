const std = @import("std");

pub const fnv_offset_basis_32: u32 = 2166136261;
pub const fnv_prime_32: u32 = 16777619;
pub const fnv_offset_basis_64: u64 = 14695981039346656037;
pub const fnv_prime_64: u64 = 1099511628211;

pub fn fnv1a32(data: []const u8) u32 {
    var hash: u32 = fnv_offset_basis_32;
    for (data) |byte| {
        hash ^= byte;
        hash *%= fnv_prime_32;
    }
    return hash;
}

pub fn fnv1a64(data: []const u8) u64 {
    var hash: u64 = fnv_offset_basis_64;
    for (data) |byte| {
        hash ^= byte;
        hash *%= fnv_prime_64;
    }
    return hash;
}

pub fn fnv1_32(data: []const u8) u32 {
    var hash: u32 = fnv_offset_basis_32;
    for (data) |byte| {
        hash *%= fnv_prime_32;
        hash ^= byte;
    }
    return hash;
}

pub fn fnv1_64(data: []const u8) u64 {
    var hash: u64 = fnv_offset_basis_64;
    for (data) |byte| {
        hash *%= fnv_prime_64;
        hash ^= byte;
    }
    return hash;
}

pub fn djb2(data: []const u8) u64 {
    var hash: u64 = 5381;
    for (data) |byte| {
        hash = ((hash << 5) +% hash) +% byte;
    }
    return hash;
}

pub fn djb2_xor(data: []const u8) u64 {
    var hash: u64 = 5381;
    for (data) |byte| {
        hash = ((hash << 5) +% hash) ^ byte;
    }
    return hash;
}

pub fn sdbm(data: []const u8) u64 {
    var hash: u64 = 0;
    for (data) |byte| {
        hash = @as(u64, byte) +% (hash << 6) +% (hash << 16) -% hash;
    }
    return hash;
}

pub fn javaStringHash(data: []const u8) i32 {
    var hash: i32 = 0;
    for (data) |byte| {
        hash = hash *% 31 +% @as(i32, byte);
    }
    return hash;
}

pub fn adler32(data: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    for (data) |byte| {
        a = (a +% byte) % 65521;
        b = (b +% a) % 65521;
    }
    return (b << 16) | a;
}

pub fn crc32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        crc ^= byte;
        var i: u8 = 0;
        while (i < 8) : (i += 1) {
            const mask: u32 = @as(u32, 0) -% (crc & 1);
            crc = (crc >> 1) ^ (0xEDB88320 & mask);
        }
    }
    return ~crc;
}

pub fn murmur3_32(data: []const u8, seed: u32) u32 {
    const c1: u32 = 0xcc9e2d51;
    const c2: u32 = 0x1b873593;

    var h: u32 = seed;
    var i: usize = 0;
    const len = data.len;

    while (i + 4 <= len) : (i += 4) {
        var k: u32 = @as(u32, data[i]) |
            (@as(u32, data[i + 1]) << 8) |
            (@as(u32, data[i + 2]) << 16) |
            (@as(u32, data[i + 3]) << 24);

        k *%= c1;
        k = std.math.rotl(u32, k, 15);
        k *%= c2;

        h ^= k;
        h = std.math.rotl(u32, h, 13);
        h = h *% 5 +% 0xe6546b64;
    }

    var tail: u32 = 0;
    const rem = len - i;
    if (rem >= 3) tail |= @as(u32, data[i + 2]) << 16;
    if (rem >= 2) tail |= @as(u32, data[i + 1]) << 8;
    if (rem >= 1) {
        tail |= @as(u32, data[i]);
        tail *%= c1;
        tail = std.math.rotl(u32, tail, 15);
        tail *%= c2;
        h ^= tail;
    }

    h ^= @as(u32, @intCast(len));
    h ^= h >> 16;
    h *%= 0x85ebca6b;
    h ^= h >> 13;
    h *%= 0xc2b2ae35;
    h ^= h >> 16;

    return h;
}

pub fn combine(a: u64, b: u64) u64 {
    var h: u64 = a ^ (b +% 0x9e3779b97f4a7c15 +% (a << 6) +% (a >> 2));
    h ^= h >> 33;
    h *%= 0xff51afd7ed558ccd;
    h ^= h >> 33;
    return h;
}

pub fn combineMany(hashes: []const u64) u64 {
    var acc: u64 = 0;
    for (hashes) |h| {
        acc = combine(acc, h);
    }
    return acc;
}

pub fn hashBytes(data: []const u8) u64 {
    return fnv1a64(data);
}

pub fn hashInt(value: anytype) u64 {
    var buf: [16]u8 = undefined;
    const T = @TypeOf(value);
    const size = @sizeOf(T);
    var bytes: [size]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .little);
    @memcpy(buf[0..size], &bytes);
    return fnv1a64(buf[0..size]);
}

pub fn hashFloat(value: f64) u64 {
    const bits: u64 = @bitCast(value);
    return fnv1a64(std.mem.asBytes(&bits));
}

pub fn hashBool(value: bool) u64 {
    return if (value) fnv1a64(&[_]u8{1}) else fnv1a64(&[_]u8{0});
}

pub const Hasher = struct {
    state: u64,

    pub fn init() Hasher {
        return .{ .state = fnv_offset_basis_64 };
    }

    pub fn initSeed(seed: u64) Hasher {
        return .{ .state = seed };
    }

    pub fn update(self: *Hasher, data: []const u8) void {
        var h = self.state;
        for (data) |byte| {
            h ^= byte;
            h *%= fnv_prime_64;
        }
        self.state = h;
    }

    pub fn updateInt(self: *Hasher, value: anytype) void {
        var bytes: [@sizeOf(@TypeOf(value))]u8 = undefined;
        std.mem.writeInt(@TypeOf(value), &bytes, value, .little);
        self.update(&bytes);
    }

    pub fn updateBool(self: *Hasher, value: bool) void {
        self.update(if (value) &[_]u8{1} else &[_]u8{0});
    }

    pub fn finalize(self: Hasher) u64 {
        return self.state;
    }

    pub fn reset(self: *Hasher) void {
        self.state = fnv_offset_basis_64;
    }
};

pub fn create() Hasher {
    return Hasher.init();
}

test "fnv1a32 known values" {
    try std.testing.expectEqual(@as(u32, 0x811c9dc5), fnv1a32(""));
    try std.testing.expectEqual(@as(u32, 0xe40c292c), fnv1a32("a"));
    try std.testing.expectEqual(@as(u32, 0xe70c2de5), fnv1a32("b"));
    try std.testing.expectEqual(@as(u32, 0xe60c2c52), fnv1a32("c"));
    try std.testing.expectEqual(@as(u32, 0x4d2505ca), fnv1a32("ab"));
}

test "fnv1a64 known values" {
    try std.testing.expectEqual(@as(u64, 0xcbf29ce484222325), fnv1a64(""));
    try std.testing.expectEqual(@as(u64, 0xaf63dc4c8601ec8c), fnv1a64("a"));
    try std.testing.expectEqual(@as(u64, 0xaf63df4c8601f1a5), fnv1a64("b"));
    try std.testing.expectEqual(@as(u64, 0x089c4407b545986a), fnv1a64("ab"));
}

test "fnv1 differs from fnv1a" {
    const a = fnv1a32("hello");
    const b = fnv1_32("hello");
    try std.testing.expect(a != b);
}

test "djb2 basics" {
    const h1 = djb2("hello");
    const h2 = djb2("hello");
    try std.testing.expectEqual(h1, h2);
    try std.testing.expect(djb2("hello") != djb2("world"));
}

test "djb2_xor differs from djb2" {
    try std.testing.expect(djb2("test") != djb2_xor("test"));
}

test "sdbm basics" {
    try std.testing.expectEqual(@as(u64, 0), sdbm(""));
    try std.testing.expect(sdbm("a") != sdbm("b"));
}

test "java string hash known values" {
    try std.testing.expectEqual(@as(i32, 0), javaStringHash(""));
    try std.testing.expectEqual(@as(i32, 97), javaStringHash("a"));
    try std.testing.expectEqual(@as(i32, 3105), javaStringHash("ab"));
}

test "adler32 basics" {
    try std.testing.expectEqual(@as(u32, 1), adler32(""));
    const h = adler32("Wikipedia");
    try std.testing.expect(h != 0);
}

test "crc32 known value" {
    try std.testing.expectEqual(@as(u32, 0), crc32(""));
    try std.testing.expectEqual(@as(u32, 0xCBF43926), crc32("123456789"));
    try std.testing.expectEqual(@as(u32, 0x414FA339), crc32("The quick brown fox jumps over the lazy dog"));
}

test "murmur3 known value" {
    try std.testing.expectEqual(@as(u32, 0), murmur3_32("", 0));
    const h1 = murmur3_32("hello", 0);
    const h2 = murmur3_32("hello", 0);
    try std.testing.expectEqual(h1, h2);
    try std.testing.expect(murmur3_32("hello", 0) != murmur3_32("hello", 1));
}

test "combine is deterministic" {
    const a = combine(1, 2);
    const b = combine(1, 2);
    try std.testing.expectEqual(a, b);
    try std.testing.expect(combine(1, 2) != combine(2, 1));
}

test "combineMany" {
    const hashes = [_]u64{ 1, 2, 3, 4 };
    const h1 = combineMany(&hashes);
    const h2 = combineMany(&hashes);
    try std.testing.expectEqual(h1, h2);
}

test "hashBytes equals fnv1a64" {
    const data = "test";
    try std.testing.expectEqual(fnv1a64(data), hashBytes(data));
}

test "hashInt" {
    const h1 = hashInt(@as(u32, 42));
    const h2 = hashInt(@as(u32, 42));
    try std.testing.expectEqual(h1, h2);
    try std.testing.expect(hashInt(@as(u32, 42)) != hashInt(@as(u32, 43)));
}

test "hashFloat" {
    const h1 = hashFloat(3.14);
    const h2 = hashFloat(3.14);
    try std.testing.expectEqual(h1, h2);
    try std.testing.expect(hashFloat(3.14) != hashFloat(2.71));
}

test "hashBool" {
    try std.testing.expect(hashBool(true) != hashBool(false));
    try std.testing.expectEqual(hashBool(true), hashBool(true));
}

test "Hasher incremental matches one-shot" {
    var h = Hasher.init();
    h.update("hello");
    h.update("world");
    const incremental = h.finalize();
    const oneshot = fnv1a64("helloworld");
    try std.testing.expectEqual(oneshot, incremental);
}

test "Hasher reset" {
    var h = Hasher.init();
    h.update("test");
    const before = h.finalize();
    try std.testing.expect(before != fnv_offset_basis_64);
    h.reset();
    try std.testing.expectEqual(fnv_offset_basis_64, h.finalize());
}

test "Hasher updateInt" {
    var h1 = Hasher.init();
    h1.updateInt(@as(u32, 0x12345678));
    var h2 = Hasher.init();
    h2.update(&[_]u8{ 0x78, 0x56, 0x34, 0x12 });
    try std.testing.expectEqual(h1.finalize(), h2.finalize());
}

test "Hasher updateBool" {
    var h1 = Hasher.init();
    h1.updateBool(true);
    var h2 = Hasher.init();
    h2.update(&[_]u8{1});
    try std.testing.expectEqual(h1.finalize(), h2.finalize());
}

test "create returns fresh hasher" {
    var h = create();
    h.update("data");
    try std.testing.expect(h.finalize() != fnv_offset_basis_64);
}

test "empty input hashes consistently" {
    try std.testing.expectEqual(hashBytes(""), hashBytes(""));
    try std.testing.expectEqual(djb2(""), djb2(""));
    try std.testing.expectEqual(sdbm(""), sdbm(""));
}
