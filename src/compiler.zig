const std = @import("std");

// first read the json file and extract all text and options

const FunctionId = u16;

const FnContext = struct {
    const Self = @This();
    id: FunctionId, //id of fn

    options: []std.json.Value,

    text: string_signature, // slice of the text

    optionFns: std.ArrayList(FunctionId),

    /// makes fncontext from json value
    pub fn init(val: std.json.ObjectMap, id: FunctionId, allocator: std.mem.Allocator) Self {
        return Self{
            .id = id,
            .text = val.get("text").?.string,
            .options = val.get("answs").?.array.items,
            // nothing is appended to this at any point
            .optionFns = std.ArrayList(FunctionId).init(allocator),
        };
    }
};

// this exists for debugging
const string_signature = []const u8;

/// contains all data
const _Parsed = struct {
    // all static text
    strings: std.ArrayList(string_signature),

    // all fn definitions
    fns: std.ArrayList(FnContext),
};

/// compiles a json file that contains the conversation tree to C header
pub fn compileConvTree(outFile: *std.fs.File, objmap: std.json.ObjectMap) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var state = _Parsed{
        .strings = std.ArrayList(string_signature).init(allocator),
        .fns = std.ArrayList(FnContext).init(allocator),
    };

    // funciton id is a running value rn
    // could be some other thing but now it is the index of the fn n the function arraylist
    var FnId: u16 = 0;

    // this is recursive datastructure we need to recursively parse it
    const root = objmap.get("f").?;

    // add root to state
    {
        const fn_context = FnContext.init(root.object, FnId, allocator);
        FnId += 1;

        try state.fns.append(fn_context);

        try state.strings.append(root.object.get("text").?.string);
    }
    // recursively add all fns
    try recursiveFnParse(root, &FnId, allocator, &state);

    try writeToFile(outFile, &state, allocator);
}

/// start writing state to file
fn writeToFile(outFile: *std.fs.File, state: *_Parsed, allocator: std.mem.Allocator) !void {
    // include guard
    _ = try outFile.write("#ifndef __CONV_TREE_HEADER \n");
    _ = try outFile.write("#define __CONV_TREE_HEADER \n");
    _ = try outFile.write("\n");

    // standard definitions
    _ = try outFile.write("#include <stdio.h>\n");
    _ = try outFile.write("#include <stdlib.h>\n");
    _ = try outFile.write("\n");

    _ = try outFile.write("// STATIC STRING DEFINITIONS\n\n");

    // debug to see that things are real
    for (state.strings.items, 0..) |value, i| {
        try std.fmt.format(outFile.writer(), "static const char* string{d} = \"{s}\";\n", .{ i, value });
        // define answer strings here aswell

        // this algo leaks mem like hell but we are using arena allocator here so it is good??
        var optionString: []u8 = "";
        for (state.fns.items[i].options) |answerName| {
            optionString = try std.mem.concat(allocator, u8, &.{ optionString, "\"", answerName.string, "\"", "," });
        }
        try std.fmt.format(outFile.writer(), "static const char* fn{d}ans[] = {{ {?s} }};\n", .{
            i,
            optionString,
        });
    }
    _ = try outFile.write("\n");

    // fn pointer signature
    // FnContext (*func)(int)
    // normal fn signature
    // FnContext fnname (int answer);

    // declaration of the return value
    const structDef =
        \\typedef struct FnContext{
        \\    const char* text;
        \\    const int answerC;
        \\    const char** answers;
        \\    struct FnContext (*func)(int);
        \\}FnContext;
        \\
    ;
    _ = try outFile.write("// MISC DECLARATIONS\n\n");
    try std.fmt.format(outFile.writer(), "{s}\n", .{structDef});

    _ = try outFile.write("static void fatal(const char *txt){ printf(\"%s\\n\",txt);exit(1); } \n");

    // fn declarationw before definitions
    _ = try outFile.write("static FnContext convTreeRoot(void);\n\n");

    _ = try outFile.write("// FUNCTION DECLARATIONS\n\n");
    try writeFnDeclarations(outFile, state);
    _ = try outFile.write("\n");

    _ = try outFile.write("// FUNCTION DEFINITIONS\n\n");

    _ = try outFile.write("FnContext convTreeRoot(void){\n");

    // TODO this needs the string fn contesxt
    try std.fmt.format(outFile.writer(), "\treturn {c}.text= string{d}, .answerC= {d}, .answers=fn0ans, .func = fnp{s} {c} ; \n", .{
        '{', 0, state.fns.items[0].options.len, "0", // id of the first fn
        '}',
    });
    _ = try outFile.write("}\n");

    for (0..state.fns.items.len) |id| {
        try writeFnDefinition(outFile, state, @intCast(id));
    }

    _ = try outFile.write("#endif\n");
}

/// write definition for function
fn writeFnDefinition(outFile: *std.fs.File, state: *_Parsed, id: FunctionId) !void {
    try std.fmt.format(outFile.writer(), "FnContext fnp{d}(int option)", .{id});
    _ = try outFile.write("{\n");
    try writeSwitchStatement(outFile, state, id);
    _ = try outFile.write("}\n");
}

/// write function definition to c outfile
fn writeFnDeclarations(outFile: *std.fs.File, state: *_Parsed) !void {
    for (0..state.fns.items.len) |i| {
        try std.fmt.format(outFile.writer(), "static FnContext fnp{d}(int option);\n", .{i});
    }
}

/// write C switch statement to outfile
fn writeSwitchStatement(outFile: *std.fs.File, state: *_Parsed, id: FunctionId) !void {
    //
    try std.fmt.format(outFile.writer(), "\tswitch(option)", .{});
    _ = try outFile.write("{\n");

    const nofOptions = state.fns.items[@intCast(id)].options.len;
    for (0..nofOptions) |i| {
        try std.fmt.format(outFile.writer(), "\t\tcase {d}:\n", .{i});
        // return appropriate struct

        const childFnId = state.fns.items[@intCast(id)].optionFns.items[i]; // need to find propper child fn id's
        const childFn = state.fns.items[@intCast(childFnId)];

        try std.fmt.format(outFile.writer(), "\t\t\treturn {c}.text= string{d}, .answerC= {d},  .answers= fn{d}ans,.func = fnp{d}, {c} ; \n", .{
            '{',
            childFnId,
            childFn.options.len,
            childFnId,
            childFnId, // we need to define all fns
            '}',
        });

        _ = try outFile.write("\t\t\tbreak;\n");
    }

    _ = try outFile.write("\t\tdefault:\n");
    _ = try outFile.write("\t\t\tfatal(\"Incorrect Option\");\n");
    _ = try outFile.write("\t}\n");
    _ = try outFile.write("\texit(1);\n");
}

// this fn needs rewrite
// appends to list
fn recursiveFnParse(node: std.json.Value, id: *FunctionId, allocator: std.mem.Allocator, state: *_Parsed) !void {

    // go throuhg the answs list and add the fns
    const anslist = node.object.get("answs").?.array;
    var node_fn_object = &state.fns.items[id.* - 1];
    for (anslist.items) |value| {
        // js object that defines the child function
        const fnobj = node.object.get(value.string).?.object;

        const fn_context = FnContext.init(fnobj, id.*, allocator); // this is child fncontext??

        // node fn objects optionfsn needs to be updated
        try node_fn_object.optionFns.append(id.*);
        id.* += 1;

        try state.fns.append(fn_context);

        try state.strings.append(fnobj.get("text").?.string);

        // recall this fn
        try recursiveFnParse(node.object.get(value.string).?, id, allocator, state);
    }
}
