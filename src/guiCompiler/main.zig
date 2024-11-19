const std = @import("std");
const rayl = @import("raylib.zig");
const rl = rayl.Raylib;

// GUI TOOL FOR GENERATING CONVERRSATION TREES

pub fn main() !void {
    rl.InitWindow(500, 500, "wow");
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        _ = rl.GuiButton(.{ .x = 0, .y = 0, .height = 50, .width = 50 }, "asdf");
    }

    // shid
}
