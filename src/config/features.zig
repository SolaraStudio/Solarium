const std = @import("std");
const version = @import("version.zig");

pub const Feature = enum {
    ecmascript_2015,
    ecmascript_2016,
    ecmascript_2017,
    ecmascript_2018,
    ecmascript_2019,
    ecmascript_2020,
    ecmascript_2021,
    ecmascript_2022,
    ecmascript_2023,
    ecmascript_2024,

    intl,
    regexp,
    regexp_unicode,
    regexp_named_groups,
    regexp_lookbehind,

    bigint,
    symbol,
    weakref,
    finalization_registry,
    proxy,
    reflect,

    async_iterators,
    async_generators,
    generators,
    promises,
    top_level_await,
    atomics,
    shared_array_buffer,

    modules,
    dynamic_import,
    import_meta,
    import_attributes,
    json_modules,

    typed_arrays,
    array_buffer,
    data_view,
    structured_clone,
    transferable_objects,

    error_cause,
    aggregate_error,

    optional_chaining,
    nullish_coalescing,
    logical_assignment,

    class_fields,
    private_methods,
    static_blocks,
    class_static_init,
    decorators,

    array_find_last,
    array_at,
    string_at,
    object_has_own,
    hashbang,
    ergonomic_brand_checks,
    change_array_by_copy,

    iterator_helpers,
    set_methods,
    promise_with_resolvers,
    array_grouping,

    temporal,
    decorator_metadata,

    jit,
    gc_generational,
    gc_incremental,
    gc_concurrent,
    jit_baseline,
    jit_optimizing,

    debugger,
    profiler,
    tracing,
    disassembler,
    repl,

    dom,
    event_loop,
    fetch,
    timers,
    console,
    storage,

    worker_threads,
    simd,
    wasm,
};

pub const FeatureSet = struct {
    enabled: std.EnumSet(Feature),
    disabled: std.EnumSet(Feature),

    pub fn init() FeatureSet {
        return .{
            .enabled = std.EnumSet(Feature).initEmpty(),
            .disabled = std.EnumSet(Feature).initEmpty(),
        };
    }

    pub fn all() FeatureSet {
        var fs = FeatureSet.init();
        inline for (@typeInfo(Feature).@"enum".fields) |field| {
            fs.enabled.insert(@enumFromInt(field.value));
        }
        return fs;
    }

    pub fn none() FeatureSet {
        return FeatureSet.init();
    }

    pub fn default() FeatureSet {
        var fs = FeatureSet.init();
        fs.enable(.ecmascript_2015);
        fs.enable(.ecmascript_2016);
        fs.enable(.ecmascript_2017);
        fs.enable(.ecmascript_2018);
        fs.enable(.ecmascript_2019);
        fs.enable(.ecmascript_2020);
        fs.enable(.ecmascript_2021);
        fs.enable(.ecmascript_2022);
        fs.enable(.ecmascript_2023);
        fs.enable(.ecmascript_2024);
        fs.enable(.promises);
        fs.enable(.generators);
        fs.enable(.async_generators);
        fs.enable(.async_iterators);
        fs.enable(.symbol);
        fs.enable(.bigint);
        fs.enable(.weakref);
        fs.enable(.proxy);
        fs.enable(.reflect);
        fs.enable(.regexp);
        fs.enable(.regexp_unicode);
        fs.enable(.regexp_named_groups);
        fs.enable(.regexp_lookbehind);
        fs.enable(.typed_arrays);
        fs.enable(.array_buffer);
        fs.enable(.data_view);
        fs.enable(.error_cause);
        fs.enable(.aggregate_error);
        fs.enable(.optional_chaining);
        fs.enable(.nullish_coalescing);
        fs.enable(.logical_assignment);
        fs.enable(.class_fields);
        fs.enable(.private_methods);
        fs.enable(.static_blocks);
        fs.enable(.array_find_last);
        fs.enable(.array_at);
        fs.enable(.string_at);
        fs.enable(.object_has_own);
        fs.enable(.hashbang);
        fs.enable(.ergonomic_brand_checks);
        fs.enable(.change_array_by_copy);
        fs.enable(.iterator_helpers);
        fs.enable(.set_methods);
        fs.enable(.promise_with_resolvers);
        fs.enable(.array_grouping);
        fs.enable(.modules);
        fs.enable(.dynamic_import);
        fs.enable(.import_meta);
        fs.enable(.import_attributes);
        fs.enable(.json_modules);
        fs.enable(.gc_incremental);
        fs.enable(.gc_generational);
        fs.enable(.dom);
        fs.enable(.event_loop);
        fs.enable(.timers);
        fs.enable(.console);
        fs.enable(.storage);
        fs.enable(.worker_threads);
        return fs;
    }

    pub fn minimal() FeatureSet {
        var fs = FeatureSet.init();
        fs.enable(.ecmascript_2015);
        fs.enable(.ecmascript_2016);
        fs.enable(.ecmascript_2017);
        fs.enable(.ecmascript_2018);
        fs.enable(.ecmascript_2019);
        fs.enable(.ecmascript_2020);
        fs.enable(.promises);
        fs.enable(.generators);
        fs.enable(.symbol);
        fs.enable(.regexp);
        fs.enable(.typed_arrays);
        fs.enable(.error_cause);
        fs.enable(.optional_chaining);
        fs.enable(.nullish_coalescing);
        fs.enable(.logical_assignment);
        fs.enable(.gc_incremental);
        fs.enable(.dom);
        fs.enable(.event_loop);
        fs.enable(.console);
        return fs;
    }

    pub fn embedded() FeatureSet {
        var fs = FeatureSet.init();
        fs.enable(.ecmascript_2015);
        fs.enable(.ecmascript_2016);
        fs.enable(.ecmascript_2017);
        fs.enable(.ecmascript_2018);
        fs.enable(.ecmascript_2019);
        fs.enable(.ecmascript_2020);
        fs.enable(.ecmascript_2021);
        fs.enable(.promises);
        fs.enable(.symbol);
        fs.enable(.regexp);
        fs.enable(.typed_arrays);
        fs.enable(.gc_incremental);
        fs.enable(.dom);
        fs.enable(.event_loop);
        return fs;
    }

    pub fn enable(self: *FeatureSet, feature: Feature) void {
        self.enabled.insert(feature);
        self.disabled.remove(feature);
    }

    pub fn disable(self: *FeatureSet, feature: Feature) void {
        self.disabled.insert(feature);
        self.enabled.remove(feature);
    }

    pub fn isEnabled(self: FeatureSet, feature: Feature) bool {
        if (self.disabled.contains(feature)) return false;
        return self.enabled.contains(feature);
    }

    pub fn isDisabled(self: FeatureSet, feature: Feature) bool {
        return !self.isEnabled(feature);
    }

    pub fn require(self: FeatureSet, feature: Feature) !void {
        if (!self.isEnabled(feature)) return error.FeatureDisabled;
    }

    pub fn count(self: FeatureSet) usize {
        return self.enabled.count();
    }

    pub fn listAlloc(self: FeatureSet, allocator: std.mem.Allocator) ![]Feature {
        var list = try allocator.alloc(Feature, self.count());
        var i: usize = 0;
        var it = self.enabled.iterator();
        while (it.next()) |f| {
            list[i] = f;
            i += 1;
        }
        return list;
    }
};

