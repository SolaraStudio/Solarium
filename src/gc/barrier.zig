const std = @import("std");
const value_mod = @import("../values/value.zig");
const heap_mod = @import("heap.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Heap = heap_mod.Heap;

pub const BarrierError = error{
    OutOfMemory,
    InvalidObject,
    BarrierViolation,
};

pub const BarrierKind = enum(u8) {
    none,
    incremental_update,
    snapshot_at_beginning,
    deletion,
    insertion,
    hybrid,

    pub fn toString(self: BarrierKind) []const u8 {
        return @tagName(self);
    }

    pub fn isIncremental(self: BarrierKind) bool {
        return self == .incremental_update;
    }

    pub fn isSnapshot(self: BarrierKind) bool {
        return self == .snapshot_at_beginning;
    }

    pub fn isHybrid(self: BarrierKind) bool {
        return self == .hybrid;
    }
};

pub const WriteKind = enum(u8) {
    field_store,
    array_store,
    global_store,
    upvalue_store,
    slot_store,

    pub fn toString(self: WriteKind) []const u8 {
        return @tagName(self);
    }
};

pub const BarrierStats = struct {
    barriers_called: usize = 0,
    objects_shaded: usize = 0,
    values_shaded: usize = 0,
    writes_observed: usize = 0,
    writes_rejected: usize = 0,

    pub fn init() BarrierStats {
        return .{};
    }

    pub fn recordBarrier(self: *BarrierStats) void {
        self.barriers_called += 1;
    }

    pub fn recordShade(self: *BarrierStats, is_object: bool) void {
        if (is_object) {
            self.objects_shaded += 1;
        } else {
            self.values_shaded += 1;
        }
    }

    pub fn recordWrite(self: *BarrierStats) void {
        self.writes_observed += 1;
    }

    pub fn recordReject(self: *BarrierStats) void {
        self.writes_rejected += 1;
    }
};

pub const Card = struct {
    offset: u32,
    dirty: bool,
    writes: u32,

    pub fn init(offset: u32) Card {
        return .{
            .offset = offset,
            .dirty = false,
            .writes = 0,
        };
    }

    pub fn markDirty(self: *Card) void {
        self.dirty = true;
        self.writes += 1;
    }

    pub fn clear(self: *Card) void {
        self.dirty = false;
        self.writes = 0;
    }
};

pub const CardTable = struct {
    allocator: std.mem.Allocator,
    cards: std.ArrayList(Card),
    card_size: u32,
    dirty_count: usize,

    pub fn init(allocator: std.mem.Allocator, card_size: u32) CardTable {
        return .{
            .allocator = allocator,
            .cards = .empty,
            .card_size = card_size,
            .dirty_count = 0,
        };
    }

    pub fn deinit(self: *CardTable) void {
        self.cards.deinit(self.allocator);
    }

    pub fn cardCount(self: CardTable) usize {
        return self.cards.items.len;
    }

    pub fn ensureCapacity(self: *CardTable, count: usize) !void {
        while (self.cards.items.len < count) {
            const offset: u32 = @intCast(self.cards.items.len * self.card_size);
            try self.cards.append(self.allocator, Card.init(offset));
        }
    }

    pub fn markDirty(self: *CardTable, addr: usize) !void {
        const index = addr / self.card_size;
        try self.ensureCapacity(index + 1);
        if (index < self.cards.items.len) {
            if (!self.cards.items[index].dirty) {
                self.dirty_count += 1;
            }
            self.cards.items[index].markDirty();
        }
    }

    pub fn isDirty(self: CardTable, addr: usize) bool {
        const index = addr / self.card_size;
        if (index >= self.cards.items.len) return false;
        return self.cards.items[index].dirty;
    }

    pub fn clearAll(self: *CardTable) void {
        for (self.cards.items) |*c| {
            c.clear();
        }
        self.dirty_count = 0;
    }

    pub fn getDirtyCount(self: CardTable) usize {
        return self.dirty_count;
    }

    pub fn iterateDirty(self: *CardTable, visitor: anytype) void {
        for (self.cards.items) |card| {
            if (card.dirty) {
                visitor.visit(card);
            }
        }
    }
};

pub const Barrier = struct {
    allocator: std.mem.Allocator,
    heap: *Heap,
    kind: BarrierKind,
    stats: BarrierStats,
    card_table: CardTable,
    active: bool,
    shade_stack: std.ArrayList(*Object),

    pub fn init(allocator: std.mem.Allocator, heap: *Heap) Barrier {
        return .{
            .allocator = allocator,
            .heap = heap,
            .kind = .incremental_update,
            .stats = BarrierStats.init(),
            .card_table = CardTable.init(allocator, 512),
            .active = false,
            .shade_stack = .empty,
        };
    }

    pub fn deinit(self: *Barrier) void {
        self.card_table.deinit();
        self.shade_stack.deinit(self.allocator);
    }

    pub fn activate(self: *Barrier) void {
        self.active = true;
    }

    pub fn deactivate(self: *Barrier) void {
        self.active = false;
        self.card_table.clearAll();
    }

    pub fn isActive(self: Barrier) bool {
        return self.active;
    }

    pub fn setKind(self: *Barrier, kind: BarrierKind) void {
        self.kind = kind;
    }

    pub fn reset(self: *Barrier) void {
        self.stats = BarrierStats.init();
        self.card_table.clearAll();
        self.shade_stack.clearRetainingCapacity();
    }

    pub fn recordWrite(
        self: *Barrier,
        container_addr: usize,
        value: Value,
    ) BarrierError!void {
        self.stats.recordWrite();

        if (!self.active) return;
        if (self.kind == .none) return;

        self.stats.recordBarrier();

        try self.shade(value);

        try self.card_table.markDirty(container_addr);
    }

    pub fn shade(self: *Barrier, value: Value) BarrierError!void {
        if (!value.isObject()) {
            self.stats.recordShade(false);
            return;
        }

        const obj = value.asObject().?;
        self.stats.recordShade(true);

        const concrete: *Object = @ptrCast(@alignCast(obj));
        _ = self.heap.markObject(concrete);

        try self.shade_stack.append(self.allocator, concrete);
    }

    pub fn drainShade(self: *Barrier) void {
        self.shade_stack.clearRetainingCapacity();
    }

    pub fn processDirtyCards(self: *Barrier, visitor: anytype) void {
        self.card_table.iterateDirty(visitor);
    }

    pub fn barrierKind(self: Barrier) BarrierKind {
        return self.kind;
    }

    pub fn getStats(self: Barrier) BarrierStats {
        return self.stats;
    }

    pub fn dirtyCount(self: Barrier) usize {
        return self.card_table.getDirtyCount();
    }

    pub fn shadeCount(self: Barrier) usize {
        return self.shade_stack.items.len;
    }
};

pub fn createBarrier(allocator: std.mem.Allocator, heap: *Heap) !*Barrier {
    const b = try allocator.create(Barrier);
    b.* = Barrier.init(allocator, heap);
    return b;
}

pub fn destroyBarrier(b: *Barrier) void {
    const allocator = b.allocator;
    b.deinit();
    allocator.destroy(b);
}

pub const CardVisitor = struct {
    count: usize,

    pub fn init() CardVisitor {
        return .{ .count = 0 };
    }

    pub fn visit(self: *CardVisitor, card: Card) void {
        _ = card;
        self.count += 1;
    }
};

pub fn needsBarrier(heap: *Heap, obj: *Object) bool {
    const h = heap.findHeader(obj) orelse return false;
    return h.isMarked();
}

pub fn isBlackObject(heap: *Heap, obj: *Object) bool {
    const h = heap.findHeader(obj) orelse return false;
    return h.isMarked();
}

pub fn isWhiteObject(heap: *Heap, obj: *Object) bool {
    const h = heap.findHeader(obj) orelse return false;
    return !h.isMarked();
}

test "BarrierKind toString" {
    try std.testing.expectEqualStrings("none", BarrierKind.none.toString());
    try std.testing.expectEqualStrings("incremental_update", BarrierKind.incremental_update.toString());
    try std.testing.expectEqualStrings("snapshot_at_beginning", BarrierKind.snapshot_at_beginning.toString());
    try std.testing.expectEqualStrings("hybrid", BarrierKind.hybrid.toString());
}

test "BarrierKind predicates" {
    try std.testing.expect(BarrierKind.incremental_update.isIncremental());
    try std.testing.expect(BarrierKind.snapshot_at_beginning.isSnapshot());
    try std.testing.expect(BarrierKind.hybrid.isHybrid());
    try std.testing.expect(!BarrierKind.none.isIncremental());
}

test "WriteKind toString" {
    try std.testing.expectEqualStrings("field_store", WriteKind.field_store.toString());
    try std.testing.expectEqualStrings("array_store", WriteKind.array_store.toString());
    try std.testing.expectEqualStrings("global_store", WriteKind.global_store.toString());
}

test "BarrierStats init" {
    const s = BarrierStats.init();
    try std.testing.expectEqual(@as(usize, 0), s.barriers_called);
    try std.testing.expectEqual(@as(usize, 0), s.objects_shaded);
}

test "BarrierStats recordBarrier" {
    var s = BarrierStats.init();
    s.recordBarrier();
    s.recordBarrier();
    try std.testing.expectEqual(@as(usize, 2), s.barriers_called);
}

test "BarrierStats recordShade object" {
    var s = BarrierStats.init();
    s.recordShade(true);
    try std.testing.expectEqual(@as(usize, 1), s.objects_shaded);
}

test "BarrierStats recordShade primitive" {
    var s = BarrierStats.init();
    s.recordShade(false);
    try std.testing.expectEqual(@as(usize, 1), s.values_shaded);
}

test "BarrierStats recordWrite" {
    var s = BarrierStats.init();
    s.recordWrite();
    try std.testing.expectEqual(@as(usize, 1), s.writes_observed);
}

test "BarrierStats recordReject" {
    var s = BarrierStats.init();
    s.recordReject();
    try std.testing.expectEqual(@as(usize, 1), s.writes_rejected);
}

test "Card init" {
    const c = Card.init(0);
    try std.testing.expectEqual(@as(u32, 0), c.offset);
    try std.testing.expect(!c.dirty);
    try std.testing.expectEqual(@as(u32, 0), c.writes);
}

test "Card markDirty" {
    var c = Card.init(0);
    c.markDirty();
    try std.testing.expect(c.dirty);
    try std.testing.expectEqual(@as(u32, 1), c.writes);
}

test "Card clear" {
    var c = Card.init(0);
    c.markDirty();
    c.clear();
    try std.testing.expect(!c.dirty);
    try std.testing.expectEqual(@as(u32, 0), c.writes);
}

test "CardTable init" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();
    try std.testing.expectEqual(@as(usize, 0), ct.cardCount());
}

