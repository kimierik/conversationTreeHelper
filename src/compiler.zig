const std = @import("std");

// first read the json file and extract all text and options

const FunctionId = u16;

const FnContext = struct {
    const Self = @This();
    id: FunctionId, //id of fn

    options: usize, // num of options

    text: string_signature, // slice of the text

    optionFns: std.ArrayList(FunctionId),

    /// makes fncontext from json value
    pub fn init(val: std.json.ObjectMap, id: FunctionId, allocator: std.mem.Allocator) Self {
        return Self{
            .id = id,
            .text = val.get("text").?.string,
            .options = val.get("answs").?.array.items.len,
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
        var fn_context = FnContext.init(root.object, FnId, allocator);
        FnId += 1;
        // this should be real??
        try fn_context.optionFns.append(FnId);

        try state.fns.append(fn_context);

        try state.strings.append(root.object.get("text").?.string);
    }
    // recursively add all fns
    try recursiveFnParse(root, &FnId, allocator, &state);

    try writeToFile(outFile, &state);
}

/// start writing state to file
fn writeToFile(outFile: *std.fs.File, state: *_Parsed) !void {
    _ = try outFile.write("#ifndef __CONV_TREE_HEADER \n");
    _ = try outFile.write("#define __CONV_TREE_HEADER \n");

    _ = try outFile.write("// STATIC STRING DEFINITIONS\n\n");

    // debug to see that things are real
    for (state.strings.items, 0..) |value, i| {
        try std.fmt.format(outFile.writer(), "static const char* string{d} = \"{s}\";\n", .{ i, value });
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
        \\    struct FnContext (*func)(int);
        \\}FnContext;
        \\
    ;
    try std.fmt.format(outFile.writer(), "{s}\n", .{structDef});

    // fn declarationw before definitions
    _ = try outFile.write("static FnContext convTreeRoot(void);\n");

    _ = try outFile.write("\n");

    // include guard for definitions
    _ = try outFile.write("#ifndef __CONV_TREE_IMPLEMENTATION \n");
    _ = try outFile.write("#define __CONV_TREE_IMPLEMENTATION \n");
    _ = try outFile.write("FnContext convTreeRoot(void){\n");

    try std.fmt.format(outFile.writer(), "\t return {c}.text= \"{s}\", .answerC= {d}, .func = {s} {c} ; \n", .{
        '{',
        state.strings.items[0],
        state.fns.items[0].options,
        "0", // we need the address of the first function and the definition of it
        '}',
    });
    _ = try outFile.write("}\n");

    // fn definitions
    _ = try outFile.write("#endif\n");
    _ = try outFile.write("#endif\n");
}

// appends to list
fn recursiveFnParse(node: std.json.Value, id: *FunctionId, allocator: std.mem.Allocator, state: *_Parsed) !void {
    // go throuhg the answs list and add the fns
    const anslist = node.object.get("answs").?.array;
    for (anslist.items) |value| {
        const fnobj = node.object.get(value.string).?.object;

        var fn_context = FnContext.init(fnobj, id.*, allocator);
        id.* += 1;
        // this should be real??
        try fn_context.optionFns.append(id.*);

        try state.fns.append(fn_context);

        try state.strings.append(fnobj.get("text").?.string);

        // recall this fn
        try recursiveFnParse(node.object.get(value.string).?, id, allocator, state);
    }
}
