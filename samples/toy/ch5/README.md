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

### `--emit=mlir-affine` pipeline (`toyc.sls`)

1. **Inline** — Scheme-level `%%inline-calls!`, as in Ch4
2. **Shape inference** — Scheme walk per `toy.func`
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

## Related Documents

- [inlining.md](../ch4/inlining.md) — how `DialectInlinerInterface` works
- [../ch4/README.md](../ch4/README.md) — Ch4 inlining feature
