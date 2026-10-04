const std = @import("std");
const value_mod = @import("../values/value.zig");
const stats_mod = @import("stats.zig");

pub const Value = value_mod.Value;
pub const Object = value_mod.Object;
pub const Stats = stats_mod.Stats;

pub const HeapError = error{
    OutOfMemory,
    HeapFull,
    InvalidPointer,
    InvalidSize,
    ObjectNotFound,
    AlreadyFreed,
};

pub const DEFAULT_HEAP_SIZE: u64 = 64 * 1024 * 1024;
pub const MIN_HEAP_SIZE: u64 = 1024 * 1024;
pub const MAX_HEAP_SIZE: u64 = 4 * 1024 * 1024 * 1024;
pub const HEAP_ALIGNMENT: usize = 1;

pub const ObjectKind = enum(u8) {
    plain_object,
    array,
    function,
    string,
    symbol,
    bigint,
    regex,
    date,
    map,
    set,
    weakmap,
    weakset,
    promise,
    error_object,
    proxy,
    arraybuffer,
    typedarray,
    dataview,
    namespace,
    module,

    pub fn toString(self: ObjectKind) []const u8 {
        return @tagName(self);
    }

    pub fn isPrimitive(self: ObjectKind) bool {
        return switch (self) {
            .string, .symbol, .bigint => true,
            else => false,
        };
    }

    pub fn isCollection(self: ObjectKind) bool {
        return switch (self) {
            .map, .set, .weakmap, .weakset => true,
            else => false,
        };
    }

    pub fn isBuffer(self: ObjectKind) bool {
        return switch (self) {
            .arraybuffer, .typedarray, .dataview => true,
            else => false,
        };
    }
};

pub const ObjectHeader = struct {
    kind: ObjectKind,
    size: u64,
    marked: bool,
    pinned: bool,
    generation: u8,
    age: u8,

    pub fn init(kind: ObjectKind, size: u64) ObjectHeader {
        return .{
            .kind = kind,
            .size = size,
            .marked = false,
            .pinned = false,
            .generation = 0,
            .age = 0,
        };
    }

    pub fn mark(self: *ObjectHeader) void {
        self.marked = true;
    }

    pub fn unmark(self: *ObjectHeader) void {
        self.marked = false;
    }

    pub fn pin(self: *ObjectHeader) void {
        self.pinned = true;
    }

    pub fn isMarked(self: ObjectHeader) bool {
        return self.marked;
    }

    pub fn isPinned(self: ObjectHeader) bool {
        return self.pinned;
    }

    pub fn aged(self: ObjectHeader) ObjectHeader {
        var h = self;
        h.age +|= 1;
        return h;
    }
};

pub const Allocation = struct {
    ptr: *anyopaque,
    header: *ObjectHeader,
    size: u64,
    kind: ObjectKind,

    pub fn init(ptr: *anyopaque, header: *ObjectHeader) Allocation {
        return .{
            .ptr = ptr,
            .header = header,
            .size = header.size,
            .kind = header.kind,
        };
    }

    pub fn toObject(self: Allocation) *Object {
        return @ptrCast(@alignCast(self.ptr));
    }

    pub fn toValue(self: Allocation) Value {
        return Value.fromObject(self.toObject());
    }
};

pub const HeapBlock = struct {
    start: u64,
    size: u64,
    free: bool,
    kind: ObjectKind,

    pub fn init(start: u64, size: u64) HeapBlock {
        return .{
            .start = start,
            .size = size,
            .free = true,
            .kind = .plain_object,
        };
    }

    pub fn end(self: HeapBlock) u64 {
        return self.start + self.size;
    }

    pub fn contains(self: HeapBlock, addr: u64) bool {
        return addr >= self.start and addr < self.end();
    }
};

pub const Generation = enum(u8) {
    young,
    old,

    pub fn toString(self: Generation) []const u8 {
        return @tagName(self);
    }

    pub fn isYoung(self: Generation) bool {
        return self == .young;
    }

    pub fn isOld(self: Generation) bool {
        return self == .old;
    }
};

