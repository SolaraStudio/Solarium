const std = @import("std");
const builtin = @import("builtin");

pub const Nanoseconds = i128;
pub const Microseconds = i64;
pub const Milliseconds = i64;
pub const Seconds = i64;

pub const ns_per_us: i128 = 1000;
pub const ns_per_ms: i128 = 1000 * 1000;
pub const ns_per_s: i128 = 1000 * 1000 * 1000;
pub const ns_per_min: i128 = 60 * ns_per_s;
pub const ns_per_hour: i128 = 60 * ns_per_min;
pub const ns_per_day: i128 = 24 * ns_per_hour;

pub const us_per_ms: i64 = 1000;
pub const us_per_s: i64 = 1000 * 1000;
pub const us_per_min: i64 = 60 * us_per_s;
pub const us_per_hour: i64 = 60 * us_per_min;

pub const ms_per_s: i64 = 1000;
pub const ms_per_min: i64 = 60 * ms_per_s;
pub const ms_per_hour: i64 = 60 * ms_per_min;

pub fn nowNanos() Nanoseconds {
    var ts: std.posix.timespec = .{ .sec = 0, .nsec = 0 };
    if (comptime @import("builtin").os.tag == .linux) {
        const rc = std.os.linux.clock_gettime(.MONOTONIC, &ts);
        if (rc != 0) return 0;
    } else {
        const rc = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
        if (rc != 0) return 0;
    }
    return @as(Nanoseconds, ts.sec) * ns_per_s + ts.nsec;
}

pub fn nowMicros() Microseconds {
    return @intCast(@divTrunc(nowNanos(), ns_per_us));
}

pub fn nowMillis() Milliseconds {
    return @intCast(@divTrunc(nowNanos(), ns_per_ms));
}

pub fn nowSeconds() Seconds {
    return @intCast(@divTrunc(nowNanos(), ns_per_s));
}

