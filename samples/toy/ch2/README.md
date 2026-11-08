# Toy Ch2 — The Toy Dialect and MLIR Generation

Ch2 defines the `toy` dialect in Scheme and turns the AST into MLIR, printed in the custom form of the
C++ tutorial (`toy.func @main() { ... }`). The dialect declares `toy.return` as a terminator
(`:traits (terminator)`), which needs LLVM 23.

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
| The text form of `toy.print`, `toy.transpose`, `toy.reshape`, `toy.generic_call` and `toy.return` | `:assembly-format` | the same strings as the `assemblyFormat` of the C++ `Ops.td`; `toy.constant`, `toy.add`, `toy.mul` and `toy.func` have a hand-written `:parse` and `:print`, as in C++ (`hasCustomAssemblyFormat`) |
| Every op `mlir-gen.sls` creates | `begin-mlir-code`, with `:loc` carrying the Toy source location | one op-form per op; no `OperationState`, no explicit builder |
| The result types of `toy.constant`, `toy.add`, `toy.mul` and `toy.transpose` | `:interfaces ((mlir::InferTypeOpInterface ...))` | C++ gives these ops builders that work out the result type (`ConstantOp` takes the type of its value, the others an unranked `f64` tensor), so `MLIRGen.cpp` names none. Here the op infers it through `InferTypeOpInterface`, so `mlir-gen.sls` writes no `-> type` for them. `toy.reshape`, `toy.generic_call` and `toy.struct_constant` take an explicit type in C++ and here |
| The module that holds the functions | `mlir::ModuleOp::create` | it is the container, not an op the DSL builds |
| Lexer, parser, AST, driver | plain Scheme | not MLIR |

`test/toy/infer-result-types.mlir` keeps the result types honest in the same way: it fails if an op-form in
`mlir-gen.sls` writes a `-> type` for an op that infers it.

`test/toy/dsl-coverage.mlir` keeps this honest: it fails if a Toy tutorial creates an op with an
`OperationState` or a typed builder without being listed as an exception.