pub const Heap = struct {
    allocator: std.mem.Allocator,
    backing: std.mem.Allocator,
    blocks: std.ArrayList(HeapBlock),
    header_map: std.AutoHashMap(usize, *ObjectHeader),
    max_size: u64,
    current_size: u64,
    peak_size: u64,
    young_size: u64,
    old_size: u64,
    stats: *Stats,

    pub fn init(allocator: std.mem.Allocator, stats: *Stats) Heap {
        return .{
            .allocator = allocator,
            .backing = allocator,
            .blocks = .empty,
            .header_map = std.AutoHashMap(usize, *ObjectHeader).init(allocator),
            .max_size = DEFAULT_HEAP_SIZE,
            .current_size = 0,
            .peak_size = 0,
            .young_size = 0,
            .old_size = 0,
            .stats = stats,
        };
    }

    pub fn initWithSize(
        allocator: std.mem.Allocator,
        stats: *Stats,
        max_size: u64,
    ) Heap {
        var h = Heap.init(allocator, stats);
        h.max_size = std.math.clamp(max_size, MIN_HEAP_SIZE, MAX_HEAP_SIZE);
        return h;
    }

    pub fn deinit(self: *Heap) void {
        var it = self.header_map.valueIterator();
        while (it.next()) |h| {
            self.allocator.destroy(h.*);
        }
        self.header_map.deinit();
        self.blocks.deinit(self.allocator);
    }

    pub fn currentSize(self: Heap) u64 {
        return self.current_size;
    }

    pub fn peakSize(self: Heap) u64 {
        return self.peak_size;
    }

    pub fn maxSize(self: Heap) u64 {
        return self.max_size;
    }

    pub fn setMaxSize(self: *Heap, size: u64) void {
        self.max_size = std.math.clamp(size, MIN_HEAP_SIZE, MAX_HEAP_SIZE);
    }

    pub fn blockCount(self: Heap) usize {
        return self.blocks.items.len;
    }

    pub fn objectCount(self: Heap) usize {
        return self.header_map.count();
    }

    pub fn usagePercent(self: Heap) f64 {
        if (self.max_size == 0) return 0;
        return @as(f64, @floatFromInt(self.current_size)) /
            @as(f64, @floatFromInt(self.max_size)) * 100.0;
    }

    pub fn wouldExceedLimit(self: Heap, size: u64) bool {
        return self.current_size + size > self.max_size;
    }

    pub fn canAllocate(self: Heap, size: u64) bool {
        return !self.wouldExceedLimit(size);
    }

    pub fn allocate(
        self: *Heap,
        kind: ObjectKind,
        size: u64,
    ) HeapError!Allocation {
        if (size == 0) return HeapError.InvalidSize;
        if (self.wouldExceedLimit(size)) return HeapError.HeapFull;

        const slice = self.backing.alloc(u8, @intCast(size)) catch {
            return HeapError.OutOfMemory;
        };

        const object_ptr: *Object = @ptrCast(slice.ptr);

        const header = self.allocator.create(ObjectHeader) catch {
            self.backing.free(slice);
            return HeapError.OutOfMemory;
        };
        header.* = ObjectHeader.init(kind, size);

        const addr = @intFromPtr(object_ptr);
        self.header_map.put(addr, header) catch {
            self.allocator.destroy(header);
            self.backing.free(slice);
            return HeapError.OutOfMemory;
        };

        self.current_size += size;
        if (self.current_size > self.peak_size) {
            self.peak_size = self.current_size;
        }

        self.stats.recordAlloc(size);

        self.recordBlock(addr, size, kind);

        return Allocation.init(@ptrCast(object_ptr), header);
    }

    fn recordBlock(self: *Heap, start: u64, size: u64, kind: ObjectKind) void {
        var i: usize = 0;
        while (i < self.blocks.items.len) : (i += 1) {
            const b = &self.blocks.items[i];
            if (b.free and b.start == start) {
                b.free = false;
                b.kind = kind;
                b.size = size;
                return;
            }
        }

        var block = HeapBlock.init(start, size);
        block.free = false;
        block.kind = kind;
        self.blocks.append(self.allocator, block) catch {};
    }

    pub fn deallocate(self: *Heap, ptr: *Object) HeapError!void {
        const addr = @intFromPtr(ptr);

        const header = self.header_map.get(addr) orelse {
            return HeapError.ObjectNotFound;
        };

        if (header.marked) {
            return HeapError.InvalidPointer;
        }

        const size = header.size;

        _ = self.header_map.remove(addr);
        self.allocator.destroy(header);

        self.current_size -|= size;
        self.stats.recordFree(size);

        var i: usize = 0;
        while (i < self.blocks.items.len) : (i += 1) {
            const b = &self.blocks.items[i];
            if (b.start == addr) {
                b.free = true;
                break;
            }
        }

        const slice: []u8 = @as([*]u8, @ptrFromInt(addr))[0..@intCast(size)];
        self.backing.free(slice);
    }

    pub fn forceDeallocate(self: *Heap, ptr: *Object) HeapError!void {
        const addr = @intFromPtr(ptr);

        const header = self.header_map.get(addr) orelse {
            return HeapError.ObjectNotFound;
        };

        const size = header.size;

        _ = self.header_map.remove(addr);
        self.allocator.destroy(header);

        self.current_size -|= size;
        self.stats.recordFree(size);

        var i: usize = 0;
        while (i < self.blocks.items.len) : (i += 1) {
            const b = &self.blocks.items[i];
            if (b.start == addr) {
                b.free = true;
                break;
            }
        }

        const slice: []u8 = @as([*]u8, @ptrFromInt(addr))[0..@intCast(size)];
        self.backing.free(slice);
    }


    pub fn findHeader(self: Heap, ptr: *Object) ?*ObjectHeader {
        const addr = @intFromPtr(ptr);
        return self.header_map.get(addr);
    }

    pub fn getObjectKind(self: Heap, ptr: *Object) ?ObjectKind {
        const h = self.findHeader(ptr) orelse return null;
        return h.kind;
    }

    pub fn markObject(self: Heap, ptr: *Object) bool {
        const h = self.findHeader(ptr) orelse return false;
        if (h.marked) return false;
        h.mark();
        return true;
    }

    pub fn unmarkObject(self: Heap, ptr: *Object) void {
        const h = self.findHeader(ptr) orelse return;
        h.unmark();
    }

    pub fn pinObject(self: Heap, ptr: *Object) bool {
        const h = self.findHeader(ptr) orelse return false;
        h.pin();
        return true;
    }

    pub fn isPinned(self: Heap, ptr: *Object) bool {
        const h = self.findHeader(ptr) orelse return false;
        return h.isPinned();
    }

    pub fn markAll(self: *Heap) void {
        var it = self.header_map.valueIterator();
        while (it.next()) |h| {
            h.*.mark();
        }
    }

    pub fn unmarkAll(self: *Heap) void {
        var it = self.header_map.valueIterator();
        while (it.next()) |h| {
            h.*.unmark();
        }
    }

    pub fn countMarked(self: Heap) usize {
        var count: usize = 0;
        var it = self.header_map.valueIterator();
        while (it.next()) |h| {
            if (h.*.isMarked()) count += 1;
        }
        return count;
    }

    pub fn countUnmarked(self: Heap) usize {
        var count: usize = 0;
        var it = self.header_map.valueIterator();
        while (it.next()) |h| {
            if (!h.*.isMarked() and !h.*.isPinned()) count += 1;
        }
        return count;
    }

    pub fn reset(self: *Heap) void {
        var it = self.header_map.iterator();
        while (it.next()) |entry| {
            const addr = entry.key_ptr.*;
            const h = entry.value_ptr.*;
            const size = h.size;

            const slice: []u8 = @as([*]u8, @ptrFromInt(addr))[0..@intCast(size)];
            self.backing.free(slice);

            self.allocator.destroy(h);
        }
        self.header_map.clearRetainingCapacity();
        self.blocks.clearRetainingCapacity();
        self.current_size = 0;
        self.young_size = 0;
        self.old_size = 0;
    }

    pub fn compact(self: *Heap) void {
        var i: usize = 0;
        while (i < self.blocks.items.len) {
            if (self.blocks.items[i].free) {
                _ = self.blocks.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn trackGeneration(self: *Heap, ptr: *Object, gen: Generation) void {
        const h = self.findHeader(ptr) orelse return;
        h.generation = @intFromEnum(gen);
    }

    pub fn generationOf(self: Heap, ptr: *Object) ?Generation {
        const h = self.findHeader(ptr) orelse return null;
        return @enumFromInt(h.generation);
    }
};

pub fn createHeap(allocator: std.mem.Allocator, stats: *Stats) !*Heap {
    const h = try allocator.create(Heap);
    h.* = Heap.init(allocator, stats);
    return h;
}

pub fn destroyHeap(h: *Heap) void {
    const allocator = h.allocator;
    h.deinit();
    allocator.destroy(h);
}

test "ObjectKind toString" {
    try std.testing.expectEqualStrings("plain_object", ObjectKind.plain_object.toString());
    try std.testing.expectEqualStrings("array", ObjectKind.array.toString());
}

test "ObjectKind isPrimitive" {
    try std.testing.expect(ObjectKind.string.isPrimitive());
    try std.testing.expect(!ObjectKind.plain_object.isPrimitive());
}

test "ObjectKind isCollection" {
    try std.testing.expect(ObjectKind.map.isCollection());
    try std.testing.expect(!ObjectKind.array.isCollection());
}

test "ObjectKind isBuffer" {
    try std.testing.expect(ObjectKind.arraybuffer.isBuffer());
    try std.testing.expect(!ObjectKind.array.isBuffer());
}

test "ObjectHeader init" {
    const h = ObjectHeader.init(.array, 100);
    try std.testing.expectEqual(ObjectKind.array, h.kind);
    try std.testing.expectEqual(@as(u64, 100), h.size);
    try std.testing.expect(!h.marked);
}

test "ObjectHeader mark" {
    var h = ObjectHeader.init(.array, 100);
    h.mark();
    try std.testing.expect(h.isMarked());
    h.unmark();
    try std.testing.expect(!h.isMarked());
}

test "ObjectHeader pin" {
    var h = ObjectHeader.init(.array, 100);
    h.pin();
    try std.testing.expect(h.isPinned());
}

test "ObjectHeader aged" {
    const h = ObjectHeader.init(.array, 100);
    const h2 = h.aged();
    try std.testing.expectEqual(@as(u8, 1), h2.age);
}

test "HeapBlock init" {
    const b = HeapBlock.init(0, 100);
    try std.testing.expect(b.free);
    try std.testing.expectEqual(@as(u64, 100), b.end());
}

test "HeapBlock contains" {
    const b = HeapBlock.init(100, 50);
    try std.testing.expect(b.contains(100));
    try std.testing.expect(b.contains(149));
    try std.testing.expect(!b.contains(150));
}

test "Generation toString" {
    try std.testing.expectEqualStrings("young", Generation.young.toString());
    try std.testing.expectEqualStrings("old", Generation.old.toString());
}

test "Generation isYoung isOld" {
    try std.testing.expect(Generation.young.isYoung());
    try std.testing.expect(Generation.old.isOld());
}

test "Heap init" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    try std.testing.expectEqual(@as(u64, 0), h.currentSize());
    try std.testing.expectEqual(@as(usize, 0), h.objectCount());
}

test "Heap initWithSize" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.initWithSize(std.testing.allocator, &stats, 16 * 1024 * 1024);
    defer h.deinit();

    try std.testing.expectEqual(@as(u64, 16 * 1024 * 1024), h.maxSize());
}

test "Heap allocate" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 64);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    try std.testing.expectEqual(@as(u64, 64), h.currentSize());
    try std.testing.expectEqual(@as(usize, 1), h.objectCount());
}

