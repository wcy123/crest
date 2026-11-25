# Toy Ch3 — Canonicalization Patterns

Ch3 adds four canonicalization rewrite patterns, which the ops bring themselves
(`:get-canonicalization-patterns` in `toy.sls`, `hasCanonicalizer` in C++) so MLIR's
canonicalizer pass finds them, and adds support for reading `.mlir` files directly as input.

## What's new over Ch2

| Feature | Ch2 | Ch3 |
|---|---|---|
| Actions | `ast`, `mlir` | `ast`, `mlir` |
| Optimization flag | — | `--opt` |
| Input formats | `.toy` only | `.toy` or `.mlir` |
| Canonicalization passes | — | 4 patterns (see below) |

### Canonicalization patterns (`combine.sls`)

These mirror `mlir/examples/toy/Ch3/mlir/ToyCombine.cpp` and `ToyCombine.td`:

| Pattern | Rule |
|---|---|
| `SimplifyRedundantTranspose` | `transpose(transpose(x))` → `x` |
| `ReshapeReshapeOpt` | `reshape(reshape(x))` → `reshape(x)` |
| `RedundantReshape` | `reshape(x)` → `x` when input and output types are identical |
| `FoldConstantReshape` | `reshape(constant(x))` → `constant(x')` (folds into new constant) |

## Commands

`./toyc` runs `$CREST_BUILD_DIR/tools/scheme-mlir/scheme-mlir` when `CREST_BUILD_DIR` is set,
and the `scheme-mlir` on `PATH` otherwise.

```sh
# Dump the AST
./toyc example.toy --emit=ast

# Dump raw MLIR (no optimization)
./toyc example.toy --emit=mlir

# Dump MLIR after canonicalization passes
./toyc example.toy --emit=mlir --opt

# Parse a .mlir file directly
./toyc some.mlir --emit=mlir

# Parse a .mlir file and apply canonicalization passes
./toyc some.mlir --emit=mlir --opt
```

## Examples of the rules

`example.toy` only shows `FoldConstantReshape`. The two programs below are the ones of the C++ tutorial
(`mlir/test/Examples/Toy/Ch3/`), and `test/toy/ch3/redundant-transpose.mlir` and
`test/toy/ch3/trivial-reshape.mlir` check them.

### `transpose_transpose.toy`

```sh
./toyc transpose_transpose.toy --emit=mlir --opt
```

```mlir
module {
  toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
    toy.return %arg0 : tensor<*xf64>
  }
  toy.func @main() {
    %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
    %1 = toy.generic_call @transpose_transpose(%0) : (tensor<2x3xf64>) -> tensor<*xf64>
    toy.print %1 : tensor<*xf64>
    toy.return
  }
}
```

Without `--opt` the function has two `toy.transpose` ops, and `main` has a `toy.reshape` of the constant to its
own type, which `var a<2, 3>` makes. `SimplifyRedundantTranspose` removes both transposes, and the reshape is gone
too.

### `trivial_reshape.toy`

```sh
./toyc trivial_reshape.toy --emit=mlir --opt
```

```mlir
module {
  toy.func @main() {
    %0 = toy.constant dense<[[1.000000e+00], [2.000000e+00]]> : tensor<2x1xf64>
    toy.print %0 : tensor<2x1xf64>
    toy.return
  }
}
```

Without `--opt` there is a flat `tensor<2xf64>` constant and three `toy.reshape` ops, one for each `var`. The
reshape rules leave one constant of type `tensor<2x1xf64>`.

Neither program isolates `ReshapeReshapeOpt`, as in the C++ tests: a reshape of a reshape of a constant is also
folded by the other rules.

> **Note:** Ch3 does not inline function calls — `main` emits `toy.generic_call`
> ops and `multiply_transpose` remains a separate function. Inlining is added in
> a later chapter. With `--opt`, `FoldConstantReshape` does fire on
> `var b<2, 3> = [1, 2, 3, 4, 5, 6]` in `example.toy`: MLIRGen emits a flat
> `tensor<6xf64>` constant plus a reshape, and the pattern folds them into a
> single `tensor<2x3xf64>` constant. `SimplifyRedundantTranspose` does not fire
> because the transpositions inside `multiply_transpose` are not nested.

