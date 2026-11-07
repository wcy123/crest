# Toy Ch4 — Inlining

Ch4 inlines `toy.generic_call` and adds `toy.cast` to handle ranked/unranked
tensor mismatches that appear at call boundaries after inlining.

The inlining is done by a Scheme-level inliner in `toyc.sls`, not by MLIR's
inliner pass. MLIR's inliner needs `toy.generic_call` to implement
`CallOpInterface` (a Scheme dialect can declare it), `toy.func` to be callable
(it is, through `FunctionOpInterface`) and `toy.return` to be a terminator. The
terminator needs `:traits (terminator)`, which exists only on LLVM 23; this
tutorial is also built on LLVM 22, where the verifier rejects a block that ends
in a Scheme op. The dialect still defines the `DialectInlinerInterface` that
MLIR's inliner would use.

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

1. **Inline** — the Scheme-level `%%inline-calls!` clones each callee body in
   front of its call, consuming all `toy.generic_call` ops, and then removes
   the private functions.
2. **Shape inference** — four rewrite patterns (`shape-inference.sls`) for
   `toy.add`, `toy.mul`, `toy.cast` and `toy.transpose`. Each fires on an op
   with an unranked result whose operands are ranked and replaces it with the
   same op with the inferred result type; the greedy rewriter applies them to
   a fixed point.
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

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, including `toy.cast` | `define-dialect` | as in Ch3 |
| The cast the inliner interface creates | `begin-mlir-code` inside the `materializeCallConversion` callback | the callback gets a builder; `with-current-OpBuilder` installs it |
| Every op `mlir-gen.sls` creates | `begin-mlir-code` | as in Ch2 |
| The canonicalization patterns | `define-rewrite-pattern` | as in Ch3 |
| Inlining | Scheme (`%%inline-calls!` in `toyc.sls`) | it clones ops whose name, operands and attributes are data, so each op is built with an `OperationState`. MLIR's inliner cannot replace it: it needs a terminator trait on `toy.return`, which needs LLVM 23 (the call interfaces can be declared now) |
| Shape inference | `define-rewrite-pattern` (`shape-inference.sls`), applied by the greedy rewriter | one pattern per op; the C++ pass does it with an op interface |

## Related Documents

- [inlining.md](inlining.md) — step-by-step walkthrough of how MLIR's inliner
  would call `handleTerminator` on the dialect's interface (`toyc.sls` does not
  run MLIR's inliner, see above) and why the callback is dialect-specific
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns that
  Ch4 inherits
