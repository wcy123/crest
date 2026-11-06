# Toy Ch2 — The Toy Dialect and MLIR Generation

Ch2 defines the `toy` dialect in Scheme and turns the AST into MLIR. The output is printed in
MLIR's generic form (`"toy.func"() ({ ... })`): the dialect has no custom syntax yet, and Ch3
adds it.

```sh
# From the repository root
./samples/toy/ch2/toyc samples/toy/ch2/example.toy --emit=ast
./samples/toy/ch2/toyc samples/toy/ch2/example.toy --emit=mlir
```

## Files

| File | What it does |
|---|---|
| `toy.sls` | the `toy` dialect: `define-dialect` with its ops (`constant`, `add`, `mul`, `transpose`, `reshape`, `generic_call`, `func`, `return`, `print`) |
| `mlir-gen.sls` | walks the AST and creates the ops |
| `lexer.sls`, `parser.sls`, `ast.sls` | as in Ch1 |
| `toyc.sls` | the driver: `--emit=ast` or `--emit=mlir` |

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect and its ops | `define-dialect` and `define-op` | the whole dialect is one declaration; the callbacks inside it are Scheme |
| Every op `mlir-gen.sls` creates | `begin-mlir-code`, with `:loc` carrying the Toy source location | one op-form per op; no `OperationState`, no explicit builder |
| The module that holds the functions | `mlir::ModuleOp::create` | it is the container, not an op the DSL builds |
| Lexer, parser, AST, driver | plain Scheme | not MLIR |

`test/toy/dsl-coverage.mlir` keeps this honest: it fails if a Toy tutorial creates an op with an
`OperationState` or a typed builder without being listed as an exception.