test "CardTable markDirty" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();

    try ct.markDirty(1000);
    try std.testing.expect(ct.isDirty(1000));
    try std.testing.expectEqual(@as(usize, 1), ct.getDirtyCount());
}

test "CardTable markDirty twice" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();

    try ct.markDirty(1000);
    try ct.markDirty(1000);
    try std.testing.expectEqual(@as(usize, 1), ct.getDirtyCount());
}

test "CardTable isDirty false" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();
    try std.testing.expect(!ct.isDirty(1000));
}

test "CardTable clearAll" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();

    try ct.markDirty(1000);
    ct.clearAll();
    try std.testing.expectEqual(@as(usize, 0), ct.getDirtyCount());
}

test "CardTable iterateDirty" {
    var ct = CardTable.init(std.testing.allocator, 512);
    defer ct.deinit();

    try ct.markDirty(0);
    try ct.markDirty(1024);

    var visitor = CardVisitor.init();
    ct.iterateDirty(&visitor);
    try std.testing.expect(visitor.count >= 2);
}

test "Barrier init" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    try std.testing.expect(!b.isActive());
    try std.testing.expectEqual(BarrierKind.incremental_update, b.barrierKind());
}

test "Barrier activate deactivate" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    b.activate();
    try std.testing.expect(b.isActive());

    b.deactivate();
    try std.testing.expect(!b.isActive());
}

