const std = @import("std");
const compiler = @import("compiler");

const helpmsg =
    \\Useage : compiler [options] 
    \\
    \\Options (brackets indicate defaults): 
    \\  -f  --file      specify path to file to be compiled.
    \\  -o  --outfile   specify output file [tree.h].
    \\  -h  --help      print this help messege.
    //\\  -v  --version   print version string
;

var defaultOutFile: [:0]const u8 = "tree.h";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    if (args.next()) |_| {} else {
        std.debug.print("{s}\n", .{helpmsg});
        std.process.exit(0);
    }

    var isInfileSet = false;
    var infile: *const [:0]const u8 = undefined;
    var outfile: *const [:0]const u8 = &defaultOutFile;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--file")) {
            infile = &args.next().?;
            isInfileSet = true;
        }

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--outfile")) {
            outfile = &args.next().?;
        }

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print("{s}\n", .{helpmsg});
            std.process.exit(0);
        }
    }

    // if no infile we need to error out
    // or if things are fuckd in general we need to exit with help messege
    if (!isInfileSet) {
        std.debug.print("{s}\n", .{helpmsg});
        std.process.exit(0);
    }

    // call compiler
    const filein = try std.fs.cwd().openFile(infile.*, .{});
    defer filein.close();

    const file_content = try filein.readToEndAlloc(allocator, 1024);
    defer allocator.free(file_content);

    var fileout = try std.fs.cwd().createFile(outfile.*, .{});
    defer fileout.close();

    const objmap = try std.json.parseFromSlice(std.json.Value, allocator, file_content, .{});
    defer objmap.deinit();

    try compiler.compileConvTree(&fileout, objmap.value.object);
}
