const std = @import("std");

// build for the cli compilertool
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const compiler_lib_dep = b.dependency("compiler", .{ .target = target, .optimize = optimize });
    const compiler_lib = compiler_lib_dep.artifact("compiler");

    const compilerTool = b.addExecutable(.{
        .name = "cliTool",
        .root_source_file = b.path("compilertool.zig"),
        .target = target,
        .optimize = optimize,
    });
    compilerTool.root_module.addImport("compiler", b.addModule("compiler", .{ .root_source_file = compiler_lib_dep.path("compiler.zig") }));

    compilerTool.linkLibrary(compiler_lib);

    b.installArtifact(compilerTool);
}
