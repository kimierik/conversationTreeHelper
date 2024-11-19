const std = @import("std");
const rl = @import("raylib");

// TODO:
// make build file have the possibility of running the compiler seperately from the gui editor that will be made later

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const guiTool_dep = b.dependency("guiTool", .{ .target = target, .optimize = optimize });
    const cliTool_dep = b.dependency("cliTool", .{ .target = target, .optimize = optimize });

    const guiTool = guiTool_dep.artifact("guiTool");
    const cliTool = cliTool_dep.artifact("cliTool");

    b.installArtifact(guiTool);
    b.installArtifact(cliTool);

    // rn gui
    const gui_run_cmd = b.addRunArtifact(guiTool);
    gui_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        gui_run_cmd.addArgs(args);
    }

    const guirun_step = b.step("gui", "run gui");
    guirun_step.dependOn(&gui_run_cmd.step);

    // cli
    const run_cmd = b.addRunArtifact(cliTool);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("cli", "run cli tool");
    run_step.dependOn(&run_cmd.step);
}
