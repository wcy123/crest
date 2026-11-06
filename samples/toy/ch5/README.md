# Toy Ch5 — Partial Lowering to Affine Dialects

Ch5 adds `--emit=mlir-affine`, which partially lowers the Toy dialect to a
combination of `affine`, `arith`, `memref`, and `func` dialects.

## What's new over Ch4

| Feature | Ch4 | Ch5 |
|---|---|---|
| Actions | `ast`, `mlir` | `ast`, `mlir`, `mlir-affine` |
| Inliner | Scheme-level walk | Scheme-level walk (unchanged) |
| `--emit=mlir-affine` | — | partial lowering to Affine+Arith+MemRef+Func |
| Post-lowering passes | — | canonicalize + CSE on `func.func` |
| `--opt` additions | canonicalize | + loop fusion + affine scalar replacement |

### Conversion patterns (`lower-to-affine.sls`)

| Source op | Target |
|---|---|
| `toy.constant` | `memref.alloc` + `affine.store` per element |
| `toy.add` | `affine.for` nest + `arith.addf` + `affine.store` |
| `toy.mul` | `affine.for` nest + `arith.mulf` + `affine.store` |
| `toy.transpose` | `affine.for` nest with reversed-index `affine.load` |
| `toy.func @main` | `func.func @main` (other functions are inlined) |
| `toy.return` | `func.return` (void only) |
| `toy.print` | operand update tensor → memref; op kept for later lowering |

Every pattern is a `define-conversion-pattern`, and every op it creates is a `begin-mlir-code`
form: `memref.alloc` and `memref.dealloc` (at the start and before the terminator of the
block, under an `InsertionGuard`), the `affine.for` nest with its bounds as `affine-map-attr`s and
each loop body a `^body` block, `affine.load` and `affine.store` with an identity map, and
`arith.constant`, `arith.addf` and `arith.mulf`. No typed builder is called. A pattern that
replaces its op with a value ends with that value, here the `memref.alloc`. The loop nest is
written out, rather than built by MLIR's `buildAffineLoopNest` callback API, so the whole
lowering reads as the IR it produces.

### `--emit=mlir-affine` pipeline (`toyc.sls`)

1. **Inline** — Scheme-level `%%inline-calls!`, as in Ch4
2. **Shape inference** — rewrite patterns (`shape-inference.sls`), as in Ch4
3. **Canonicalize** — greedy rewrite (Ch3/Ch4 patterns)
4. **Partial lowering** — Scheme-level `%%toy-to-affine-lower!`
5. **Canonicalize + CSE** — on `func.func` bodies
6. **(--opt only)** Loop fusion + affine scalar replacement on `func.func`

## Commands

```sh
# Dump the AST
./toyc example.toy --emit=ast

# Raw Toy MLIR (no optimization)
./toyc example.toy --emit=mlir

# Toy MLIR after inline + shape inference + canonicalize
./toyc example.toy --emit=mlir --opt

# Partially lowered to Affine+Arith+MemRef+Func
./toyc example.toy --emit=mlir-affine

# Lowered + loop fusion + scalar replacement
./toyc example.toy --emit=mlir-affine --opt
```

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, `mlir-gen.sls`, the canonicalization patterns | `define-dialect`, `begin-mlir-code`, `define-rewrite-pattern` | as in Ch4 |
| The affine lowering of `toy.constant`, `toy.add`, `toy.mul`, `toy.transpose`, `toy.func`, `toy.return`, `toy.print` | `define-conversion-pattern`, with every op a `begin-mlir-code` form | see the section above |
| Registering the conversion | `apply-conversion` (`:mode partial`, `:type-converter`, `:legal-dialects`, `:illegal-dialects`, `:dynamically-legal`, `:patterns`) | one declaration instead of a type converter, a target and a pattern set created and freed by hand |
| Moving the body of `toy.func` into `func.func` | `(:move-region op)` | the region moves, it is not rebuilt |
| Shape inference | `define-rewrite-pattern`, as in Ch4 | |
| Inlining | Scheme, as in Ch4 | the reasons are in the Ch4 README |

## Related Documents

- [inlining.md](../ch4/inlining.md) — how `DialectInlinerInterface` works
- [../ch4/README.md](../ch4/README.md) — Ch4 inlining feature
