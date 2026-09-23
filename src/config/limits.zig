const std = @import("std");

pub const min_stack_size: usize = 64 * 1024;
pub const default_stack_size: usize = 1024 * 1024;
pub const max_stack_size: usize = 256 * 1024 * 1024;

pub const min_heap_size: usize = 1024 * 1024;
pub const default_heap_size: usize = 256 * 1024 * 1024;
pub const max_heap_size: usize = 16 * 1024 * 1024 * 1024;

pub const min_gc_threshold: usize = 256 * 1024;
pub const default_gc_threshold: usize = 16 * 1024 * 1024;
pub const default_gc_interval_ms: u64 = 1000;

pub const default_max_call_depth: usize = 10_000;
pub const hard_max_call_depth: usize = 100_000;

pub const default_max_parse_depth: usize = 1_000;
pub const hard_max_parse_depth: usize = 10_000;

pub const default_max_eval_depth: usize = 256;
pub const hard_max_eval_depth: usize = 1_024;

pub const default_max_string_length: usize = 512 * 1024 * 1024;
pub const max_string_length: usize = 512 * 1024 * 1024;

pub const default_max_array_length: usize = 4_294_967_295;
pub const max_array_length: u32 = 4_294_967_295;

pub const default_max_object_properties: usize = 1_000_000;
pub const max_object_properties: usize = 16_777_216;

pub const default_max_regex_backtrack: usize = 1_000_000;
pub const hard_max_regex_backtrack: usize = 100_000_000;

pub const max_regex_pattern_length: usize = 1024 * 1024;
pub const max_regex_groups: usize = 10_000;

pub const max_arguments_count: usize = 65_535;
pub const max_parameters_count: usize = 65_535;
pub const max_locals_per_function: usize = 65_535;
pub const max_constants_per_function: usize = 65_535;
pub const max_bytecode_size: usize = 16 * 1024 * 1024;

pub const max_closure_captures: usize = 1_024;
pub const max_scope_chain: usize = 1_024;

pub const max_prototype_chain: usize = 1_024;
pub const max_symbol_registry: usize = 1_000_000;
pub const max_weakrefs: usize = 1_000_000;
pub const max_finalization_callbacks: usize = 100_000;

pub const max_promise_chain: usize = 100_000;
pub const max_microtask_queue: usize = 1_000_000;
pub const max_macrotask_queue: usize = 10_000;
pub const max_timers: usize = 100_000;
pub const min_timer_delay_ms: u32 = 0;
pub const max_timer_delay_ms: u32 = 2_147_483_647;

pub const max_event_listeners_per_type: usize = 10_000;
pub const max_event_types_per_target: usize = 10_000;
pub const max_event_targets: usize = 1_000_000;

pub const max_modules: usize = 100_000;
pub const max_module_depth: usize = 256;
pub const max_module_size: usize = 64 * 1024 * 1024;
pub const max_module_specifier_length: usize = 4_096;

pub const max_worker_threads: usize = 64;
pub const max_shared_array_buffer_size: usize = 2 * 1024 * 1024 * 1024;

pub const max_typed_array_size: usize = 2 * 1024 * 1024 * 1024;
pub const max_array_buffer_size: usize = 2 * 1024 * 1024 * 1024;

pub const max_iterator_steps: usize = 1_000_000_000;
pub const max_generator_yields: usize = 1_000_000_000;

pub const max_json_depth: usize = 1_000;
pub const max_json_size: usize = 512 * 1024 * 1024;

pub const max_source_length: usize = 512 * 1024 * 1024;
pub const max_line_length: usize = 1024 * 1024;
pub const max_lines: usize = 16_777_216;
pub const max_identifiers: usize = 100_000_000;
pub const max_identifier_length: usize = 16_384;

pub const max_number_precision: usize = 100_000;
pub const max_number_to_string_digits: usize = 100_000;
pub const max_bigint_bits: usize = 1_048_576;

pub const max_intl_locales: usize = 1_024;
pub const max_intl_options: usize = 256;
pub const max_date_range_years: i32 = 8_640_000_000_000_000;

pub const max_debug_breakpoints: usize = 1_000;
pub const max_debug_watch_expressions: usize = 1_000;
pub const max_trace_depth: usize = 1_024;
pub const max_profile_samples: usize = 1_000_000;

