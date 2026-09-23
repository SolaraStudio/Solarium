const std = @import("std");

pub const major: u32 = 1;
pub const minor: u32 = 17;
pub const patch: u32 = 0;

pub const stage: Stage = .beta;

pub const Stage = enum {
    alpha,
    beta,
    rc,
    stable,

    pub fn toString(self: Stage) []const u8 {
        return switch (self) {
            .alpha => "alpha",
            .beta => "beta",
            .rc => "rc",
            .stable => "stable",
        };
    }
};

pub const pre_release: ?[]const u8 = "beta";

pub const string: []const u8 = "1.17.0-beta";
pub const name: []const u8 = "Solarium";
pub const description: []const u8 = "JavaScript engine written in Zig for the Solara browser";
pub const author: []const u8 = "SolaraStudio";
pub const license: []const u8 = "Apache-2.0";
pub const homepage: []const u8 = "https://github.com/SolaraStudio/Solarium";
pub const repository: []const u8 = "https://github.com/SolaraStudio/Solarium.git";
pub const issues: []const u8 = "https://github.com/SolaraStudio/Solarium/issues";

pub const required_zig: []const u8 = "0.14.0";

pub const abi: u32 = 1;

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub const current = Version{ .major = major, .minor = minor, .patch = patch };

    pub fn init(m: u32, n: u32, p: u32) Version {
        return .{ .major = m, .minor = n, .patch = p };
    }

    pub fn parse(s: []const u8) !Version {
        var it = std.mem.splitScalar(u8, s, '.');
        const m_str = it.next() orelse return error.InvalidVersion;
        const n_str = it.next() orelse return error.InvalidVersion;
        const p_str = it.next() orelse return error.InvalidVersion;
        const m = std.fmt.parseInt(u32, m_str, 10) catch return error.InvalidVersion;
        const n = std.fmt.parseInt(u32, n_str, 10) catch return error.InvalidVersion;
        const p = std.fmt.parseInt(u32, p_str, 10) catch return error.InvalidVersion;
        if (it.next() != null) return error.InvalidVersion;
        return .{ .major = m, .minor = n, .patch = p };
    }

    pub fn format(self: Version, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }

    pub fn order(self: Version, other: Version) std.math.Order {
        if (self.major != other.major) return std.math.order(self.major, other.major);
        if (self.minor != other.minor) return std.math.order(self.minor, other.minor);
        return std.math.order(self.patch, other.patch);
    }

    pub fn eql(self: Version, other: Version) bool {
        return self.major == other.major and
            self.minor == other.minor and
            self.patch == other.patch;
    }

    pub fn isCompatibleWith(self: Version, other: Version) bool {
        if (self.major == 0 or other.major == 0) {
            return self.eql(other);
        }
        return self.major == other.major and other.minor >= self.minor;
    }
};

pub fn current() Version {
    return Version.current;
}

pub fn fullString(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}-{s}", .{
        major,
        minor,
        patch,
        pre_release orelse "release",
    });
}

pub fn bannerString(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s} {s} (zig {s})", .{
        name,
        string,
        required_zig,
    });
}

test "current version matches constants" {
    const c = Version.current;
    try std.testing.expectEqual(@as(u32, 1), c.major);
    try std.testing.expectEqual(@as(u32, 17), c.minor);
    try std.testing.expectEqual(@as(u32, 0), c.patch);
}

test "parse valid version" {
    const v = try Version.parse("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
}

test "parse rejects malformed" {
    try std.testing.expectError(error.InvalidVersion, Version.parse("1.2"));
    try std.testing.expectError(error.InvalidVersion, Version.parse("1"));
    try std.testing.expectError(error.InvalidVersion, Version.parse("1.2.3.4"));
    try std.testing.expectError(error.InvalidVersion, Version.parse("a.b.c"));
}

test "equality" {
    const a = Version.init(1, 2, 3);
    const b = Version.init(1, 2, 3);
    const c = Version.init(1, 2, 4);
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
}

test "ordering" {
    const a = Version.init(1, 2, 3);
    const b = Version.init(1, 2, 4);
    const c = Version.init(2, 0, 0);
    try std.testing.expectEqual(std.math.Order.lt, a.order(b));
    try std.testing.expectEqual(std.math.Order.lt, b.order(c));
    try std.testing.expectEqual(std.math.Order.gt, c.order(a));
    try std.testing.expectEqual(std.math.Order.eq, a.order(a));
}

test "compatibility same major" {
    const a = Version.init(1, 2, 0);
    const b = Version.init(1, 3, 0);
    try std.testing.expect(a.isCompatibleWith(b));
    try std.testing.expect(!b.isCompatibleWith(a));
}

test "compatibility different major" {
    const a = Version.init(1, 2, 0);
    const b = Version.init(2, 0, 0);
    try std.testing.expect(!a.isCompatibleWith(b));
    try std.testing.expect(!b.isCompatibleWith(a));
}

test "zero major requires exact match" {
    const a = Version.init(0, 1, 0);
    const b = Version.init(0, 2, 0);
    try std.testing.expect(!a.isCompatibleWith(b));
    try std.testing.expect(a.isCompatibleWith(a));
}

test "stage toString" {
    try std.testing.expectEqualStrings("alpha", Stage.alpha.toString());
    try std.testing.expectEqualStrings("stable", Stage.stable.toString());
}

test "stage is beta" {
    try std.testing.expectEqual(Stage.beta, stage);
}

test "license is apache" {
    try std.testing.expectEqualStrings("Apache-2.0", license);
}

test "full string allocates" {
    const s = try fullString(std.testing.allocator);
    defer std.testing.allocator.free(s);
    try std.testing.expect(s.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, s, "1.17.0"));
}

test "banner string allocates" {
    const s = try bannerString(std.testing.allocator);
    defer std.testing.allocator.free(s);
    try std.testing.expect(std.mem.indexOf(u8, s, "Solarium") != null);
}