pub const Duration = struct {
    nanos: Nanoseconds,

    pub fn fromNanos(n: Nanoseconds) Duration {
        return .{ .nanos = n };
    }

    pub fn fromMicros(us: Microseconds) Duration {
        return .{ .nanos = @as(Nanoseconds, us) * ns_per_us };
    }

    pub fn fromMillis(ms: Milliseconds) Duration {
        return .{ .nanos = @as(Nanoseconds, ms) * ns_per_ms };
    }

    pub fn fromSeconds(s: Seconds) Duration {
        return .{ .nanos = @as(Nanoseconds, s) * ns_per_s };
    }

    pub fn fromMinutes(m: i64) Duration {
        return .{ .nanos = @as(Nanoseconds, m) * ns_per_min };
    }

    pub fn fromHours(h: i64) Duration {
        return .{ .nanos = @as(Nanoseconds, h) * ns_per_hour };
    }

    pub fn fromDays(d: i64) Duration {
        return .{ .nanos = @as(Nanoseconds, d) * ns_per_day };
    }

    pub fn zero() Duration {
        return .{ .nanos = 0 };
    }

    pub fn toNanos(self: Duration) Nanoseconds {
        return self.nanos;
    }

    pub fn toMicros(self: Duration) Microseconds {
        return @intCast(@divTrunc(self.nanos, ns_per_us));
    }

    pub fn toMillis(self: Duration) Milliseconds {
        return @intCast(@divTrunc(self.nanos, ns_per_ms));
    }

    pub fn toSeconds(self: Duration) Seconds {
        return @intCast(@divTrunc(self.nanos, ns_per_s));
    }

    pub fn toMinutes(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanos, ns_per_min));
    }

    pub fn toHours(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanos, ns_per_hour));
    }

    pub fn toDays(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanos, ns_per_day));
    }

    pub fn toFloatSeconds(self: Duration) f64 {
        return @as(f64, @floatFromInt(self.nanos)) / @as(f64, @floatFromInt(ns_per_s));
    }

    pub fn toFloatMillis(self: Duration) f64 {
        return @as(f64, @floatFromInt(self.nanos)) / @as(f64, @floatFromInt(ns_per_ms));
    }

    pub fn add(self: Duration, other: Duration) Duration {
        return .{ .nanos = self.nanos + other.nanos };
    }

    pub fn sub(self: Duration, other: Duration) Duration {
        return .{ .nanos = self.nanos - other.nanos };
    }

    pub fn mul(self: Duration, factor: f64) Duration {
        return .{ .nanos = @intFromFloat(@as(f64, @floatFromInt(self.nanos)) * factor) };
    }

    pub fn div(self: Duration, divisor: f64) Duration {
        if (divisor == 0) return Duration.zero();
        return .{ .nanos = @intFromFloat(@as(f64, @floatFromInt(self.nanos)) / divisor) };
    }

    pub fn isZero(self: Duration) bool {
        return self.nanos == 0;
    }

    pub fn isPositive(self: Duration) bool {
        return self.nanos > 0;
    }

    pub fn isNegative(self: Duration) bool {
        return self.nanos < 0;
    }

    pub fn abs(self: Duration) Duration {
        return .{ .nanos = if (self.nanos < 0) -self.nanos else self.nanos };
    }

    pub fn order(self: Duration, other: Duration) std.math.Order {
        return std.math.order(self.nanos, other.nanos);
    }

    pub fn eql(self: Duration, other: Duration) bool {
        return self.nanos == other.nanos;
    }

    pub fn lessThan(self: Duration, other: Duration) bool {
        return self.nanos < other.nanos;
    }

    pub fn greaterThan(self: Duration, other: Duration) bool {
        return self.nanos > other.nanos;
    }

    pub fn clamp(self: Duration, min_value: Duration, max_value: Duration) Duration {
        if (self.nanos < min_value.nanos) return min_value;
        if (self.nanos > max_value.nanos) return max_value;
        return self;
    }

    pub fn format(
        self: Duration,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {

        const total = self.nanos;
        if (total < 0) {
            try writer.writeAll("-");
        }
        const abs_ns: Nanoseconds = if (total < 0) -total else total;

        if (abs_ns < ns_per_us) {
            try writer.print("{d}ns", .{abs_ns});
        } else if (abs_ns < ns_per_ms) {
            try writer.print("{d}.{d:0>3}us", .{
                @divTrunc(abs_ns, ns_per_us),
                @mod(abs_ns, ns_per_us),
            });
        } else if (abs_ns < ns_per_s) {
            try writer.print("{d}.{d:0>6}ms", .{
                @divTrunc(abs_ns, ns_per_ms),
                @mod(abs_ns, ns_per_ms),
            });
        } else if (abs_ns < ns_per_min) {
            try writer.print("{d}.{d:0>9}s", .{
                @divTrunc(abs_ns, ns_per_s),
                @mod(abs_ns, ns_per_s),
            });
        } else if (abs_ns < ns_per_hour) {
            const minutes = @divTrunc(abs_ns, ns_per_min);
            const remainder = @mod(abs_ns, ns_per_min);
            try writer.print("{d}m {d}.{d:0>9}s", .{
                minutes,
                @divTrunc(remainder, ns_per_s),
                @mod(remainder, ns_per_s),
            });
        } else {
            const hours = @divTrunc(abs_ns, ns_per_hour);
            const remainder = @mod(abs_ns, ns_per_hour);
            try writer.print("{d}h {d}m", .{
                hours,
                @divTrunc(remainder, ns_per_min),
            });
        }
    }
};

pub const Timer = struct {
    start_ns: Nanoseconds,
    running: bool,
    accumulated: Nanoseconds,

    pub fn start() Timer {
        return .{
            .start_ns = nowNanos(),
            .running = true,
            .accumulated = 0,
        };
    }

    pub fn stopped() Timer {
        return .{
            .start_ns = 0,
            .running = false,
            .accumulated = 0,
        };
    }

    pub fn stop(self: *Timer) Duration {
        if (self.running) {
            self.accumulated += nowNanos() - self.start_ns;
            self.running = false;
        }
        return Duration.fromNanos(self.accumulated);
    }

    pub fn resumeTimer(self: *Timer) void {
        if (!self.running) {
            self.start_ns = nowNanos();
            self.running = true;
        }
    }

    pub fn reset(self: *Timer) void {
        self.accumulated = 0;
        if (self.running) {
            self.start_ns = nowNanos();
        }
    }

    pub fn elapsed(self: Timer) Duration {
        if (self.running) {
            return Duration.fromNanos(self.accumulated + (nowNanos() - self.start_ns));
        }
        return Duration.fromNanos(self.accumulated);
    }

    pub fn elapsedMillis(self: Timer) Milliseconds {
        return self.elapsed().toMillis();
    }

    pub fn elapsedMicros(self: Timer) Microseconds {
        return self.elapsed().toMicros();
    }

    pub fn elapsedNanos(self: Timer) Nanoseconds {
        return self.elapsed().nanos;
    }

    pub fn isRunning(self: Timer) bool {
        return self.running;
    }
};