test "Heap allocate invalid size" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    try std.testing.expectError(HeapError.InvalidSize, h.allocate(.plain_object, 0));
}

test "Heap allocate exceeds max" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.initWithSize(std.testing.allocator, &stats, MIN_HEAP_SIZE);
    defer h.deinit();

    try std.testing.expectError(HeapError.HeapFull, h.allocate(.plain_object, MIN_HEAP_SIZE + 1));
}

test "Heap deallocate" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 64);
    try h.deallocate(alloc.toObject());

    try std.testing.expectEqual(@as(u64, 0), h.currentSize());
    try std.testing.expectEqual(@as(usize, 0), h.objectCount());
}

test "Heap findHeader" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.array, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    const header = h.findHeader(alloc.toObject());
    try std.testing.expect(header != null);
    try std.testing.expectEqual(ObjectKind.array, header.?.kind);
}

test "Heap markObject" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    const first = h.markObject(alloc.toObject());
    const second = h.markObject(alloc.toObject());
    try std.testing.expect(first);
    try std.testing.expect(!second);
}

test "Heap unmarkObject" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    _ = h.markObject(alloc.toObject());
    h.unmarkObject(alloc.toObject());

    try std.testing.expect(!h.findHeader(alloc.toObject()).?.isMarked());
}

test "Heap pinObject" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    _ = h.pinObject(alloc.toObject());
    try std.testing.expect(h.isPinned(alloc.toObject()));
}

