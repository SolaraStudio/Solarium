const std = @import("std");

pub const Level = enum(u8) {
    off = 0,
    err = 1,
    warn = 2,
    info = 3,
    debug = 4,
    trace = 5,

    pub fn enabled(self: Level, other: Level) bool {
        return @intFromEnum(self) >= @intFromEnum(other);
    }
};

pub const Sink = enum {
    stderr,
    stdout,
    silent,

    pub fn toString(self: Sink) []const u8 {
        return @tagName(self);
    }
};

pub const Format = enum {
    plain,
    structured,
    json,

    pub fn toString(self: Format) []const u8 {
        return @tagName(self);
    }
};

pub const Logger = struct {
    level: Level = .info,
    sink: Sink = .stderr,
    format: Format = .plain,
    scope: ?[]const u8 = null,

    pub fn init() Logger {
        return .{};
    }

    pub fn withLevel(self: Logger, level: Level) Logger {
        var l = self;
        l.level = level;
        return l;
    }

    pub fn withSink(self: Logger, sink: Sink) Logger {
        var l = self;
        l.sink = sink;
        return l;
    }

    pub fn withFormat(self: Logger, format: Format) Logger {
        var l = self;
        l.format = format;
        return l;
    }

    pub fn withScope(self: Logger, scope: []const u8) Logger {
        var l = self;
        l.scope = scope;
        return l;
    }

    pub fn scoped(self: Logger, scope: []const u8) Logger {
        return self.withScope(scope);
    }

    pub fn enabled(self: Logger, level: Level) bool {
        return self.level.enabled(level);
    }

    pub fn isSilent(self: Logger) bool {
        return self.sink == .silent or self.level == .off;
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }

    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn trace(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.trace, fmt, args);
    }

    pub fn log(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled(level)) return;
        if (self.sink == .silent) return;

        switch (self.format) {
            .plain => self.emitPlain(level, fmt, args),
            .structured => self.emitStructured(level, fmt, args),
            .json => self.emitJson(level, fmt, args),
        }
    }

    fn emitPlain(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        const tag = levelTag(level);
        if (self.scope) |scope| {
            writeFormatted("[{s}] [{s}] " ++ fmt ++ "\n", .{ tag, scope } ++ args, self.sink);
        } else {
            writeFormatted("[{s}] " ++ fmt ++ "\n", .{tag} ++ args, self.sink);
        }
    }

    fn emitStructured(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        const tag = levelTag(level);
        const ts = std.time.milliTimestamp();
        if (self.scope) |scope| {
            writeFormatted("[{d}] [{s}] [{s}] " ++ fmt ++ "\n", .{ ts, tag, scope } ++ args, self.sink);
        } else {
            writeFormatted("[{d}] [{s}] " ++ fmt ++ "\n", .{ ts, tag } ++ args, self.sink);
        }
    }

    fn emitJson(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        const tag = levelTag(level);
        const ts = std.time.milliTimestamp();
        var buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt, args) catch "<message too long>";
        if (self.scope) |scope| {
            writeFormatted("{{\"ts\":{d},\"level\":\"{s}\",\"scope\":\"{s}\",\"msg\":\"{s}\"}}\n", .{ ts, tag, scope, msg }, self.sink);
        } else {
            writeFormatted("{{\"ts\":{d},\"level\":\"{s}\",\"msg\":\"{s}\"}}\n", .{ ts, tag, msg }, self.sink);
        }
    }

    fn writeFormatted(comptime fmt: []const u8, args: anytype, sink: Sink) void {
        switch (sink) {
            .stderr => std.debug.print(fmt, args),
            .stdout => {
                var buf: [4096]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
                std.fs.File.stdout().writeAll(msg) catch {};
            },
            .silent => {},
        }
    }
};

pub fn levelTag(level: Level) []const u8 {
    return switch (level) {
        .off => "OFF",
        .err => "ERR",
        .warn => "WARN",
        .info => "INFO",
        .debug => "DEBUG",
        .trace => "TRACE",
    };
}

pub const ScopedLogger = struct {
    logger: Logger,
    scope: []const u8,

    pub fn err(self: ScopedLogger, comptime fmt: []const u8, args: anytype) void {
        self.logger.err("[{s}] " ++ fmt, .{self.scope} ++ args);
    }

    pub fn warn(self: ScopedLogger, comptime fmt: []const u8, args: anytype) void {
        self.logger.warn("[{s}] " ++ fmt, .{self.scope} ++ args);
    }

    pub fn info(self: ScopedLogger, comptime fmt: []const u8, args: anytype) void {
        self.logger.info("[{s}] " ++ fmt, .{self.scope} ++ args);
    }

    pub fn debug(self: ScopedLogger, comptime fmt: []const u8, args: anytype) void {
        self.logger.debug("[{s}] " ++ fmt, .{self.scope} ++ args);
    }

    pub fn trace(self: ScopedLogger, comptime fmt: []const u8, args: anytype) void {
        self.logger.trace("[{s}] " ++ fmt, .{self.scope} ++ args);
    }
};

