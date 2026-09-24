const std = @import("std");

pub const RopeError = error{
    Empty,
    InvalidRange,
};

pub const Leaf = struct {
    text: []const u8,

    pub fn len(self: Leaf) usize {
        return self.text.len;
    }
};

pub const Node = union(enum) {
    leaf: Leaf,
    branch: Branch,

    pub fn len(self: Node) usize {
        return switch (self) {
            .leaf => |l| l.text.len,
            .branch => |b| b.len,
        };
    }

    pub fn depth(self: Node) usize {
        return switch (self) {
            .leaf => 0,
            .branch => |b| 1 + @max(b.left.depth(), b.right.depth()),
        };
    }
};

pub const Branch = struct {
    left: *Node,
    right: *Node,
    len: usize,
};

pub const Rope = struct {
    root: ?*Node,
    allocator: std.mem.Allocator,
    total_len: usize,

    pub fn init(allocator: std.mem.Allocator) Rope {
        return .{
            .root = null,
            .allocator = allocator,
            .total_len = 0,
        };
    }

    pub fn deinit(self: *Rope) void {
        if (self.root) |root| {
            self.freeNode(root);
        }
        self.root = null;
        self.total_len = 0;
    }

    fn freeNode(self: *Rope, node: *Node) void {
        switch (node.*) {
            .leaf => {},
            .branch => |b| {
                self.freeNode(b.left);
                self.freeNode(b.right);
            },
        }
        self.allocator.destroy(node);
    }

    pub fn len(self: Rope) usize {
        return self.total_len;
    }

    pub fn isEmpty(self: Rope) bool {
        return self.total_len == 0;
    }

    pub fn append(self: *Rope, text: []const u8) !void {
        if (text.len == 0) return;

        const leaf = try self.allocator.create(Node);
        leaf.* = .{ .leaf = .{ .text = text } };

        if (self.root == null) {
            self.root = leaf;
            self.total_len = text.len;
            return;
        }

        const branch = try self.allocator.create(Node);
        branch.* = .{ .branch = .{
            .left = self.root.?,
            .right = leaf,
            .len = self.total_len + text.len,
        } };

        self.root = branch;
        self.total_len += text.len;
    }

    pub fn concat(self: *Rope, other: *Rope) !void {
        if (other.total_len == 0) return;
        if (self.total_len == 0) {
            self.root = other.root;
            self.total_len = other.total_len;
            other.root = null;
            other.total_len = 0;
            return;
       }
       if (self.root == null or other.root == null) return;

       const other_root = other.root.?;
       const other_len = other.total_len;

       const branch = try self.allocator.create(Node);
       branch.* = .{ .branch = .{
           .left = self.root.?,
           .right = other_root,
           .len = self.total_len + other_len,
       } };
       self.root = branch;
       self.total_len += other_len;

       other.root = null;
       other.total_len = 0;
    }

    pub fn toString(self: Rope) ![]u8 {
        const buf = try self.allocator.alloc(u8, self.total_len);
        if (self.root) |root| {
            var pos: usize = 0;
            self.writeTo(root, buf, &pos);
        }
        return buf;
    }

    fn writeTo(self: *const Rope, node: *Node, buf: []u8, pos: *usize) void {
        switch (node.*) {
            .leaf => |l| {
                @memcpy(buf[pos.* .. pos.* + l.text.len], l.text);
                pos.* += l.text.len;
            },
            .branch => |b| {
                self.writeTo(b.left, buf, pos);
                self.writeTo(b.right, buf, pos);
            },
        }
    }

    pub fn charAt(self: Rope, index: usize) ?u8 {
        if (index >= self.total_len) return null;
        if (self.root == null) return null;
        return self.charAtNode(self.root.?, index);
    }

    fn charAtNode(self: *const Rope, node: *Node, index: usize) ?u8 {
        switch (node.*) {
            .leaf => |l| {
                if (index >= l.text.len) return null;
                return l.text[index];
            },
            .branch => |b| {
                const left_len = b.left.len();
                if (index < left_len) {
                    return self.charAtNode(b.left, index);
                }
                return self.charAtNode(b.right, index - left_len);
            },
        }
    }

    pub fn depth(self: Rope) usize {
        if (self.root) |r| return r.depth();
        return 0;
    }

    pub fn nodeCount(self: Rope) usize {
        if (self.root) |r| return self.countNodes(r);
        return 0;
    }

    fn countNodes(self: *const Rope, node: *Node) usize {
        return switch (node.*) {
            .leaf => 1,
            .branch => |b| 1 + self.countNodes(b.left) + self.countNodes(b.right),
        };
    }

    pub fn leafCount(self: Rope) usize {
        if (self.root) |r| return self.countLeaves(r);
        return 0;
    }

    fn countLeaves(self: *const Rope, node: *Node) usize {
        return switch (node.*) {
            .leaf => 1,
            .branch => |b| self.countLeaves(b.left) + self.countLeaves(b.right),
        };
    }
};