pub fn measure(comptime f: anytype, args: anytype) struct { result: @TypeOf(@call(.auto, f, args)), duration: Duration } {
    const start_ns = nowNanos();
    const result = @call(.auto, f, args);
    const elapsed = nowNanos() - start_ns;
    return .{ .result = result, .duration = Duration.fromNanos(elapsed) };
}

pub fn sleepNanos(n: Nanoseconds) void {
    if (n <= 0) return;
    const ns: u64 = @intCast(n);
    var req: std.os.linux.timespec = .{
        .sec = @intCast(ns / 1_000_000_000),
        .nsec = @intCast(ns % 1_000_000_000),
    };
    var rem: std.os.linux.timespec = undefined;
    while (true) {
        const rc = std.os.linux.nanosleep(&req, &rem);
        switch (rc) {
            0 => return,
            4 => {
                req = rem;
                continue;
            },
            else => return,
        }
    }
}

pub fn sleepMicros(us: Microseconds) void {
    if (us <= 0) return;
    sleepNanos(@as(Nanoseconds, us) * 1000);
}

pub fn sleepMillis(ms: Milliseconds) void {
    if (ms <= 0) return;
    sleepNanos(@as(Nanoseconds, ms) * 1_000_000);
}

pub fn sleepSeconds(s: Seconds) void {
    if (s <= 0) return;
    sleepNanos(@as(Nanoseconds, s) * 1_000_000_000);
}

test "now functions are monotonic" {
    const a = nowNanos();
    const b = nowNanos();
    try std.testing.expect(b >= a);
}

test "nowMillis and nowSeconds exist" {
    const ms = nowMillis();
    const s = nowSeconds();
    try std.testing.expect(ms > 0);
    try std.testing.expect(s > 0);
}

test "Duration from constructors" {
    try std.testing.expectEqual(@as(Nanoseconds, 1), Duration.fromNanos(1).nanos);
    try std.testing.expectEqual(@as(Nanoseconds, 1000), Duration.fromMicros(1).nanos);
    try std.testing.expectEqual(@as(Nanoseconds, 1000000), Duration.fromMillis(1).nanos);
    try std.testing.expectEqual(@as(Nanoseconds, 1000000000), Duration.fromSeconds(1).nanos);
    try std.testing.expectEqual(@as(Nanoseconds, 60 * 1000000000), Duration.fromMinutes(1).nanos);
    try std.testing.expectEqual(@as(Nanoseconds, 3600 * 1000000000), Duration.fromHours(1).nanos);
}

test "Duration to conversions round trip" {
    const d = Duration.fromSeconds(5);
    try std.testing.expectEqual(@as(Seconds, 5), d.toSeconds());
    try std.testing.expectEqual(@as(Milliseconds, 5000), d.toMillis());
    try std.testing.expectEqual(@as(Microseconds, 5000000), d.toMicros());
    try std.testing.expectEqual(@as(Nanoseconds, 5000000000), d.toNanos());
}

test "Duration to minutes hours days" {
    const d = Duration.fromHours(2);
    try std.testing.expectEqual(@as(i64, 120), d.toMinutes());
    try std.testing.expectEqual(@as(i64, 2), d.toHours());
    try std.testing.expectEqual(@as(i64, 0), d.toDays());

    const d2 = Duration.fromDays(1);
    try std.testing.expectEqual(@as(i64, 24), d2.toHours());
    try std.testing.expectEqual(@as(i64, 1), d2.toDays());
}

test "Duration to float" {
    const d = Duration.fromMillis(1500);
    try std.testing.expectEqual(@as(f64, 1.5), d.toFloatSeconds());
    try std.testing.expectEqual(@as(f64, 1500.0), d.toFloatMillis());
}

test "Duration zero" {
    try std.testing.expect(Duration.zero().isZero());
    try std.testing.expect(!Duration.fromSeconds(1).isZero());
}

