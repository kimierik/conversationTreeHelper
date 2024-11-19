# Conversation tree builder tool
Tool for making conversation trees that compiles into a single C header file.

## motivation
The goal of this is to help making text based games with large conversation trees less tedious and give the developper a way to compile the conversation tree to a native langauge.


# Building 
```sh
zig build 
```
This builds a Gui and a Cli tool to zig-out/bin.

  
The tool compiles a json file. [examples here](./testjson).
Json files can be made manually but using generated json files is advised.

  
# header useage
the header exposes the following function as an entrypoint
```c
static FnContext convTreeRoot(void);
```
calling this function returns context for the next node.
Context is defined as follows.
```c
typedef struct FnContext{
    const char* text;
    const int answerC;
    const char** answers;
    struct FnContext (*func)(int);
}FnContext;
```

The "text" field contains the text of the current node. This is the entrypoint and first node of the conversation tree.
```c
    const char* text; 
```

The "answerC" field contains the num of answers the next fn has defined. all answers need to be more than 0 and less than answerC.
```c
    const int answerC; 
```
The "func" field contains a functino pointer that can be called with whatever answer the user has chosen. The function returns the context of the next node of the conversation tree.
```c
    struct FnContext (*func)(int);
```

The "answers" field contains all the answers or paths the user can take in this node.
```c
    const char** answers;
```


# TODO
- Gui tool for visualising and building conversation trees.
- json file generation
- Option to check flags on each node
- support multiple languages
