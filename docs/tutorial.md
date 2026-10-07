<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

---
marp: true
theme: default
paginate: true
style: |
  section { font-size: 1.1em; }
  pre { font-size: 0.72em; }
  code { font-size: 0.8em; }
  h1 { color: #c00; }
  h2 { color: #333; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 1em; }
---

# CREST: MLIR Rewrite Passes in Scheme

**Writing dialect fusion patterns without the boilerplate**

Wang Chunye · AMD Research · 2026

---

## The problem with C++ rewrite patterns

A simple quantization fusion in C++:

```cpp
struct QMulFusion : OpRewritePattern<QuantizeLinearOp> {
  LogicalResult matchAndRewrite(QuantizeLinearOp op,
                                PatternRewriter &rw) const override {
    auto mul = op.getInput().getDefiningOp<MulOp>();
    if (!mul || !mul->hasOneUse()) return failure();
    auto dqL = mul.getLhs().getDefiningOp<DequantizeLinearOp>();
    auto dqR = mul.getRhs().getDefiningOp<DequantizeLinearOp>();
    if (!dqL || !dqR) return failure();
    // ... 40 more lines of attribute extraction + op creation ...
  }
};
```

**Every pattern**: boilerplate match → boilerplate attribute extraction → boilerplate OperationState → missing source locs in emitted ops.

---

## CREST in 30 seconds

The **same** pattern in CREST DDR:

```scheme
(define-rewrite-pattern (hip-qmul-fusion op rewriter)
  :if-match
    %q    = hip.quantize_linear (%ctx %prod %out_scale)
      :where (hip-splat-scale? %out_scale)
    %prod = hip.mul (%ctx %dq_lhs %dq_rhs %init)
      :where (hip-value-single-use? %prod)
    %dq_lhs = hip.dequantize_linear (%ctx %lhs %lhs_scale)
    %dq_rhs = hip.dequantize_linear (%ctx %rhs %rhs_scale)
  :then-let
    ([!out-type (mlir::Value::getType %q)]
     [lhs-scale (hip-extract-splat-scale %lhs_scale)]
     [rhs-scale (hip-extract-splat-scale %rhs_scale)])
  :rewrite %q :with
    (%result = hip.qmul (%ctx %lhs %rhs %init)
      ("lhs_scale" = lhs-scale :f32)
      ("rhs_scale" = rhs-scale :f32)
      -> !out-type))
```

Pattern matching, analysis, and emission — **one cohesive form**.

---

## Structure of a DDR pattern

```scheme
(define-rewrite-pattern (pattern-name matched-op rewriter)
  ;;  ① Structural match — traverse def-use, bind SSA values
  :if-match
    %root = dialect.op (...) :where guard?
    %dep  = other.op  (...) :where another-guard?

  ;;  ② Analysis — pure Scheme, runs before any IR mutation
  :then-let
    ([!type  (extract-type %root)]
     [scale  (compute-scale %dep)])

  ;;  ③ Emission — replace %root with the new ops
  :rewrite %root :with
    (%new = dialect.new_op (...) ("attr" = scale :f32) -> !type))
```

Three phases: **match** → **analyze** → **rewrite**.

---

## `:if-match` — structural matching

```scheme
:if-match
  %q   = hip.quantize_linear (%ctx %x %scale)
  %x   = hip.add             (%ctx %a %b %init)
```

- `%q = dialect.op (...)` — match an op by name; bind its **result Value** to `%q`
- Operand positions `(%ctx %x %scale)` — each operand must be an SSA value
- **Implicit def-use traversal**: `%x` appears as an operand of `%q`, so CREST walks back to the defining op automatically
- Order is **root first** — match the op you want to replace, then trace its inputs

<!--
The match is structural — it walks the def-use graph. You write the match in "output order", letting CREST figure out which defining op to look at.
-->

---

## `:where` guards

```scheme
:if-match
  %q = hip.quantize_linear (%ctx %sum %scale)
    :where (and (hip-splat-scale? %scale)
                (hip-extractable-qdq-zeropoint? op))
  %sum = hip.add (%ctx %a %b %init)
    :where (hip-value-single-use? %sum)
```

- `:where expr` is **arbitrary Scheme** — any predicate over the matched values
- `op` refers to the **root** matched op (the argument to `matchAndRewrite`)
- Guard failure → `failure()` — the pattern is skipped cleanly
- Predicates are normal Scheme functions; test them independently

---

## `:then-let` — analysis phase

```scheme
:then-let
  ([!out-type   (mlir::Value::getType %q)]
   [%dq-lhs-op (mlir::Value::getDefiningOp %dq_lhs)]
   [lhs-scale  (hip-extract-splat-scale %lhs_scale)]
   [lhs-zp     (hip-extract-qdq-zeropoint-i64 %dq-lhs-op 0)]
   [%init      (hip-build-init rewriter !out-type %prod_init)])
```

- Evaluates **before** any IR mutation — safe to read the IR freely
- Variables prefixed `!` are **types** (filtered from value operand lists later)
- Variables prefixed `%` are **MLIR values/ops** (uptrs)
- Can call any Scheme function — complex analysis, constant folding, shape inference
- `rewriter` and `matched-op` are in scope here

---

## `:rewrite :with` + `begin-mlir-code`

```scheme
:rewrite %q :with
  (%result = hip.qmul (%ctx %lhs %rhs %init)
    ("lhs_scale"    = lhs-scale :f32)
    ("rhs_scale"    = rhs-scale :f32)
    ("output_scale" = out-scale :f32)
    ("lhs_zp"       = lhs-zp   :i64)
    ("output_zp"    = out-zp   :i64)
    -> !out-type)
```

- `:rewrite %root :with body ...` — replace `%root`'s uses with the last result
- `begin-mlir-code (:rewriter rewriter)` is implicit inside `:rewrite :with`
- Ops are emitted **before** the matched root op; the root is erased automatically
- The last bound result replaces `%root`

---

## Inline attribute modifiers

No more `OperationState` + `setAttr!` dance:

| Modifier | MLIR type | Example |
|---|---|---|
| `:f32` | `FloatAttr` (f32) | `("scale" = 0.5 :f32)` |
| `:i64` | `IntegerAttr` (i64) | `("axis" = 1 :i64)` |
| `:index` | `IntegerAttr` (index) | `("n" = 8 :index)` |
| `:i32-array` | `DenseI32ArrayAttr` | `("pads" = '(0 0) :i32-array)` |
| `:i64-array` | `DenseI64ArrayAttr` | `("shape" = '(1 8) :i64-array)` |
| `:unit` | `UnitAttr` (flag) | `("packed_int4" = #t :unit)` |
| *(none)* | pre-built `Attribute*` | `("val" = my-attr-uptr)` |

Values are **runtime Scheme expressions** — compute them in `:then-let`.

---

## Regions and `^bb0`

```scheme
(%ph = hipsr.placeholder (%ctx %lhs %rhs)
  (^bb0 ((%ls : !shape-type) (%rs : !shape-type))
        (%bc = shape.broadcast (%ls %rs) -> !shape-type)
        (hipsr.shape_yield (%bc)))
  -> out-type)
```

- `(^bb0 ((arg : !type) ...) body ...)` — inline block inside a region
- `%arg` variables are bound to `Block::getArgument` values
- Body ops are emitted with an `OpBuilder` positioned at the block end
- `(:builder %block-builder)` is the explicit builder inside `^bb0`
- Multiple blocks: use `:region (^bb0 ...) (^bb1 ...)` full form

---

## Source locations — for free

Every op emitted by `begin-mlir-code` carries `mlir::FileLineColLoc` from the **Scheme source**:

```
$ crest-opt --mlir-print-debuginfo input.mlir

%0 = "hipsr.placeholder"(...) loc("min.sls":54:23)
%1 = shape.broadcast %a, %b   loc("min.sls":56:41)
%2 = "hipsr.min"(...)          loc("min.sls":59:18)
```

- Location derived from `#'op-name` syntax annotation at **macro expand time**
- No `UnknownLoc` — diagnostics point to the exact Scheme line
- MLIR error messages, `--mlir-print-ir-after-all`, crash traces all resolve correctly
- Zero effort: source locs are attached automatically, not opt-in

---

## `define-conversion-pattern`

Same structure, but for **dialect conversion** (with `TypeConverter`):

```scheme
(define-conversion-pattern (onnx-return->func-return op rewriter)
  :if-match
    %out = onnx.Return (%inputs...)
  :then-let
    ([operands (collect-converted-operands operands-ref)])
  :rewrite %out :with
    (func.return (,@operands)))
```

- Generated callback signature: `(fn op operands-ref rewriter type-converter)`
- Operands in `:then-let` are **already type-converted** by the framework
- Register with `add-conversion-pattern`
- Otherwise identical to `define-rewrite-pattern`

---

## Helper functions

Extract complex logic into plain Scheme:

```scheme
;; In fusion.sls — called from :then-let
(define (hip-extract-splat-scale val)
  (mlir::DenseElementsAttr::getSplatValue<APFloat>
   (mlir::Operation::getAttr
    (mlir::Value::getDefiningOp val) "value")))

;; In :then-let:
:then-let
  ([lhs-scale (hip-extract-splat-scale %lhs_scale)]
   [rhs-scale (hip-extract-splat-scale %rhs_scale)])
```

- Helpers are just Scheme `define`s — unit-testable, reusable across patterns
- Can import any Scheme library — arithmetic, list processing, string ops
- MLIR bindings (`mlir::Operation::...`, `mlir::Value::...`) are direct FFI calls

---

## `begin-mlir-code` standalone

Call it from helper functions or outside a DDR pattern:

```scheme
;; Build a tensor.empty anchored at loc-op's source location
(define (hip-build-init rewriter out-type shape-source)
  (let ([loc-op (mlir::Value::getDefiningOp shape-source)])
    (mlir::RewriterBase::setInsertionPoint rewriter loc-op)
    (begin-mlir-code (:rewriter rewriter)
      (%init = tensor.empty () -> out-type))))

;; Inside a ^bb0 block — use the block's builder
(begin-mlir-code (:builder %block-builder)
  (%c = arith.constant () ("value" = 0 :i64) -> i64)
  (%r = tensor.insert (%val %acc %c) -> out-type))
```

- `(:rewriter rw)` — use a `RewriterBase*`; insertion point must be set beforehand
- `(:builder b)` — use a plain `OpBuilder*`; typically `%block-builder` inside `^bb0`

---

## Complete walkthrough: `hip-qmul-fusion`

**Input IR** (three ops to fuse):
```mlir
%dq_a = hip.dequantize_linear(%ctx, %a, %a_scale)
%dq_b = hip.dequantize_linear(%ctx, %b, %b_scale)
%mul  = hip.mul(%ctx, %dq_a, %dq_b, %init)
%q    = hip.quantize_linear(%ctx, %mul, %out_scale)
```

**Output IR** (one fused op):
```mlir
%result = hip.qmul(%ctx, %a, %b, %init)
  {lhs_scale = ..., rhs_scale = ..., output_scale = ...}
```

CREST matches root `%q`, walks back through `%mul`, `%dq_a`, `%dq_b`, extracts splat scales in `:then-let`, emits `hip.qmul` with inline attribute modifiers.

<!--
Walk through the pattern step by step: match, guard check, then-let analysis, rewrite emission. Each phase is isolated — the analysis cannot accidentally mutate the IR.
-->

---

## Honest limitations

CREST DDR today does **not** support:

- **Multi-value root replacement** — `:rewrite %root :with` replaces a single SSA value. Replacing an op with multiple results requires calling `replaceOp` manually.
- **Erase without replace** — use `mlir::RewriterBase::eraseOp` explicitly after the pattern body.
- **Cross-block patterns** — `:if-match` traverses only the def-use graph within a single block.
- **Op with multiple successors** — `:rewrite` inserts before the root op; branch ops need manual handling.

These are engineering gaps, not fundamental limits. Contributions welcome.

---

## Getting started

```scheme
(import (crest))                    ; define-rewrite-pattern, begin-mlir-code, ...
(import (mlir IR PatternMatch))     ; mlir::RewriterBase::replaceOp, mlir-create-operation
(import (mlir IR Value))            ; mlir::Value::getType, getDefiningOp, ...
(import (mlir IR Operation))        ; mlir::Operation::getAttr, getLoc, ...
```

Register your pattern:

```scheme
;; Greedy rewrite
(add-rewrite-pattern patterns my-fusion-pattern 10) ; benefit = 10

;; Dialect conversion
(add-conversion-pattern patterns "onnx.Op" my-conversion type-converter 1)
```

Run via `--crest-pass="module=passes/my-pass"` — the pass loader finds your `.sls` by module name.

---

## Summary

| | C++ ODS pattern | CREST DDR |
|---|---|---|
| Match boilerplate | `getDefiningOp<T>()` chains | `:if-match` DSL |
| Guard logic | `if (!...) return failure()` | `:where` predicate |
| Analysis | inline, mixes with mutation | `:then-let` (pure, isolated) |
| Op emission | `OperationState` + `setAttr` | `begin-mlir-code` + modifiers |
| Source locs | manual `getLoc(op)` | **automatic** from Scheme source |
| Helpers | C++ member functions | plain Scheme `define` |

**CREST patterns are shorter, testable in isolation, and ship source locs for free.**

---

# Thank you

```scheme
(import (crest))

(define-rewrite-pattern (hello-world op rewriter)
  :if-match
    %y = my.expensive_op (%x)
      :where (is-constant? %x)
  :then-let ([val (fold-constant %x)])
  :rewrite %y :with
    (%result = arith.constant () ("value" = val :i64) -> i64))
```

Repo: `scheme/crest.sls` — public API and full documentation
Samples: `samples/passes/hip-fusion/` · `samples/passes/onnx-to-hipsr/`
