const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const compilerTool = b.addStaticLibrary(.{
        .name = "compiler",
        .root_source_file = b.path("compiler.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(compilerTool);
}
