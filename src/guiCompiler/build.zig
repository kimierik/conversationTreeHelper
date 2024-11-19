const std = @import("std");
const rl = @import("raylib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const guiTool = b.addExecutable(.{
        .name = "guiTool",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    const raygui_dep = b.dependency("raygui", .{});
    const rlart = raylib.artifact("raylib");

    rl.addRaygui(b, rlart, raygui_dep);

    guiTool.linkLibrary(rlart);
    b.installArtifact(guiTool);
}
