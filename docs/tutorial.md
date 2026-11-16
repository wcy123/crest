# CREST Tutorial

This tutorial builds a rewrite pattern from scratch in three steps.
Each step adds one new concept to the previous pattern.

Prerequisites: you have CREST built and `crest-opt` on your path.
See [Getting started](getting-started.md) for build instructions.

**Contents**

1. [Step 1 — A minimal pattern](#1-a-minimal-pattern)
2. [Step 2 — Add a guard](#2-add-a-guard)
3. [Step 3 — Handle optional operands](#3-handle-optional-operands)

---

## Project layout

A typical pass lives in two files under a `passes/` directory:

```
my-project/
  passes/
    my-pass.sls          ← pass entry point (exports pass-entry-point)
    my-pass/
      patterns.sls       ← pattern definitions
      helpers.sls        ← domain helpers (optional)
```

Set `CREST_PATH` to the parent of `passes/` so CREST can find the libraries:

```bash
export CREST_PATH=/my-project
```

For a small pass a single file is fine — split into sub-libraries only
when the pattern file grows large.

---

## 1. A minimal pattern

**Goal:** replace every `source.add(%x, %y)` with `target.fused(%x, %y)`.

### The pattern

Create `passes/tutorial-step1.sls`:

```scheme
#!r6rs
(library (passes tutorial-step1)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  (define-rewrite-pattern (step1 op rewriter)
    :if-match
      %out = source.add (%x %y)
    :then-let
      ([!result-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = target.fused (%x %y) -> !result-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("source.add" step1))))))

  ) ;; end library
```

### What each part does

```
(define-rewrite-pattern (step1 op rewriter)
```
`step1` is the pattern name. `op` is the root operation (the `source.add` instance
the pattern matched). `rewriter` is the handle for emitting new ops.

```
  :if-match
    %out = source.add (%x %y)
```
Match any op named `source.add` with two operands. Bind its result to `%out`,
its operands to `%x` and `%y`. This is the **root op** — the op that will be replaced.

```
  :then-let
    ([!result-type (mlir::Value::getType %out)])
```
Runs after the match succeeded and before any IR is changed, so it is safe to read the IR here. It binds
`!result-type` to the type of `%out`. (The `!` is only a naming habit for a name that holds a type.)

```
  :rewrite %out :with
    result = target.fused (%x %y) -> !result-type
```
Emit `target.fused` with the same operands. `%out` is replaced by `result`, the last value the body makes,
in all uses. `-> !result-type` gives the result the same type as the original op. The names on the left
of `=` have no `%`; the `%` names are the ones the match bound.

### Try it

Create `test.mlir`:

```mlir
func.func @example(%a: i32, %b: i32) -> i32 {
  %0 = "source.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
```

Run:

```bash
CREST_PATH=/path/to/passes \
  crest-opt -allow-unregistered-dialect \
  --crest-pass="passes=passes/tutorial-step1" \
  test.mlir
```

Output:

```mlir
func.func @example(%arg0: i32, %arg1: i32) -> i32 {
  %0 = "target.fused"(%arg0, %arg1) : (i32, i32) -> i32
  return %0 : i32
}
```

---

## 2. Add a guard

**Goal:** only fuse when both operands have the same type.

New concept: **`:where`** — a Scheme predicate that must return truthy for the match to continue.

### The pattern

```scheme
(define-rewrite-pattern (step2 op rewriter)
  :if-match
    %out = source.add (%x %y)
      :where (equal? (mlir::Value::getType %x)
                     (mlir::Value::getType %y))
  :then-let
    ([!result-type (mlir::Value::getType %out)])
  :rewrite %out :with
    result = target.fused (%x %y) -> !result-type)
```

### What changed

**`:where`** — runs after the operands are bound. If `%x` and `%y` have different
types the predicate returns `#f` and the pattern silently skips this op.
Any Scheme expression is valid here.

---

## 3. Handle optional operands

**Goal:** match a 2-operand or 3-operand form of the same op without writing
two separate patterns. The third operand (a bias) may or may not be present.

New concept: **`(:optional %var)`** — binds `%var` when the operand is present,
leaves it unbound when absent. The op must carry an `operandSegmentSizes`
attribute so CREST knows the group boundaries.

### The pattern

```scheme
(define-rewrite-pattern (step3 op rewriter)
  :if-match
    %out = source.add (%x %y (:optional %bias))
  :then-let
    ([!result-type (mlir::Value::getType %out)]
     [extra        (if (unbound-value? %bias) '() (list %bias))])
  :rewrite %out :with
    result = target.fused (%x %y ,@extra) -> !result-type)
```

`extra` is the list of the operands that come after `%y`: empty when the bias is absent, `(%bias)` when it
is there. `,@extra` puts them in the operand list of `target.fused`, so the bias is kept.

### What changed

**`(:optional %bias)`** — CREST reads `operandSegmentSizes` on the op to
determine whether the optional slot is filled. If absent, `%bias` is bound
to the absent sentinel; test it with `(unbound-value? %bias)`.

### Try it

```mlir
func.func @both(%a: i32, %b: i32, %c: i32) -> (i32, i32) {
  // 2-operand form (bias absent)
  %0 = "source.add"(%a, %b) {operandSegmentSizes = array<i32: 1, 1, 0>} : (i32, i32) -> i32
  // 3-operand form (bias present)
  %1 = "source.add"(%a, %b, %c) {operandSegmentSizes = array<i32: 1, 1, 1>} : (i32, i32, i32) -> i32
  return %0, %1 : i32, i32
}
```

The output has `target.fused(%arg0, %arg1)` and `target.fused(%arg0, %arg1, %arg2)`.
Both match the same pattern. Without `:optional` you would need two separate
patterns — one for each arity.

---

## Next steps

- Read the [Manual](manual.md) for the complete DSL reference.
- Study `samples/passes/hip-fusion/qadd.sls` for a real 7-op fusion pattern
  that uses `:optional`, `:where`, `:then-let`, and attribute extraction.
- Study `samples/passes/onnx-to-hipsr/matmul.sls` for a dialect conversion
  pattern with nested regions.
- Follow the Toy tutorial in `samples/toy`, chapter by chapter. Each chapter README ends with a
  table of what is written with the DSL and why the rest is not:
  [Ch2](../samples/toy/ch2/README.md) shows `define-dialect` and `begin-mlir-code` generating IR,
  [Ch3](../samples/toy/ch3/README.md) and [Ch4](../samples/toy/ch4/README.md) show
  `define-rewrite-pattern`, [Ch5](../samples/toy/ch5/README.md) shows
  `define-conversion-pattern`, `apply-conversion`, `:move-region` and regions with `^bb`, and
  [Ch6](../samples/toy/ch6/README.md) shows a full lowering to LLVM.