pub const default = FeatureSet.default();

pub fn all() FeatureSet {
    return FeatureSet.all();
}

pub fn none() FeatureSet {
    return FeatureSet.none();
}

pub fn parseFeature(s: []const u8) ?Feature {
    inline for (@typeInfo(Feature).@"enum".fields) |field| {
        if (std.mem.eql(u8, s, field.name)) {
            return @enumFromInt(field.value);
        }
    }
    return null;
}

pub fn featureName(feature: Feature) []const u8 {
    return @tagName(feature);
}

test "default feature set enables ES2015 through ES2024" {
    const fs = FeatureSet.default();
    try std.testing.expect(fs.isEnabled(.ecmascript_2015));
    try std.testing.expect(fs.isEnabled(.ecmascript_2024));
}

test "default feature set enables promises" {
    try std.testing.expect(default.isEnabled(.promises));
}

test "default feature set disables JIT" {
    try std.testing.expect(default.isDisabled(.jit));
}

test "default feature set enables gc_incremental" {
    try std.testing.expect(default.isEnabled(.gc_incremental));
}

test "all feature set enables everything" {
    const fs = FeatureSet.all();
    try std.testing.expect(fs.isEnabled(.jit));
    try std.testing.expect(fs.isEnabled(.wasm));
    try std.testing.expect(fs.isEnabled(.simd));
}

test "none feature set enables nothing" {
    const fs = FeatureSet.none();
    try std.testing.expect(fs.isDisabled(.promises));
    try std.testing.expect(fs.isDisabled(.ecmascript_2015));
}

test "minimal feature set omits bigint" {
    const fs = FeatureSet.minimal();
    try std.testing.expect(fs.isDisabled(.bigint));
    try std.testing.expect(fs.isEnabled(.promises));
}

test "embedded feature set omits bigint and modules" {
    const fs = FeatureSet.embedded();
    try std.testing.expect(fs.isDisabled(.bigint));
    try std.testing.expect(fs.isDisabled(.modules));
    try std.testing.expect(fs.isEnabled(.dom));
}

test "enable then disable feature" {
    var fs = FeatureSet.init();
    fs.enable(.promises);
    try std.testing.expect(fs.isEnabled(.promises));
    fs.disable(.promises);
    try std.testing.expect(fs.isDisabled(.promises));
}

test "require succeeds for enabled" {
    const fs = FeatureSet.default();
    try fs.require(.promises);
}

test "require fails for disabled" {
    const fs = FeatureSet.none();
    try std.testing.expectError(error.FeatureDisabled, fs.require(.promises));
}

test "count matches enabled" {
    var fs = FeatureSet.init();
    fs.enable(.promises);
    fs.enable(.symbol);
    fs.enable(.regexp);
    try std.testing.expectEqual(@as(usize, 3), fs.count());
}

test "listAlloc returns all enabled" {
    var fs = FeatureSet.init();
    fs.enable(.promises);
    fs.enable(.symbol);
    const list = try fs.listAlloc(std.testing.allocator);
    defer std.testing.allocator.free(list);
    try std.testing.expectEqual(@as(usize, 2), list.len);
}

test "parseFeature round trip" {
    try std.testing.expectEqual(Feature.promises, parseFeature("promises").?);
    try std.testing.expectEqual(Feature.bigint, parseFeature("bigint").?);
    try std.testing.expect(parseFeature("nonsense") == null);
}

test "featureName matches tag" {
    try std.testing.expectEqualStrings("promises", featureName(.promises));
    try std.testing.expectEqualStrings("bigint", featureName(.bigint));
}
