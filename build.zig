const std = @import("std");

// TODO:
// make build file have the possibility of running the compiler seperately from the gui editor that will be made later

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const compilerTool = b.addExecutable(.{
        .name = "conversationTreeTool",
        .root_source_file = b.path("src/compilertool.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(compilerTool);

    const run_cmd = b.addRunArtifact(compilerTool);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("compiler", "run compiler tool");
    run_step.dependOn(&run_cmd.step);
}
