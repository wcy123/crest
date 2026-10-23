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