## Inspecting macro expansions

`tools/debug-define-dialect` pretty-prints what `define-dialect` expands to.
It is useful for understanding what the DSL generates and for debugging macro
issues.

```sh
# From the repository root — expand define-dialect in toy.sls
# (CREST_BUILD_DIR says where crest-opt is, or crest-opt is on PATH)
tools/debug-define-dialect samples/toy/ch3/toy.sls

# Save to a file
tools/debug-define-dialect samples/toy/ch3/toy.sls > /tmp/toy3.sls
```

### Key structures in the expanded output

`define-dialect toy` expands to a `begin` containing:

**`%%toy.func:interfaces`** — the pairs of the `:interfaces` entries of `toy.func`, made once when the library is
loaded. `mlir::SymbolOpInterface`, `mlir::ArgAndResultAttrsOpInterface`, `mlir::CallableOpInterface` and
`mlir::FunctionOpInterface` are macros of `(mlir IR SymbolInterfaces)`, `(mlir Interfaces CallInterfaces)` and
`(mlir Interfaces FunctionInterfaces)`: each makes a C function (a `foreign-callable`) for each method and answers the
pair of the interface's `TypeID` and a dispatcher of them. MLIR has no default for the methods of
`CallableOpInterface` and `FunctionOpInterface`, as in C++ the op class gives them, so `toy.func` gives them as
clauses; for `SymbolOpInterface` MLIR has one for each method (the `sym_name` attribute and the others), and
`(mlir::ArgAndResultAttrsOpInterface :standard)` keeps the `arg_attrs` and `res_attrs` attributes:

```scheme
(define %%toy.func:interfaces
  (list (mlir::SymbolOpInterface)
        (mlir::ArgAndResultAttrsOpInterface :standard)
        (mlir::CallableOpInterface
         (getCallableRegion (self) (mlir::Operation::getRegion self 0))
         (getArgumentTypes (self)
           (mlir::FunctionType::getInputs
            (mlir::TypeAttr::getValue
             (mlir::Operation::getAttr self "function_type"))))
         (getResultTypes (self)
           (mlir::FunctionType::getResults
            (mlir::TypeAttr::getValue
             (mlir::Operation::getAttr self "function_type")))))
        (mlir::FunctionOpInterface
         (getFunctionType (self)
           (mlir::TypeAttr::getValue
            (mlir::Operation::getAttr self "function_type")))
         (setFunctionTypeAttr (self attr)
           (mlir::Operation::setAttr! self "function_type" attr)))))
```

**`%%toy:initialize`** — called at dialect registration time; registers every
op via `%crest::register-dynamic-op!`, which installs the interfaces of the op in its definition:

```scheme
(define (%%toy:initialize dialect-ptr)
  (%crest::register-dynamic-op! dialect-ptr "toy.constant" ...)
  ...
  (%crest::register-dynamic-op! dialect-ptr "toy.func"
                                %%toy.func:op-callbacks %%toy.func:interfaces)
  ...)
```

**`toy`** — the dialect descriptor vector passed to CREST's dialect registry:

```scheme
(define toy
  (vector %%toy:initialize #f #f #f #f #f #f #f #f #f #f))
```

**Accessor predicates and field getters** — one `?` predicate and one getter
per operand/attribute/result for every op, e.g.:

```scheme
(define (toy.constant? op)
  (string=? (mlir::Operation::getName op) "toy.constant"))
(define (toy.constant:value op) (mlir::Operation::getAttr op "value"))
(define (toy.constant:output op) (mlir::Operation::getResult op 0))
```

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, with its text form | `define-dialect`, `:assembly-format` | as in Ch2 |
| Every op `mlir-gen.sls` creates | `begin-mlir-code` | as in Ch2 |
| The four canonicalization patterns | `define-rewrite-pattern` | each one is a match and a rewrite |
| Registering the patterns | `define-pattern-set` (`combine.sls`), `:get-canonicalization-patterns` (`toy.sls`) | a table of (op, pattern, benefit) per op, registered by the op as C++ `getCanonicalizationPatterns` does |
| Applying them | `PassManager` nested on `toy.func` with `createCanonicalizerPass` (`toyc.sls`) | the canonicalizer also folds and erases dead `pure` ops, as in the C++ `toyc` |