pub const default_http_max_body: usize = 256 * 1024 * 1024;
pub const default_http_timeout_ms: u64 = 30_000;
pub const default_dns_timeout_ms: u64 = 5_000;
pub const default_fetch_redirects: u8 = 20;
pub const max_fetch_redirects: u8 = 50;
pub const max_fetch_headers: usize = 512;
pub const max_header_length: usize = 65_536;
pub const max_url_length: usize = 65_536;

pub const default_storage_quota: usize = 256 * 1024 * 1024;
pub const max_cookie_count: usize = 180;
pub const max_cookie_size: usize = 4_096;
pub const max_local_storage_keys: usize = 1_000_000;
pub const max_local_storage_key_length: usize = 1_024;
pub const max_local_storage_value_length: usize = 10 * 1024 * 1024;

pub const max_console_message_length: usize = 1024 * 1024;
pub const max_console_history: usize = 10_000;

pub const Limits = struct {
    stack_size: usize = default_stack_size,
    heap_size: usize = default_heap_size,
    gc_threshold: usize = default_gc_threshold,
    gc_interval_ms: u64 = default_gc_interval_ms,

    max_call_depth: usize = default_max_call_depth,
    max_parse_depth: usize = default_max_parse_depth,
    max_eval_depth: usize = default_max_eval_depth,

    max_string_length: usize = default_max_string_length,
    max_array_length: usize = default_max_array_length,
    max_object_properties: usize = default_max_object_properties,

    max_regex_backtrack: usize = default_max_regex_backtrack,
    max_regex_pattern_length: usize = max_regex_pattern_length,
    max_regex_groups: usize = max_regex_groups,

    max_arguments_count: usize = max_arguments_count,
    max_parameters_count: usize = max_parameters_count,
    max_locals_per_function: usize = max_locals_per_function,
    max_constants_per_function: usize = max_constants_per_function,
    max_bytecode_size: usize = max_bytecode_size,

    max_closure_captures: usize = max_closure_captures,
    max_scope_chain: usize = max_scope_chain,
    max_prototype_chain: usize = max_prototype_chain,

    max_promise_chain: usize = max_promise_chain,
    max_microtask_queue: usize = max_microtask_queue,
    max_macrotask_queue: usize = max_macrotask_queue,
    max_timers: usize = max_timers,

    max_modules: usize = max_modules,
    max_module_depth: usize = max_module_depth,
    max_module_size: usize = max_module_size,

    max_worker_threads: usize = max_worker_threads,
    max_typed_array_size: usize = max_typed_array_size,
    max_array_buffer_size: usize = max_array_buffer_size,

    max_json_depth: usize = max_json_depth,
    max_json_size: usize = max_json_size,

    max_source_length: usize = max_source_length,
    max_identifier_length: usize = max_identifier_length,

    default_http_max_body: usize = default_http_max_body,
    default_http_timeout_ms: u64 = default_http_timeout_ms,

    default_storage_quota: usize = default_storage_quota,

    pub fn relaxed() Limits {
        return .{
            .stack_size = max_stack_size,
            .heap_size = max_heap_size,
            .max_call_depth = hard_max_call_depth,
            .max_parse_depth = hard_max_parse_depth,
            .max_eval_depth = hard_max_eval_depth,
            .max_regex_backtrack = hard_max_regex_backtrack,
        };
    }

    pub fn strict() Limits {
        return .{
            .stack_size = 256 * 1024,
            .heap_size = 32 * 1024 * 1024,
            .gc_threshold = 4 * 1024 * 1024,
            .max_call_depth = 1_000,
            .max_parse_depth = 200,
            .max_eval_depth = 64,
            .max_string_length = 16 * 1024 * 1024,
            .max_array_length = 1_000_000,
            .max_object_properties = 10_000,
            .max_regex_backtrack = 100_000,
            .max_microtask_queue = 10_000,
            .max_macrotask_queue = 1_000,
        };
    }

    pub fn embedded() Limits {
        return .{
            .stack_size = 256 * 1024,
            .heap_size = 16 * 1024 * 1024,
            .gc_threshold = 2 * 1024 * 1024,
            .max_call_depth = 500,
            .max_parse_depth = 100,
            .max_eval_depth = 32,
            .max_string_length = 4 * 1024 * 1024,
            .max_array_length = 100_000,
            .max_object_properties = 1_000,
            .max_regex_backtrack = 10_000,
            .max_worker_threads = 4,
            .max_microtask_queue = 1_000,
            .max_macrotask_queue = 100,
        };
    }

    pub fn validate(self: Limits) !void {
        if (self.stack_size < min_stack_size) return error.StackTooSmall;
        if (self.stack_size > max_stack_size) return error.StackTooLarge;
        if (self.heap_size < min_heap_size) return error.HeapTooSmall;
        if (self.heap_size > max_heap_size) return error.HeapTooLarge;
        if (self.gc_threshold < min_gc_threshold) return error.GcThresholdTooSmall;
        if (self.gc_threshold > self.heap_size) return error.GcThresholdExceedsHeap;
        if (self.gc_interval_ms == 0) return error.InvalidGcInterval;
        if (self.max_call_depth == 0) return error.InvalidCallDepth;
        if (self.max_call_depth > hard_max_call_depth) return error.CallDepthTooLarge;
        if (self.max_parse_depth == 0) return error.InvalidParseDepth;
        if (self.max_parse_depth > hard_max_parse_depth) return error.ParseDepthTooLarge;
        if (self.max_eval_depth == 0) return error.InvalidEvalDepth;
        if (self.max_eval_depth > hard_max_eval_depth) return error.EvalDepthTooLarge;
        if (self.max_string_length == 0) return error.InvalidStringLimit;
        if (self.max_string_length > max_string_length) return error.StringLimitTooLarge;
        if (self.max_array_length == 0) return error.InvalidArrayLimit;
        if (self.max_object_properties == 0) return error.InvalidObjectLimit;
        if (self.max_regex_backtrack == 0) return error.InvalidRegexBacktrack;
        if (self.max_regex_backtrack > hard_max_regex_backtrack) return error.RegexBacktrackTooLarge;
        if (self.max_regex_pattern_length == 0) return error.InvalidRegexPatternLength;
        if (self.max_regex_groups == 0) return error.InvalidRegexGroups;
        if (self.max_arguments_count == 0) return error.InvalidArgumentsCount;
        if (self.max_parameters_count == 0) return error.InvalidParametersCount;
        if (self.max_locals_per_function == 0) return error.InvalidLocalsCount;
        if (self.max_constants_per_function == 0) return error.InvalidConstantsCount;
        if (self.max_bytecode_size == 0) return error.InvalidBytecodeSize;
        if (self.max_closure_captures == 0) return error.InvalidClosureCaptures;
        if (self.max_scope_chain == 0) return error.InvalidScopeChain;
        if (self.max_prototype_chain == 0) return error.InvalidPrototypeChain;
        if (self.max_promise_chain == 0) return error.InvalidPromiseChain;
        if (self.max_microtask_queue == 0) return error.InvalidMicrotaskQueue;
        if (self.max_macrotask_queue == 0) return error.InvalidMacrotaskQueue;
        if (self.max_timers == 0) return error.InvalidTimers;
        if (self.max_modules == 0) return error.InvalidModules;
        if (self.max_module_depth == 0) return error.InvalidModuleDepth;
        if (self.max_module_size == 0) return error.InvalidModuleSize;
        if (self.max_worker_threads == 0) return error.InvalidWorkerThreads;
        if (self.max_typed_array_size == 0) return error.InvalidTypedArraySize;
        if (self.max_array_buffer_size == 0) return error.InvalidArrayBufferSize;
        if (self.max_json_depth == 0) return error.InvalidJsonDepth;
        if (self.max_json_size == 0) return error.InvalidJsonSize;
        if (self.max_source_length == 0) return error.InvalidSourceLength;
        if (self.max_identifier_length == 0) return error.InvalidIdentifierLength;
        if (self.default_http_max_body == 0) return error.InvalidHttpBodyLimit;
        if (self.default_http_timeout_ms == 0) return error.InvalidHttpTimeout;
        if (self.default_storage_quota == 0) return error.InvalidStorageQuota;
    }

    pub fn isWithinCallDepth(self: Limits, depth: usize) bool {
        return depth <= self.max_call_depth;
    }

    pub fn isWithinParseDepth(self: Limits, depth: usize) bool {
        return depth <= self.max_parse_depth;
    }

    pub fn isWithinPrototypeChain(self: Limits, depth: usize) bool {
        return depth <= self.max_prototype_chain;
    }

    pub fn isWithinModuleDepth(self: Limits, depth: usize) bool {
        return depth <= self.max_module_depth;
    }

    pub fn isWithinJsonDepth(self: Limits, depth: usize) bool {
        return depth <= self.max_json_depth;
    }

    pub fn canAllocateString(self: Limits, size: usize) bool {
        return size <= self.max_string_length;
    }

    pub fn canAllocateArrayBuffer(self: Limits, size: usize) bool {
        return size <= self.max_array_buffer_size;
    }

    pub fn canAllocateTypedArray(self: Limits, size: usize) bool {
        return size <= self.max_typed_array_size;
    }
};

