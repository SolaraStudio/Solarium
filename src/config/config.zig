const std = @import("std");

pub const version = @import("version.zig");
pub const features = @import("features.zig");
pub const limits = @import("limits.zig");

pub const LogLevel = enum(u8) {
    off = 0,
    err = 1,
    warn = 2,
    info = 3,
    debug = 4,
    trace = 5,

    pub fn fromString(s: []const u8) ?LogLevel {
        const table = [_]struct { []const u8, LogLevel }{
            .{ "off", .off },
            .{ "error", .err },
            .{ "err", .err },
            .{ "warn", .warn },
            .{ "warning", .warn },
            .{ "info", .info },
            .{ "debug", .debug },
            .{ "trace", .trace },
        };
        for (table) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .off => "off",
            .err => "error",
            .warn => "warn",
            .info => "info",
            .debug => "debug",
            .trace => "trace",
        };
    }

    pub fn enabled(self: LogLevel, other: LogLevel) bool {
        return @intFromEnum(self) >= @intFromEnum(other);
    }
};

pub const Mode = enum {
    production,
    development,
    testing,
    embedded,

    pub fn toString(self: Mode) []const u8 {
        return @tagName(self);
    }

    pub fn fromString(s: []const u8) ?Mode {
        inline for (@typeInfo(Mode).@"enum".fields) |field| {
            if (std.mem.eql(u8, s, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return null;
    }
};

pub const Config = struct {
    mode: Mode = .production,
    log_level: LogLevel = .info,
    strict_mode: bool = true,
    debug_trace: bool = false,
    jit_enabled: bool = false,
    stack_size: usize = 1024 * 1024,
    heap_size: usize = 256 * 1024 * 1024,
    gc_threshold: usize = 16 * 1024 * 1024,
    gc_interval_ms: u64 = 1000,
    max_call_depth: usize = 10_000,
    max_parse_depth: usize = 1_000,
    max_string_length: usize = 512 * 1024 * 1024,
    max_array_length: usize = 4_294_967_295,
    max_object_properties: usize = 1_000_000,
    max_regex_backtrack: usize = 1_000_000,

    pub fn production() Config {
        return .{
            .mode = .production,
            .log_level = .warn,
            .strict_mode = false,
            .debug_trace = false,
            .jit_enabled = true,
        };
    }

    pub fn development() Config {
        return .{
            .mode = .development,
            .log_level = .debug,
            .strict_mode = true,
            .debug_trace = true,
            .jit_enabled = false,
        };
    }

    pub fn testing() Config {
        return .{
            .mode = .testing,
            .log_level = .warn,
            .strict_mode = true,
            .debug_trace = true,
            .jit_enabled = false,
            .heap_size = 32 * 1024 * 1024,
            .gc_threshold = 4 * 1024 * 1024,
            .max_call_depth = 1_000,
            .max_parse_depth = 200,
        };
    }

    pub fn embedded() Config {
        return .{
            .mode = .embedded,
            .log_level = .err,
            .strict_mode = false,
            .debug_trace = false,
            .jit_enabled = false,
            .stack_size = 256 * 1024,
            .heap_size = 16 * 1024 * 1024,
            .gc_threshold = 2 * 1024 * 1024,
            .max_call_depth = 500,
            .max_parse_depth = 100,
        };
    }

    pub fn forMode(mode: Mode) Config {
        return switch (mode) {
            .production => Config.production(),
            .development => Config.development(),
            .testing => Config.testing(),
            .embedded => Config.embedded(),
        };
    }

    pub fn validate(self: Config) !void {
        if (self.stack_size < 64 * 1024) return error.StackTooSmall;
        if (self.heap_size < 1024 * 1024) return error.HeapTooSmall;
        if (self.gc_threshold > self.heap_size) return error.GcThresholdExceedsHeap;
        if (self.gc_interval_ms == 0) return error.InvalidGcInterval;
        if (self.max_call_depth == 0) return error.InvalidCallDepth;
        if (self.max_parse_depth == 0) return error.InvalidParseDepth;
        if (self.max_string_length == 0) return error.InvalidStringLimit;
        if (self.max_array_length == 0) return error.InvalidArrayLimit;
        if (self.max_object_properties == 0) return error.InvalidObjectLimit;
        if (self.max_regex_backtrack == 0) return error.InvalidRegexLimit;
    }

    pub fn withMode(self: Config, mode: Mode) Config {
        var c = self;
        c.mode = mode;
        return c;
    }

    pub fn withLogLevel(self: Config, level: LogLevel) Config {
        var c = self;
        c.log_level = level;
        return c;
    }

    pub fn withStrictMode(self: Config, strict: bool) Config {
        var c = self;
        c.strict_mode = strict;
        return c;
    }

    pub fn withDebugTrace(self: Config, enabled: bool) Config {
        var c = self;
        c.debug_trace = enabled;
        return c;
    }

    pub fn withJit(self: Config, enabled: bool) Config {
        var c = self;
        c.jit_enabled = enabled;
        return c;
    }

    pub fn withHeapSize(self: Config, size: usize) Config {
        var c = self;
        c.heap_size = size;
        return c;
    }

    pub fn withStackSize(self: Config, size: usize) Config {
        var c = self;
        c.stack_size = size;
        return c;
    }

    pub fn withGcThreshold(self: Config, threshold: usize) Config {
        var c = self;
        c.gc_threshold = threshold;
        return c;
    }

    pub fn withMaxCallDepth(self: Config, depth: usize) Config {
        var c = self;
        c.max_call_depth = depth;
        return c;
    }
};

pub const default = Config{};

pub fn defaults() Config {
    return default;
}

test "default config validates" {
    try default.validate();
}

test "production preset validates" {
    try Config.production().validate();
}

test "development preset validates" {
    try Config.development().validate();
}

test "testing preset validates" {
    try Config.testing().validate();
}

test "embedded preset validates" {
    try Config.embedded().validate();
}

test "for mode dispatch returns correct mode" {
    try std.testing.expectEqual(Mode.production, Config.forMode(.production).mode);
    try std.testing.expectEqual(Mode.development, Config.forMode(.development).mode);
    try std.testing.expectEqual(Mode.testing, Config.forMode(.testing).mode);
    try std.testing.expectEqual(Mode.embedded, Config.forMode(.embedded).mode);
}

test "log level from string" {
    try std.testing.expectEqual(LogLevel.debug, LogLevel.fromString("debug").?);
    try std.testing.expectEqual(LogLevel.err, LogLevel.fromString("err").?);
    try std.testing.expectEqual(LogLevel.err, LogLevel.fromString("error").?);
    try std.testing.expectEqual(LogLevel.warn, LogLevel.fromString("warning").?);
    try std.testing.expect(LogLevel.fromString("nonsense") == null);
}

test "log level round trip" {
    const levels = [_]LogLevel{ .off, .err, .warn, .info, .debug, .trace };
    for (levels) |level| {
        const s = level.toString();
        try std.testing.expect(LogLevel.fromString(s) != null);
    }
}

test "log level enabled comparison" {
    try std.testing.expect(LogLevel.trace.enabled(.info));
    try std.testing.expect(LogLevel.info.enabled(.info));
    try std.testing.expect(!LogLevel.warn.enabled(.info));
    try std.testing.expect(!LogLevel.off.enabled(.err));
}

test "mode toString round trip" {
    try std.testing.expectEqual(Mode.production, Mode.fromString("production").?);
    try std.testing.expectEqual(Mode.embedded, Mode.fromString("embedded").?);
    try std.testing.expect(Mode.fromString("invalid") == null);
}

test "with log level is pure" {
    const modified = default.withLogLevel(.trace);
    try std.testing.expectEqual(LogLevel.trace, modified.log_level);
    try std.testing.expectEqual(LogLevel.info, default.log_level);
}

test "with heap size is pure" {
    const modified = default.withHeapSize(64 * 1024 * 1024);
    try std.testing.expectEqual(@as(usize, 64 * 1024 * 1024), modified.heap_size);
    try std.testing.expectEqual(@as(usize, 256 * 1024 * 1024), default.heap_size);
}

test "with strict mode is pure" {
    const modified = default.withStrictMode(false);
    try std.testing.expect(!modified.strict_mode);
    try std.testing.expect(default.strict_mode);
}

test "validate rejects small stack" {
    var c = default;
    c.stack_size = 1024;
    try std.testing.expectError(error.StackTooSmall, c.validate());
}

test "validate rejects small heap" {
    var c = default;
    c.heap_size = 512 * 1024;
    try std.testing.expectError(error.HeapTooSmall, c.validate());
}

test "validate rejects gc threshold larger than heap" {
    var c = default;
    c.heap_size = 1024 * 1024;
    c.gc_threshold = 2 * 1024 * 1024;
    try std.testing.expectError(error.GcThresholdExceedsHeap, c.validate());
}

test "validate rejects zero gc interval" {
    var c = default;
    c.gc_interval_ms = 0;
    try std.testing.expectError(error.InvalidGcInterval, c.validate());
}

test "validate rejects zero call depth" {
    var c = default;
    c.max_call_depth = 0;
    try std.testing.expectError(error.InvalidCallDepth, c.validate());
}