pub fn fromSlice(allocator: std.mem.Allocator, text: []const u8) !Rope {
    var rope = Rope.init(allocator);
    try rope.append(text);
    return rope;
}

pub fn join(allocator: std.mem.Allocator, pieces: []const []const u8) !Rope {
    var rope = Rope.init(allocator);
    for (pieces) |piece| {
        try rope.append(piece);
    }
    return rope;
}

test "init empty" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try std.testing.expectEqual(@as(usize, 0), rope.len());
    try std.testing.expect(rope.isEmpty());
}

test "append single" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("hello");
    try std.testing.expectEqual(@as(usize, 5), rope.len());
    try std.testing.expect(!rope.isEmpty());
}

test "append empty is no-op" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("");
    try std.testing.expectEqual(@as(usize, 0), rope.len());
}

test "append multiple" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("hello");
    try rope.append(" ");
    try rope.append("world");
    try std.testing.expectEqual(@as(usize, 11), rope.len());
}

test "toString" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("hello");
    try rope.append(" ");
    try rope.append("world");

    const s = try rope.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("hello world", s);
}

test "toString empty" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    const s = try rope.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqual(@as(usize, 0), s.len);
}

test "charAt" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("abc");
    try rope.append("def");

    try std.testing.expectEqual(@as(?u8, 'a'), rope.charAt(0));
    try std.testing.expectEqual(@as(?u8, 'c'), rope.charAt(2));
    try std.testing.expectEqual(@as(?u8, 'd'), rope.charAt(3));
    try std.testing.expectEqual(@as(?u8, 'f'), rope.charAt(5));
    try std.testing.expectEqual(@as(?u8, null), rope.charAt(6));
}

test "depth grows with appends" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("a");
    try std.testing.expectEqual(@as(usize, 0), rope.depth());
    try rope.append("b");
    try std.testing.expectEqual(@as(usize, 1), rope.depth());
    try rope.append("c");
    try std.testing.expectEqual(@as(usize, 2), rope.depth());
}

test "leafCount" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("a");
    try rope.append("b");
    try rope.append("c");
    try std.testing.expectEqual(@as(usize, 3), rope.leafCount());
}

test "nodeCount" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();
    try rope.append("a");
    try rope.append("b");
    try std.testing.expectEqual(@as(usize, 3), rope.nodeCount());
}

test "concat" {
    var a = Rope.init(std.testing.allocator);
    defer a.deinit();
    var b = Rope.init(std.testing.allocator);
    defer b.deinit();

    try a.append("hello");
    try b.append("world");

    try a.concat(&b);

    const s = try a.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("helloworld", s);
}

test "concat with empty" {
    var a = Rope.init(std.testing.allocator);
    defer a.deinit();
    var b = Rope.init(std.testing.allocator);
    defer b.deinit();

    try a.append("hello");
    try a.concat(&b);

    const s = try a.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("hello", s);
}

test "fromSlice" {
    var rope = try fromSlice(std.testing.allocator, "hello");
    defer rope.deinit();
    try std.testing.expectEqual(@as(usize, 5), rope.len());
}

test "join" {
    const pieces = [_][]const u8{ "hello", " ", "world" };
    var rope = try join(std.testing.allocator, &pieces);
    defer rope.deinit();

    const s = try rope.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("hello world", s);
}

test "large rope" {
    var rope = Rope.init(std.testing.allocator);
    defer rope.deinit();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try rope.append("ab");
    }

    try std.testing.expectEqual(@as(usize, 200), rope.len());
    const s = try rope.toString();
    defer std.testing.allocator.free(s);
    try std.testing.expectEqual(@as(usize, 200), s.len);
}