test "Heap countMarked countUnmarked" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    const a2 = try h.allocate(.array, 32);
    const a3 = try h.allocate(.string, 32);
    defer {
        h.forceDeallocate(a1.toObject()) catch {};
        h.forceDeallocate(a2.toObject()) catch {};
        h.forceDeallocate(a3.toObject()) catch {};
    }

    _ = h.markObject(a1.toObject());
    _ = h.markObject(a2.toObject());

    try std.testing.expectEqual(@as(usize, 2), h.countMarked());
    try std.testing.expectEqual(@as(usize, 1), h.countUnmarked());
}

test "Heap markAll unmarkAll" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const a1 = try h.allocate(.plain_object, 32);
    const a2 = try h.allocate(.array, 32);
    defer {
        h.forceDeallocate(a1.toObject()) catch {};
        h.forceDeallocate(a2.toObject()) catch {};
    }

    h.markAll();
    try std.testing.expectEqual(@as(usize, 2), h.countMarked());

    h.unmarkAll();
    try std.testing.expectEqual(@as(usize, 0), h.countMarked());
}

test "Heap usagePercent" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.initWithSize(std.testing.allocator, &stats, MIN_HEAP_SIZE);
    defer h.deinit();

    try std.testing.expectEqual(@as(f64, 0.0), h.usagePercent());
}

