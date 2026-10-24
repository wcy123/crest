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

`tools/expand-macro` pretty-prints what `define-dialect` expands to.  It is
useful for understanding what the DSL generates and for debugging macro issues.

```sh
# From the repository root — expand define-dialect in toy.sls
tools/expand-macro --file samples/toy/ch3/toy.sls

# Save to a file
tools/expand-macro --file samples/toy/ch3/toy.sls > /tmp/toy3.sls

# Expand a different macro head
tools/expand-macro --name define-op --file samples/toy/ch3/toy.sls
```

### Key structures in the expanded output

`define-dialect toy` expands to a `begin` containing:

**`%%toy.func:mlir::FunctionOpInterface`** — the generated per-op dispatch
procedure for `toy.func`'s `FunctionOpInterface` overrides.  Methods declared
in `:interfaces` are dispatched here; everything else falls back to
`mlir::FunctionOpInterface` (which errors on required methods, enforcing that
the dialect author has overridden them):

```scheme
(set! %%toy.func:mlir::FunctionOpInterface
  (lambda (method . args)
    (case method
      ((getFunctionType)
       (apply (lambda (self)
                (mlir::TypeAttr::getValue
                 (mlir::Operation::getAttr self "function_type")))
              args))
      ((setFunctionTypeAttr)
       (apply (lambda (self attr)
                (mlir::Operation::setAttr! self "function_type" attr))
              args))
      (else (apply mlir::FunctionOpInterface method args)))))
```

**`%%toy:get-registered-interface-for-op-auto`** — routes MLIR's
`getRegisteredInterfaceForOp` calls to the right concept pointer.  Because
`toy.func` has method bodies, the Scheme-dispatch concept is used
(`crest::FunctionOpInterface::getSchemeConceptPtr`) rather than the static C++
concept:

```scheme
(set! %%toy:get-registered-interface-for-op-auto
  (lambda (iface-id op-name)
    (let ([op-name (%mlir::OperationName::getStringRef op-name)])
      (cond
        [(string=? op-name "toy.func")
         (let try ([ps (list crest::FunctionOpInterface::getSchemeConceptPtr)])
           (if (null? ps) 0
               (let ([r ((car ps) iface-id)])
                 (if (zero? r) (try (cdr ps)) r))))]
        [else 0]))))
```

**`%%toy:initialize`** — called at dialect registration time.  Registers all
ops and, for ops with Scheme method overrides, calls
`crest::FunctionOpInterface::setSchemeDispatch` to wire the dispatch procedure
into the C++ concept:

```scheme
(set! %%toy:initialize
  (lambda (dialect-ptr)
    (%crest::register-dynamic-op! dialect-ptr "toy.constant" ...)
    ...
    (%crest::register-dynamic-op! dialect-ptr "toy.func" ...)
    (crest::FunctionOpInterface::setSchemeDispatch
     "toy.func" %%toy.func:mlir::FunctionOpInterface)))
```
