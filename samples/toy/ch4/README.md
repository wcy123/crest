# Toy Ch4 — Inlining

Ch4 inlines `toy.generic_call` and adds `toy.cast` to handle ranked/unranked
tensor mismatches that appear at call boundaries after inlining.

The inlining is done by MLIR's inliner pass, as in the C++ tutorial. The pass needs four things from the dialect.
Two are new in Ch4: `toy.generic_call` implements `CallOpInterface` (its `:interfaces` give the callee, the argument
operands and `(getArgOperandsMutable :all-operands)`, as the C++ op does with `getCallableForCallee` and
`getArgOperands`), and the dialect has a `DialectInlinerInterface`, which says that inlining is legal and how to convert
a call operand to the type of the parameter of the callee. The other two are there since Ch2: `toy.func` is callable
(`CallableOpInterface`) and `toy.return` is a terminator (`:traits (terminator)`). Like Ch2 and Ch3, Ch4 needs LLVM 23.

## What you learn about MLIR here

Ch3 showed that an op can bring its own rewrite patterns. Ch4 is the other direction: MLIR passes that know nothing
about Toy, and what the dialect has to tell them.

1. **A generic pass asks through interfaces.** The inliner works on any dialect, so it does not look at `toy.*` ops.
   An op interface says what an op is: `CallOpInterface` on `toy.generic_call` (the callee and the argument operands)
   and `CallableOpInterface` on `toy.func` (the body and the types). A dialect interface says what the dialect
   allows: `DialectInlinerInterface`. They are the `:interfaces` clauses in `toy.sls`; in C++ they are
   `DeclareOpInterfaceMethods<CallOpInterface>` in `Ops.td` and `ToyInlinerInterface` in `Dialect.cpp`.
2. **Inlining can make a type mismatch, and the dialect repairs it.** The callee takes `tensor<*xf64>` and the caller
   passes a ranked tensor. The inliner calls `materializeCallConversion`, which creates a `toy.cast`, and
   `handleTerminator`, which replaces the results of the call by the operands of the cloned `toy.return`.
   [inlining.md](inlining.md) walks through it.
3. **An op can exist only to bridge one step of a pipeline.** `toy.cast` has the traits `pure` and
   `same-operands-and-result-shape`. When shape inference has given the types, the cast changes nothing, and its folder
   (`:fold`) removes it.
4. **Shape inference is a rewrite to a fixed point.** Each pattern gives an op with an unranked result a precise type
   when its operands are ranked, and the greedy rewriter repeats until nothing changes (`shape-inference.sls`). The C++
   tutorial writes the same with an op interface (`ShapeInferenceOpInterface`) and a pass with a worklist.
5. **The order of the passes matters.** A `PassManager` runs the inliner on the module and the other passes nested on
   `toy.func`: inline, then shape inference, then canonicalize and CSE (`toyc.sls`; `toyc.cpp` in C++). Each pass needs
   what the one before made: after inlining the transpositions are in one function, so canonicalization can remove
   them. CSE merges equal ops, which is safe for ops marked `pure`.

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
source. Its text form is the C++ `assemblyFormat`, declared with `:assembly-format`
(`toy.cast %0 : tensor<2xf64> to tensor<*xf64>`).

### `--opt` pipeline (`toyc.sls`)

Three steps run in order when `--opt` is passed:

1. **Inline** — MLIR's inliner pass (`mlir::createInlinerPass`, run on a
   `PassManager` in `toyc.sls`) replaces each `toy.generic_call` with the
   callee's body, calling the dialect's `materializeCallConversion` to cast a
   ranked argument to the callee's unranked parameter type, and erases the
   private functions that are dead afterwards.
2. **Shape inference** — four rewrite patterns (`shape-inference.sls`) for
   `toy.add`, `toy.mul`, `toy.cast` and `toy.transpose`. Each fires on an op
   with an unranked result whose operands are ranked and replaces it with the
   same op with the inferred result type; the greedy rewriter applies them to
   a fixed point.
3. **Canonicalize + CSE** — nested on `toy.func`: MLIR's canonicalizer, with the patterns of
   [Ch3](../ch3/README.md) that the ops register themselves, and CSE, which is new. After inlining and shape
   inference the transpositions are in the same function, so the redundant-transpose pattern fires.

## Commands

```sh
# Dump MLIR after inline → shape inference → canonicalize
./toyc example.toy --emit=mlir --opt
```

`--emit=ast`, `--emit=mlir` without `--opt`, and `.mlir` input work as in Ch3.

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, `mlir-gen.sls`, the canonicalization patterns | `define-dialect`, `begin-mlir-code`, `define-rewrite-pattern` | as in Ch2 and Ch3 |
| The text form of `toy.cast` | `:assembly-format` | `` $input attr-dict `:` type($input) `to` type($output) ``, as in C++; it prints `toy.cast %0 : tensor<2xf64> to tensor<*xf64>` |
| The cast the inliner interface creates | `begin-mlir-code` inside the `materializeCallConversion` callback | the callback gets a builder; `with-current-OpBuilder` installs it |
| Inlining | MLIR's inliner pass (added to the `PassManager` in `toyc.sls`) | the dialect declares what the pass needs (`CallOpInterface`, a terminator trait, `DialectInlinerInterface`); no inliner is written in Scheme |
| Shape inference | `define-rewrite-pattern` (`shape-inference.sls`), applied by the greedy rewriter | one pattern per op; the C++ pass does it with an op interface |

## Related Documents

- [inlining.md](inlining.md) — step-by-step walkthrough of how MLIR's inliner
  calls `handleTerminator` on the dialect's interface, and why the callback is
  dialect-specific
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns that
  Ch4 inherits
