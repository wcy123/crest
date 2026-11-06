# Toy Ch1 — The Language and its AST

Ch1 reads a Toy program and prints its AST. It has no MLIR in it: a lexer, a recursive-descent
parser and the AST types, all plain Scheme. Every later chapter builds on these three files.

```sh
# From the repository root
./samples/toy/ch1/toyc samples/toy/ch1/example.toy --emit=ast
```

## Files

| File | What it does |
|---|---|
| `lexer.sls` | tokens: identifiers, numbers, punctuation, with line and column |
| `parser.sls` | recursive-descent parser producing the AST, and the AST dump |
| `ast.sls` | AST records: functions, prototypes, expressions, source locations |
| `toyc.sls` | the driver: reads the file and runs the one action, `--emit=ast` |

## What is written with the DSL

Nothing here uses CREST: there is no MLIR yet. The DSL starts in
[Ch2](../ch2/README.md), where the program is turned into IR.
