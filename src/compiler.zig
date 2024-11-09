const std = @import("std");

/// compiles a json file that contains the conversation tree to C header
pub fn compileConvTree(outFile: *std.fs.File, objmap: std.json.ObjectMap) !void {
    std.debug.print("ran compiler\n", .{});

    _ = outFile; // autofix
    _ = objmap; // autofix
}
