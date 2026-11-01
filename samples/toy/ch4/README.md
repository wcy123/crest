# Toy Ch4 — Inlining

Ch4 enables MLIR's generic inliner for `toy.generic_call` and adds `toy.cast`
to handle ranked/unranked tensor mismatches that appear at call boundaries
after inlining.

## What's new over Ch3

| Feature | Ch3 | Ch4 |
|---|---|---|
| `toy.generic_call` | stays as call op | inlined into caller |
| `toy.cast` op | — | inserted at ranked/unranked boundaries |
| `DialectInlinerInterface` | — | added to toy dialect |
| `--opt` pipeline | canonicalization only | inline → shape inference → canonicalize |

### `DialectInlinerInterface` (`toy.sls`)

Three legality predicates — all return `true` (toy permits inlining
everywhere):

| Method | Guards |
|---|---|
| `isLegalToInline/call` | whether a call may be inlined |
| `isLegalToInline/region` | whether a region may be inlined into a dest region |
| `isLegalToInline/op` | whether a single op may be inlined |

Two action callbacks:

**`handleTerminator`** — called with the cloned `toy.return` and the list of
call-site SSA results that need new definitions. Redirects each call result to
the corresponding return operand via `replaceAllUsesWith`. See
[inlining.md](inlining.md) for a step-by-step walkthrough.

**`materializeCallConversion`** — called when the return type and call-result
type differ (ranked vs. unranked tensor). Inserts a `toy.cast` op to bridge
the mismatch. Shape inference resolves the cast in the next pipeline step.

### `toy.cast` op (`toy.sls`)

Bridges a ranked/unranked tensor mismatch at a call boundary. Inserted
automatically by `materializeCallConversion`; not written by hand in Toy
source. Uses the same `%%parse-unary-to-type` / `%%print-unary-to-type`
assembly format as `transpose` and `reshape`.

### `--opt` pipeline (`toyc.sls`)

Three steps run in order when `--opt` is passed:

1. **Inline** — runs MLIR's inliner, consuming all `toy.generic_call` ops and
   eliminating private functions.
2. **Shape inference** — walks each `toy.func` body; for every op with
   unranked result types whose operands are all ranked, infers and sets the
   result type. Repeats to fixed point.
3. **Canonicalize** — applies the same four patterns from Ch3
   (`SimplifyRedundantTranspose`, `ReshapeReshapeOpt`, `RedundantReshape`,
   `FoldConstantReshape`). After inlining and shape inference, transpositions
   are now in the same function and the redundant-transpose pattern fires.

## Commands

```sh
# Dump the AST
./toyc example.toy --emit=ast

# Dump raw MLIR (no optimization)
./toyc example.toy --emit=mlir

# Dump MLIR after inline → shape inference → canonicalize
./toyc example.toy --emit=mlir --opt
```

## Related Documents

- [inlining.md](inlining.md) — step-by-step walkthrough of how the MLIR
  inliner calls `handleTerminator` and why the callback is dialect-specific
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns that
  Ch4 inherits