pub const default = Limits{};

pub fn defaults() Limits {
    return default;
}

test "default limits validate" {
    try default.validate();
}

test "relaxed limits validate" {
    try Limits.relaxed().validate();
}

test "strict limits validate" {
    try Limits.strict().validate();
}

test "embedded limits validate" {
    try Limits.embedded().validate();
}

test "stack size below min rejected" {
    var l = default;
    l.stack_size = 1024;
    try std.testing.expectError(error.StackTooSmall, l.validate());
}

test "stack size above max rejected" {
    var l = default;
    l.stack_size = max_stack_size + 1;
    try std.testing.expectError(error.StackTooLarge, l.validate());
}

test "heap size below min rejected" {
    var l = default;
    l.heap_size = 512 * 1024;
    try std.testing.expectError(error.HeapTooSmall, l.validate());
}

test "gc threshold above heap rejected" {
    var l = default;
    l.heap_size = 1024 * 1024;
    l.gc_threshold = 2 * 1024 * 1024;
    try std.testing.expectError(error.GcThresholdExceedsHeap, l.validate());
}

test "gc interval zero rejected" {
    var l = default;
    l.gc_interval_ms = 0;
    try std.testing.expectError(error.InvalidGcInterval, l.validate());
}

test "call depth above hard max rejected" {
    var l = default;
    l.max_call_depth = hard_max_call_depth + 1;
    try std.testing.expectError(error.CallDepthTooLarge, l.validate());
}