test "Heap wouldExceedLimit" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.initWithSize(std.testing.allocator, &stats, MIN_HEAP_SIZE);
    defer h.deinit();

    try std.testing.expect(!h.wouldExceedLimit(1024));
    try std.testing.expect(h.wouldExceedLimit(MIN_HEAP_SIZE + 1));
}

test "Heap canAllocate" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.initWithSize(std.testing.allocator, &stats, MIN_HEAP_SIZE);
    defer h.deinit();

    try std.testing.expect(h.canAllocate(1024));
    try std.testing.expect(!h.canAllocate(MIN_HEAP_SIZE + 1));
}

test "Heap setMaxSize" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    h.setMaxSize(16 * 1024 * 1024);
    try std.testing.expectEqual(@as(u64, 16 * 1024 * 1024), h.maxSize());
}

test "Heap reset" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    _ = try h.allocate(.plain_object, 64);
    _ = try h.allocate(.array, 32);

    h.reset();
    try std.testing.expectEqual(@as(u64, 0), h.currentSize());
    try std.testing.expectEqual(@as(usize, 0), h.objectCount());
}

test "Heap trackGeneration" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    var h = Heap.init(std.testing.allocator, &stats);
    defer h.deinit();

    const alloc = try h.allocate(.plain_object, 32);
    defer h.forceDeallocate(alloc.toObject()) catch {};

    h.trackGeneration(alloc.toObject(), .old);
    const g = h.generationOf(alloc.toObject());
    try std.testing.expectEqual(Generation.old, g.?);
}

test "createHeap and destroyHeap" {
    var stats = Stats.init(std.testing.allocator);
    defer stats.deinit();

    const h = try createHeap(std.testing.allocator, &stats);
    destroyHeap(h);
}

test "DEFAULT_HEAP_SIZE" {
    try std.testing.expectEqual(@as(u64, 64 * 1024 * 1024), DEFAULT_HEAP_SIZE);
}

test "MIN_HEAP_SIZE" {
    try std.testing.expectEqual(@as(u64, 1024 * 1024), MIN_HEAP_SIZE);
}

test "MAX_HEAP_SIZE" {
    try std.testing.expectEqual(@as(u64, 4 * 1024 * 1024 * 1024), MAX_HEAP_SIZE);
}
