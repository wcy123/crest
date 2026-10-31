# Toy Ch3 — Canonicalization Patterns

Ch3 adds four canonicalization rewrite patterns applied via MLIR's greedy
pattern rewriter, and adds support for reading `.mlir` files directly as input.

## What's new over Ch2

| Feature | Ch2 | Ch3 |
|---|---|---|
| Actions | `ast`, `mlir` | `ast`, `mlir` |
| Optimization flag | — | `TOYC_OPT=1` (mirrors `--opt`) |
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
tools/debug-define-dialect samples/toy/ch3/toy.sls

# Save to a file
tools/debug-define-dialect samples/toy/ch3/toy.sls > /tmp/toy3.sls
```

### Key structures in the expanded output

`define-dialect toy` expands to a `begin` containing:

**`%%toy.func:mlir::FunctionOpInterface`** — the generated per-op dispatch
procedure for `toy.func`'s `FunctionOpInterface` overrides.  Methods declared
in `:interfaces` are dispatched via `case`; unrecognised methods return `#f`:

```scheme
(define (%%toy.func:mlir::FunctionOpInterface method)
  (case method
    [(operation_name) "toy.func"]
    [(getFunctionType)
     (lambda (self)
       (mlir::TypeAttr::getValue
        (mlir::Operation::getAttr self "function_type")))]
    [(setFunctionTypeAttr)
     (lambda (self attr)
       (mlir::Operation::setAttr! self "function_type" attr))]
    [else #f]))
```

**`%%toy:initialize`** — called at dialect registration time; registers every
op via `%crest::register-dynamic-op!`:

```scheme
(define (%%toy:initialize dialect-ptr)
  (%crest::register-dynamic-op! dialect-ptr "toy.constant" ...)
  ...
  (%crest::register-dynamic-op! dialect-ptr "toy.func" ...)
  ...)
```

**`toy`** — the dialect descriptor vector passed to CREST's dialect registry:

```scheme
(define toy
  (vector %%toy:initialize #f #f #f #f #f #f #f #f #f #f))
```

**`%%toy-iface-init`** — eagerly wires the Scheme dispatch procedure into the
C++ `FunctionOpInterface` concept at library load time:

```scheme
(define %%toy-iface-init
  (begin
    ((foreign-procedure "mlir::FunctionOpInterface"
       (scheme-object) void)
     %%toy.func:mlir::FunctionOpInterface)
    #t))
```

**Accessor predicates and field getters** — one `?` predicate and one getter
per operand/attribute/result for every op, e.g.:

```scheme
(define (toy.constant? op)
  (string=? (mlir::Operation::getName op) "toy.constant"))
(define (toy.constant:value op) (mlir::Operation::getAttr op "value"))
(define (toy.constant:output op) (mlir::Operation::getResult op 0))
```