test "parse depth above hard max rejected" {
    var l = default;
    l.max_parse_depth = hard_max_parse_depth + 1;
    try std.testing.expectError(error.ParseDepthTooLarge, l.validate());
}

test "string length above max rejected" {
    var l = default;
    l.max_string_length = max_string_length + 1;
    try std.testing.expectError(error.StringLimitTooLarge, l.validate());
}

test "regex backtrack above hard max rejected" {
    var l = default;
    l.max_regex_backtrack = hard_max_regex_backtrack + 1;
    try std.testing.expectError(error.RegexBacktrackTooLarge, l.validate());
}

test "call depth check" {
    const l = default;
    try std.testing.expect(l.isWithinCallDepth(100));
    try std.testing.expect(l.isWithinCallDepth(l.max_call_depth));
    try std.testing.expect(!l.isWithinCallDepth(l.max_call_depth + 1));
}

test "parse depth check" {
    const l = default;
    try std.testing.expect(l.isWithinParseDepth(100));
    try std.testing.expect(!l.isWithinParseDepth(l.max_parse_depth + 1));
}

test "prototype chain check" {
    const l = default;
    try std.testing.expect(l.isWithinPrototypeChain(10));
    try std.testing.expect(!l.isWithinPrototypeChain(l.max_prototype_chain + 1));
}

test "module depth check" {
    const l = default;
    try std.testing.expect(l.isWithinModuleDepth(10));
    try std.testing.expect(!l.isWithinModuleDepth(l.max_module_depth + 1));
}

test "json depth check" {
    const l = default;
    try std.testing.expect(l.isWithinJsonDepth(100));
    try std.testing.expect(!l.isWithinJsonDepth(l.max_json_depth + 1));
}

test "can allocate string boundary" {
    const l = default;
    try std.testing.expect(l.canAllocateString(1024));
    try std.testing.expect(l.canAllocateString(l.max_string_length));
    try std.testing.expect(!l.canAllocateString(l.max_string_length + 1));
}

test "can allocate array buffer boundary" {
    const l = default;
    try std.testing.expect(l.canAllocateArrayBuffer(1024));
    try std.testing.expect(!l.canAllocateArrayBuffer(l.max_array_buffer_size + 1));
}

test "can allocate typed array boundary" {
    const l = default;
    try std.testing.expect(l.canAllocateTypedArray(1024));
    try std.testing.expect(!l.canAllocateTypedArray(l.max_typed_array_size + 1));
}

test "strict preset disables large limits" {
    const s = Limits.strict();
    try std.testing.expect(s.max_call_depth < default_max_call_depth);
    try std.testing.expect(s.max_parse_depth < default_max_parse_depth);
    try std.testing.expect(s.max_object_properties < default_max_object_properties);
}

test "embedded preset disables worker threads high" {
    const e = Limits.embedded();
    try std.testing.expect(e.max_worker_threads < max_worker_threads);
}
