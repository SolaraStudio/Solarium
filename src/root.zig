const std = @import("std");

pub const version = @import("config/version.zig");
pub const features = @import("config/features.zig");
pub const limits = @import("config/limits.zig");

pub const Runtime = @import("runtime/runtime.zig").Runtime;
pub const Context = @import("runtime/context.zig").Context;
pub const Realm = @import("runtime/realm.zig").Realm;
pub const Agent = @import("runtime/agent.zig").Agent;

pub const Value = @import("values/value.zig").Value;
pub const Primitive = @import("values/primitive.zig").Primitive;
pub const Coercion = @import("values/coercion.zig");

pub const Object = @import("objects/object.zig").Object;
pub const Property = @import("objects/property.zig").Property;
pub const Descriptor = @import("objects/descriptor.zig").Descriptor;
pub const Prototype = @import("objects/prototype.zig").Prototype;

pub const Function = @import("functions/function.zig").Function;
pub const Closure = @import("functions/closure.zig").Closure;
pub const NativeFn = @import("functions/native.zig").NativeFn;

pub const Bytecode = @import("compiler/bytecode.zig").Bytecode;
pub const Opcode = @import("compiler/opcode.zig").Opcode;
pub const ConstantPool = @import("compiler/constant_pool.zig").ConstantPool;
pub const Compiler = @import("compiler/compiler.zig").Compiler;

pub const Lexer = @import("lexer/lexer.zig").Lexer;
pub const Token = @import("lexer/token.zig").Token;
pub const TokenKind = @import("lexer/token.zig").TokenKind;

pub const Parser = @import("parser/parser.zig").Parser;
pub const Ast = @import("parser/ast.zig");

pub const Vm = @import("vm/vm.zig").Vm;
pub const Frame = @import("vm/frame.zig").Frame;
pub const Stack = @import("vm/stack.zig").Stack;

pub const Gc = @import("gc/gc.zig").Gc;
pub const Heap = @import("gc/heap.zig").Heap;

pub const Scope = @import("scope/scope.zig").Scope;
pub const Environment = @import("scope/environment.zig").Environment;

pub const EventLoop = @import("eventloop/loop.zig").EventLoop;
pub const Job = @import("eventloop/job.zig").Job;

pub const Module = @import("modules/module.zig").Module;
pub const ModuleLoader = @import("modules/loader.zig").ModuleLoader;

pub const Dom = @import("dom/bridge.zig").Dom;

pub const Errors = @import("errors/error.zig");
pub const Error = @import("errors/error.zig").Error;
pub const TypeError = @import("errors/type_error.zig").TypeError;
pub const SyntaxError = @import("errors/syntax_error.zig").SyntaxError;
pub const ReferenceError = @import("errors/reference_error.zig").ReferenceError;
pub const RangeError = @import("errors/range_error.zig").RangeError;

pub const Json = @import("json/parse.zig");
pub const Regex = @import("regex/regex.zig").Regex;

pub const Api = @import("api/api.zig");
pub const EvalOptions = @import("api/eval.zig").EvalOptions;
pub const CompileOptions = @import("api/compile.zig").CompileOptions;

pub const CAbi = @import("interop/c_abi.zig");
pub const Jni = @import("interop/jni.zig");
pub const OptimaBridge = @import("interop/optima.zig");

pub const builtins = struct {
    pub const global = @import("builtins/global.zig");
    pub const object = @import("builtins/object/object.zig");
    pub const array = @import("builtins/array/array.zig");
    pub const function = @import("builtins/function/function.zig");
    pub const string = @import("builtins/string/string.zig");
    pub const number = @import("builtins/number/number.zig");
    pub const boolean = @import("builtins/boolean/boolean.zig");
    pub const symbol = @import("builtins/symbol/symbol.zig");
    pub const bigint = @import("builtins/bigint/bigint.zig");
    pub const math = @import("builtins/math/math.zig");
    pub const json = @import("builtins/json/json.zig");
    pub const date = @import("builtins/date/date.zig");
    pub const regexp = @import("builtins/regexp/regexp.zig");
    pub const error = @import("builtins/error/error.zig");
    pub const promise = @import("builtins/promise/promise.zig");
    pub const map = @import("builtins/map/map.zig");
    pub const set = @import("builtins/set/set.zig");
    pub const weakmap = @import("builtins/weakmap/weakmap.zig");
    pub const weakset = @import("builtins/weakset/weakset.zig");
    pub const reflect = @import("builtins/reflect/reflect.zig");
    pub const proxy = @import("builtins/proxy/proxy.zig");
    pub const arraybuffer = @import("builtins/arraybuffer/arraybuffer.zig");
    pub const typedarray = @import("builtins/typedarray/typedarray.zig");
    pub const dataview = @import("builtins/dataview/dataview.zig");
    pub const atomics = @import("builtins/atomics/atomics.zig");
    pub const intl = @import("builtins/intl/intl.zig");
    pub const iterator = @import("builtins/iterator/iterator.zig");
};

pub const utils = struct {
    pub const bit = @import("utils/bit.zig");
    pub const hash = @import("utils/hash.zig");
    pub const math = @import("utils/math.zig");
    pub const time = @import("utils/time.zig");
    pub const log = @import("utils/log.zig");
    pub const assert = @import("utils/assert.zig");
};

pub fn buildInfo() type {
    return struct {
        pub const name = "Solarium";
        pub const major = version.major;
        pub const minor = version.minor;
        pub const patch = version.patch;
        pub const semver = version.string;
        pub const zig_version = "0.14.0";
    };
}
