# CREST Tutorial

This tutorial builds a rewrite pattern from scratch in three steps.
Each step adds one new concept to the previous pattern.

Prerequisites: you have CREST built and `crest-opt` on your path.
See [Getting started](getting-started.md) for build instructions.

**Contents**

1. [Step 1 — A minimal pattern](#1-a-minimal-pattern)
2. [Step 2 — Add a guard and pre-rewrite computation](#2-add-a-guard-and-pre-rewrite-computation)
3. [Step 3 — Handle optional operands](#3-handle-optional-operands)

---

## 1. A minimal pattern

**Goal:** replace every `source.add(%x, %y)` with `target.fused(%x, %y)`.

### The pattern

Create `passes/tutorial-step1.sls`:

```scheme
#!r6rs
(library (passes tutorial-step1)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (step1 op rewriter)
    :if-match
      %out = source.add (%x %y)
    :rewrite %out :with
      (%result = target.fused (%x %y) -> (mlir::Value::getType %out)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps)
          (add-rewrite-pattern ps "source.add" step1 1)
          (mlir::applyPatternsGreedily module-op ps)))))

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
  :rewrite %out :with
    (%result = target.fused (%x %y) -> (mlir::Value::getType %out))
```
Emit `target.fused` with the same operands. `%out` is replaced by `%result` in all uses.
`-> (mlir::Value::getType %out)` gives the result the same type as the original op.

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
  --crest-pass="module=passes/tutorial-step1" \
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

## 2. Add a guard and pre-rewrite computation

**Goal:** only fuse when both operands have the same type; extract the type
before the rewrite.

Two new concepts:
- **`:where`** — a Scheme predicate that must return truthy for the match to continue.
- **`:then-let`** — bindings computed after the match succeeds and before any IR mutation.

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
    (%result = target.fused (%x %y) -> !result-type))
```

### What changed

**`:where`** — runs after the operands are bound. If `%x` and `%y` have different
types the predicate returns `#f` and the pattern silently skips this op.
Any Scheme expression is valid here.

**`:then-let`** — runs after the match succeeds, before any IR is modified.
Safe to read the IR (call `getType`, `getAttr`, etc.). Use it to extract
values you need in the rewrite.

`!result-type` is a naming convention (the `!` prefix) signalling a type binding.
It has no special meaning to CREST — it is just part of the Scheme identifier.

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
     [operands     (if (unbound-value? %bias)
                       (list %x %y)
                       (list %x %y %bias))])
  :rewrite %out :with
    (%result = (apply-rewrite rewriter "target.fused" operands !result-type)))
```

In practice the rewrite body is more direct — use `unbound-value?` in
`:then-let` to compute what you need, then use those values in the op-form:

```scheme
(define-rewrite-pattern (step3 op rewriter)
  :if-match
    %out = source.add (%x %y (:optional %bias))
  :then-let
    ([!result-type (mlir::Value::getType %out)]
     [has-bias?    (not (unbound-value? %bias))])
  :rewrite %out :with
    (%result = target.fused (%x %y) -> !result-type))
```

### What changed

**`(:optional %bias)`** — CREST reads `operandSegmentSizes` on the op to
determine whether the optional slot is filled. If absent, `%bias` is bound
to the absent sentinel; test it with `(unbound-value? %bias)`.

### Try it

```mlir
;; 2-operand form (bias absent)
%0 = "source.add"(%a, %b) {operandSegmentSizes = array<i32: 1, 1, 0>}
       : (i32, i32) -> i32

;; 3-operand form (bias present)
%1 = "source.add"(%a, %b, %c) {operandSegmentSizes = array<i32: 1, 1, 1>}
       : (i32, i32, i32) -> i32
```

Both match the same pattern. Without `:optional` you would need two separate
patterns — one for each arity.

---

## Next steps

- Read the [Manual](manual.md) for the complete DSL reference.
- Study `samples/passes/hip-fusion/qadd.sls` for a real 7-op fusion pattern
  that uses `:optional`, `:where`, `:then-let`, and attribute extraction.
- Study `samples/passes/onnx-to-hipsr/matmul.sls` for a dialect conversion
  pattern with nested regions.
