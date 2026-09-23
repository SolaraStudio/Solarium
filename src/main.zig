const std = @import("std");
const solarium = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var stdout_buf = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = stdout_buf.writer();
    defer stdout_buf.flush() catch {};

    var stderr_buf = std.io.bufferedWriter(std.io.getStdErr().writer());
    const stderr = stderr_buf.writer();
    defer stderr_buf.flush() catch {};

    if (args.len < 2) {
        try stderr.writeAll("usage: solarium <file.js>\n");
        try stderr.writeAll("       solarium -e \"<expression>\"\n");
        return error.InvalidArguments;
    }

    var runtime = try solarium.Runtime.init(allocator);
    defer runtime.deinit();

    if (std.mem.eql(u8, args[1], "-e")) {
        if (args.len < 3) {
            try stderr.writeAll("error: -e requires an expression\n");
            return error.InvalidArguments;
        }
        const result = runtime.eval(args[2]) catch |err| {
            try stderr.print("error: {s}\n", .{@errorName(err)});
            return err;
        };
        try stdout.print("{s}\n", .{result});
        return;
    }

    const path = args[1];
    const source = std.fs.cwd().readFileAlloc(allocator, path, 16 * 1024 * 1024) catch |err| {
        try stderr.print("error: cannot read {s}: {s}\n", .{ path, @errorName(err) });
        return err;
    };
    defer allocator.free(source);

    const result = runtime.eval(source) catch |err| {
        try stderr.print("error: {s}\n", .{@errorName(err)});
        return err;
    };
    try stdout.print("{s}\n", .{result});
}
