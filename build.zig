const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const solarium_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "solarium",
        .root_module = solarium_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    const shared = b.addLibrary(.{
        .name = "solarium",
        .root_module = solarium_mod,
        .linkage = .dynamic,
    });
    b.installArtifact(shared);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const repl_exe = b.addExecutable(.{
        .name = "solarium-repl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/repl.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    repl_exe.root_module.addImport("solarium", solarium_mod);
    b.installArtifact(repl_exe);

    const repl_run = b.addRunArtifact(repl_exe);
    const repl_step = b.step("repl", "Run the Solarium REPL");
    repl_step.dependOn(&repl_run.step);

    const eval_exe = b.addExecutable(.{
        .name = "solarium-eval",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/eval.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    eval_exe.root_module.addImport("solarium", solarium_mod);
    b.installArtifact(eval_exe);

    const embed_exe = b.addExecutable(.{
        .name = "solarium-embed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/embed.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    embed_exe.root_module.addImport("solarium", solarium_mod);
    b.installArtifact(embed_exe);

    const disasm_exe = b.addExecutable(.{
        .name = "solarium-disasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/disasm/disasm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    disasm_exe.root_module.addImport("solarium", solarium_mod);
    b.installArtifact(disasm_exe);

    const conformance_exe = b.addExecutable(.{
        .name = "solarium-conformance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/conformance/test_runner.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    conformance_exe.root_module.addImport("solarium", solarium_mod);
    b.installArtifact(conformance_exe);

    const benchmark_exe = b.addExecutable(.{
        .name = "solarium-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    benchmark_exe.root_module.addImport("solarium", solarium_mod);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&b.addRunArtifact(benchmark_exe).step);
}