test "Duration isPositive isNegative" {
    try std.testing.expect(Duration.fromSeconds(1).isPositive());
    try std.testing.expect(!Duration.fromSeconds(1).isNegative());
    try std.testing.expect(Duration.fromSeconds(-1).isNegative());
}

test "Duration abs" {
    const d = Duration.fromSeconds(-5);
    try std.testing.expectEqual(@as(Seconds, 5), d.abs().toSeconds());
}

test "Duration add sub mul div" {
    const a = Duration.fromSeconds(10);
    const b = Duration.fromSeconds(5);
    try std.testing.expectEqual(@as(Seconds, 15), a.add(b).toSeconds());
    try std.testing.expectEqual(@as(Seconds, 5), a.sub(b).toSeconds());
    try std.testing.expectEqual(@as(Seconds, 20), a.mul(2.0).toSeconds());
    try std.testing.expectEqual(@as(Seconds, 5), a.div(2.0).toSeconds());
}

test "Duration div by zero" {
    const a = Duration.fromSeconds(10);
    try std.testing.expect(a.div(0.0).isZero());
}

test "Duration comparison" {
    const a = Duration.fromSeconds(10);
    const b = Duration.fromSeconds(5);
    try std.testing.expect(a.greaterThan(b));
    try std.testing.expect(b.lessThan(a));
    try std.testing.expect(a.eql(a));
    try std.testing.expect(!a.eql(b));
}

test "Duration clamp" {
    const d = Duration.fromSeconds(50);
    const clamped = d.clamp(Duration.fromSeconds(0), Duration.fromSeconds(10));
    try std.testing.expectEqual(@as(Seconds, 10), clamped.toSeconds());
}

test "Timer basic" {
    var t = Timer.start();
    sleepMillis(1);
    const elapsed = t.stop();
    try std.testing.expect(elapsed.toMillis() >= 1);
}

test "Timer stop while running" {
    var t = Timer.start();
    try std.testing.expect(t.isRunning());
    _ = t.stop();
    try std.testing.expect(!t.isRunning());
}

test "Timer resume accumulates" {
    var t = Timer.start();
    sleepMillis(1);
    _ = t.stop();
    sleepMillis(5);
    t.resumeTimer();
    sleepMillis(1);
    const total = t.stop();
    try std.testing.expect(total.toMillis() >= 2);
    try std.testing.expect(total.toMillis() < 100);
}

test "Timer reset" {
    var t = Timer.start();
    sleepMillis(5);
    t.reset();
    const elapsed = t.stop();
    try std.testing.expect(elapsed.toMillis() < 5);
}

test "Timer stopped never runs" {
    var t = Timer.stopped();
    try std.testing.expect(!t.isRunning());
    const elapsed = t.elapsed();
    try std.testing.expect(elapsed.isZero());
}

test "measure function" {
    const result = measure(testAdd, .{ @as(u32, 3), @as(u32, 4) });
    try std.testing.expectEqual(@as(u32, 7), result.result);
    try std.testing.expect(result.duration.toNanos() >= 0);
}

fn testAdd(a: u32, b: u32) u32 {
    return a + b;
}

test "sleepNanos too small no-op" {
    sleepNanos(0);
    sleepNanos(-1);
}

test "sleepMillis basic" {
    const start = nowMillis();
    sleepMillis(2);
    const elapsed = nowMillis() - start;
    try std.testing.expect(elapsed >= 1);
}

test "Duration format microseconds" {
    var buf: [64]u8 = undefined;
    const d = Duration.fromMicros(500);
    var writer = std.Io.Writer.fixed(&buf);
    try writer.print("{f}", .{d});
    const s = writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, s, "us") != null);
}

test "Duration format milliseconds" {
    var buf: [64]u8 = undefined;
    const d = Duration.fromMillis(500);
    var writer = std.Io.Writer.fixed(&buf);
    try writer.print("{f}", .{d});
    const s = writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, s, "ms") != null);
}

test "Duration format seconds" {
    var buf: [64]u8 = undefined;
    const d = Duration.fromSeconds(5);
    var writer = std.Io.Writer.fixed(&buf);
        try writer.print("{f}", .{d});
        const s = writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, s, "s") != null);
}