test "Barrier setKind" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    b.setKind(.snapshot_at_beginning);
    try std.testing.expectEqual(BarrierKind.snapshot_at_beginning, b.barrierKind());
}

test "Barrier recordWrite inactive" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    try b.recordWrite(0, Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), b.getStats().writes_observed);
    try std.testing.expectEqual(@as(usize, 0), b.getStats().barriers_called);
}

test "Barrier recordWrite active" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    b.activate();
    try b.recordWrite(0, Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), b.getStats().barriers_called);
    try std.testing.expectEqual(@as(usize, 1), b.dirtyCount());
}

test "Barrier recordWrite object" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    b.activate();
    try b.recordWrite(0, alloc.toValue());

    try std.testing.expectEqual(@as(usize, 1), b.getStats().objects_shaded);
    try std.testing.expectEqual(@as(usize, 1), b.shadeCount());
}

test "Barrier shade primitive" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    try b.shade(Value.TRUE);
    try std.testing.expectEqual(@as(usize, 1), b.getStats().values_shaded);
}

test "Barrier drainShade" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    try b.shade(alloc.toValue());
    try std.testing.expectEqual(@as(usize, 1), b.shadeCount());

    b.drainShade();
    try std.testing.expectEqual(@as(usize, 0), b.shadeCount());
}

test "Barrier reset" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    var b = Barrier.init(std.testing.allocator, &h);
    defer b.deinit();

    b.activate();
    try b.recordWrite(0, Value.TRUE);
    b.reset();

    try std.testing.expectEqual(@as(usize, 0), b.getStats().writes_observed);
    try std.testing.expectEqual(@as(usize, 0), b.dirtyCount());
}

test "createBarrier and destroyBarrier" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const b = try createBarrier(std.testing.allocator, &h);
    destroyBarrier(b);
}

test "needsBarrier isBlackObject isWhiteObject" {
    var stats = heap_mod.Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = heap_mod.Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    try std.testing.expect(!needsBarrier(&h, alloc.toObject()));
    try std.testing.expect(isWhiteObject(&h, alloc.toObject()));

    _ = h.markObject(alloc.toObject());
    try std.testing.expect(needsBarrier(&h, alloc.toObject()));
    try std.testing.expect(isBlackObject(&h, alloc.toObject()));
}