pub fn scoped(logger: Logger, scope: []const u8) ScopedLogger {
    return .{ .logger = logger, .scope = scope };
}

pub const global: Logger = .{};

pub fn default() Logger {
    return Logger.init();
}

pub fn silent() Logger {
    return Logger.init().withSink(.silent);
}

pub fn debug() Logger {
    return Logger.init().withLevel(.debug);
}

pub fn trace() Logger {
    return Logger.init().withLevel(.trace);
}

test "Logger default level is info" {
    const l = Logger.init();
    try std.testing.expectEqual(Level.info, l.level);
}

test "Logger default sink is stderr" {
    const l = Logger.init();
    try std.testing.expectEqual(Sink.stderr, l.sink);
}

test "Logger withLevel returns new logger" {
    const l = Logger.init().withLevel(.debug);
    try std.testing.expectEqual(Level.debug, l.level);
    try std.testing.expectEqual(Level.info, Logger.init().level);
}

test "Logger withSink returns new logger" {
    const l = Logger.init().withSink(.silent);
    try std.testing.expectEqual(Sink.silent, l.sink);
}

test "Logger withFormat returns new logger" {
    const l = Logger.init().withFormat(.json);
    try std.testing.expectEqual(Format.json, l.format);
}

test "Logger withScope sets scope" {
    const l = Logger.init().withScope("vm");
    try std.testing.expectEqualStrings("vm", l.scope.?);
}

test "Logger enabled filtering" {
    const l = Logger.init().withLevel(.warn);
    try std.testing.expect(l.enabled(.err));
    try std.testing.expect(l.enabled(.warn));
    try std.testing.expect(!l.enabled(.info));
    try std.testing.expect(!l.enabled(.debug));
    try std.testing.expect(!l.enabled(.trace));
}

test "Logger silent" {
    const l = Logger.init().withSink(.silent);
    try std.testing.expect(l.isSilent());
}

test "Logger off level is silent" {
    const l = Logger.init().withLevel(.off);
    try std.testing.expect(l.isSilent());
}

test "level tags" {
    try std.testing.expectEqualStrings("ERR", levelTag(.err));
    try std.testing.expectEqualStrings("WARN", levelTag(.warn));
    try std.testing.expectEqualStrings("INFO", levelTag(.info));
    try std.testing.expectEqualStrings("DEBUG", levelTag(.debug));
    try std.testing.expectEqualStrings("TRACE", levelTag(.trace));
    try std.testing.expectEqualStrings("OFF", levelTag(.off));
}

test "Sink toString" {
    try std.testing.expectEqualStrings("stderr", Sink.stderr.toString());
    try std.testing.expectEqualStrings("stdout", Sink.stdout.toString());
    try std.testing.expectEqualStrings("silent", Sink.silent.toString());
}

test "Format toString" {
    try std.testing.expectEqualStrings("plain", Format.plain.toString());
    try std.testing.expectEqualStrings("json", Format.json.toString());
    try std.testing.expectEqualStrings("structured", Format.structured.toString());
}

test "global logger has info level" {
    try std.testing.expectEqual(Level.info, global.level);
}

test "default creates info logger" {
    const l = default();
    try std.testing.expectEqual(Level.info, l.level);
}

test "debug preset" {
    const l = debug();
    try std.testing.expectEqual(Level.debug, l.level);
}

test "trace preset" {
    const l = trace();
    try std.testing.expectEqual(Level.trace, l.level);
}

test "silent preset" {
    const l = silent();
    try std.testing.expect(l.isSilent());
}

test "ScopedLogger wraps logger" {
    const l = Logger.init().withSink(.silent);
    const s = scoped(l, "vm");
    try std.testing.expectEqualStrings("vm", s.scope);
}

test "scoped helper" {
    const s = scoped(Logger.init(), "test");
    try std.testing.expectEqualStrings("test", s.scope);
}

test "Logger scoped method" {
    const l = Logger.init().scoped("compiler");
    try std.testing.expectEqualStrings("compiler", l.scope.?);
}
