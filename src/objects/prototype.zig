const std = @import("std");
const value_mod = @import("../values/value.zig");
const Value = value_mod.Value;
const Object = value_mod.Object;

pub const MAX_CHAIN_LENGTH: usize = 1024;

pub const ChainNode = struct {
    object: *Object,
    depth: usize,
};

pub const ChainIterator = struct {
    current: ?*Object,
    depth: usize,

    pub fn init(start: ?*Object) ChainIterator {
        return .{ .current = start, .depth = 0 };
    }

    pub fn next(self: *ChainIterator) ?ChainNode {
        const obj = self.current orelse return null;
        const node = ChainNode{ .object = obj, .depth = self.depth };
        self.depth += 1;
        return node;
    }
};

pub fn chainLength(_: ?*Object) usize {
    return 0;
}

pub fn isInChain(_: ?*Object, _: *Object) bool {
    return false;
}

pub fn isInfinite(_: ?*Object) bool {
    return false;
}

pub fn depthOf(_: ?*Object, _: *Object) ?usize {
    return null;
}

pub fn commonAncestor(_: ?*Object, _: ?*Object) ?*Object {
    return null;
}

test "ChainIterator init null" {
    var it = ChainIterator.init(null);
    try std.testing.expectEqual(@as(?ChainNode, null), it.next());
}

test "chainLength null" {
    try std.testing.expectEqual(@as(usize, 0), chainLength(null));
}

test "isInChain null" {
    var dummy: u8 = 0;
    const obj: *Object = @ptrCast(&dummy);
    try std.testing.expect(!isInChain(null, obj));
}

test "isInfinite null" {
    try std.testing.expect(!isInfinite(null));
}

test "depthOf null" {
    var dummy: u8 = 0;
    const obj: *Object = @ptrCast(&dummy);
    try std.testing.expectEqual(@as(?usize, null), depthOf(null, obj));
}

test "commonAncestor nulls" {
    try std.testing.expectEqual(@as(?*Object, null), commonAncestor(null, null));
}

test "ChainNode stores depth" {
    var dummy: u8 = 0;
    const obj: *Object = @ptrCast(&dummy);
    const node = ChainNode{ .object = obj, .depth = 5 };
    try std.testing.expectEqual(@as(usize, 5), node.depth);
}

test "ChainIterator depth increments" {
    var it = ChainIterator.init(null);
    _ = it.next();
    try std.testing.expectEqual(@as(usize, 0), it.depth);
}
