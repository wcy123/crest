---
theme: default
title: CREST — Conversion and Rewriting Engine for Scheme Transformations
highlighter: shiki
lineNumbers: false
fonts:
  mono: 'JetBrains Mono'
---



# CREST
## Conversion and Rewriting Engine for Scheme Transformations

Wang Chunye · AMD Research · 2026

---

## What is CREST?

**CREST** — Scheme-hosted MLIR pass framework.

You write patterns in Scheme; CREST generates the C++ `matchAndRewrite` callback.

Three macros form the public surface:

| Macro | Use case |
|---|---|
| `define-rewrite-pattern` | Greedy rewrite — fuse, fold, simplify ops |
| `define-conversion-pattern` | Dialect conversion with `TypeConverter` |
| `begin-mlir-code` | Inline op emission DSL — used inside the above |

---

## `define-rewrite-pattern`

```scheme
(define-rewrite-pattern (name matched-op rewriter)
  :if-match                           ; ── structural match on the IR
    %root = dialect.op  (%a %b)
      :where (guard? %a)              ;    arbitrary Scheme predicate
    %dep  = other.op    (%c)
      :where (another-guard? %dep)

  :then-let                           ; ── pure analysis, before any mutation
    ([!ty  (mlir::Value::getType %root)]
     [v    (analyze %dep)]
     [%aux (build-helper rewriter !ty %c)])

  :rewrite %root :with                ; ── emit new ops, replace %root
    (%result = new.op (%a %b %aux)
               ("attr" = v :f32)
               -> !ty))
```

---

## `define-conversion-pattern`

```scheme
(define-conversion-pattern (name matched-op operands-ref rewriter type-converter)
  :if-match                           ; ── same syntax as rewrite-pattern
    %root = onnx.Op (%a %b)

  :then-let                           ; ── operands already type-converted
    ([!out-ty  (mlir::Value::getType %root)]
     [!sh-ty   (mlir::shape::ShapeType::get)]
     [rank     (mlir::RankedTensorType::getRank (mlir::Value::getType %a))])

  :rewrite %root :with
    (%ph = hipsr.placeholder (%ctx %a %b)  ; ── region block inline
           (^bb0 ((%sa : !sh-ty) (%sb : !sh-ty))
                 (%bc = shape.broadcast (%sa %sb) -> !sh-ty)
                 (hipsr.shape_yield (%bc)))
           -> !out-ty)
    (%result = hipsr.op (%ctx %a %b %ph) -> !out-ty))
```

---

## `begin-mlir-code`

```scheme
;; (:rewriter rw) — use inside :rewrite :with or a helper function
(begin-mlir-code (:rewriter rw)
  (%init   = tensor.empty () -> !ty)
  (%result = hip.qadd (%ctx %a %b %init)
             ("lhs_scale"    = ls  :f32)
             ("output_scale" = os  :f32)
             ("lhs_zp"       = lzp :i64)
             -> !ty))

;; (:builder b) — inside ^bb0 region blocks
(begin-mlir-code (:builder %block-builder)
  (%c  = arith.constant () ("value" = 42 :index) -> index)
  (%e  = shape.get_extent (%shape %c) -> !size-ty)
  (%sh = shape.from_extents (%e) -> !shape-ty))

---

## Example 1 — Dialect Conversion

**`onnx.MatMul` → `hipsr.placeholder` + `hipsr.matmul`**

<div class="cols">

**Input** (`matmul.mlir`):
```mlir
func.func @matmul_2d(
    %ctx: !hipsr.context,
    %a: tensor<?x4096xf16>,
    %b: tensor<4096x1024xf16>)
    -> tensor<?x1024xf16> {

  %0 = "onnx.MatMul"(%a, %b)
      : (tensor<?x4096xf16>,
         tensor<4096x1024xf16>)
      -> tensor<?x1024xf16>
  "onnx.Return"(%0) ...
}
```

**Output** (after pass):
```mlir
func.func @matmul_2d(...) {
  %0 = "hipsr.placeholder"(%ctx,%a,%b) ({
  ^bb0(%as: !shape.shape,
       %bs: !shape.shape):
    // K equality + batch broadcast
    // shape constraints ...
    "hipsr.shape_yield"(%out_shape)
  }) -> tensor<?x1024xf16, device>

  %1 = "hipsr.matmul"(%ctx,%a,%b,%0)
      -> tensor<?x1024xf16, device>
  return %1 ...
}
```

</div>

---

## The Scheme pattern (conversion)

```scheme
(define-conversion-pattern (onnx-matmul->hipsr op operands-ref rewriter type-converter)
  :if-match
    %output = onnx.MatMul (%a %b)          ; match by op name, bind result + operands

  :then-let
    ([%ctx          (mlir-get-hipsr-context-arg op)]
     [!output-type  (mlir::Value::getType %output)]
     [!shape-type   (mlir::shape::ShapeType::get)]
     [a-rank        (mlir::RankedTensorType::getRank (mlir::Value::getType %a))]
     [k-a-idx       (- a-rank 1)]          ; K dim index — pure Scheme arithmetic
     ...)

  :rewrite %output :with
    (%placeholder = hipsr.placeholder (%ctx %a %b !output-type)
      (^bb0 ((%a-shape : !shape-type) (%b-shape : !shape-type))
            (%ck  = shape.const_size () (value = k-a-idx :index) -> !size-type)
            (%ek  = shape.get_extent (%a-shape %ck) -> !size-type)
            ...                            ; shape constraints in a region block
            (hipsr.shape_yield (%out)))
      -> !output-type)
    (%result = hipsr.matmul (%ctx %a %b %placeholder) -> !output-type))
```

---

## Example 2 — Fusion Rewrite

**`DQ + DQ → add → Q` ⟹ `qadd`** (quantized element-wise add)

```
  Before fusion                          After fusion

  %a:i8 ──► [dequantize] ──┐
                            ├──► [add] ──► [quantize] ──► %q:i8
  %b:i8 ──► [dequantize] ──┘

                               ═══════════════════════

                                         %a:i8 ──┐
                                                  ├──► [qadd] ──► %q:i8
                                         %b:i8 ──┘
                                         (scales/zp as attributes)
```

Four ops collapse to one. Scales and zero-points move from operands to attributes.

---

## Input MLIR (qadd)

```mlir
func.func @qadd(%ctx: !hip.context, %lhs: tensor<1x128x32xi8>, %rhs: tensor<1x128x32xi8>)
               -> tensor<1x128x32xi8> {
  %lhs_scale = "hip.constant"() {value = dense<0.25> : tensor<f32>} : () -> tensor<f32>
  %lhs_zp    = "hip.constant"() {value = dense<-5>   : tensor<i8>}  : () -> tensor<i8>
  %rhs_scale = "hip.constant"() {value = dense<0.5>  : tensor<f32>} : () -> tensor<f32>
  %rhs_zp    = "hip.constant"() {value = dense<3>    : tensor<i8>}  : () -> tensor<i8>
  %out_scale = "hip.constant"() {value = dense<0.125>: tensor<f32>} : () -> tensor<f32>
  %out_zp    = "hip.constant"() {value = dense<7>    : tensor<i8>}  : () -> tensor<i8>

  %dq_lhs = "hip.dequantize_linear"(%ctx, %lhs, %lhs_scale, %lhs_zp, ...) -> tensor<...xf32>
  %dq_rhs = "hip.dequantize_linear"(%ctx, %rhs, %rhs_scale, %rhs_zp, ...) -> tensor<...xf32>
  %sum    = "hip.add"(%ctx, %dq_lhs, %dq_rhs, ...)                         -> tensor<...xf32>
  %q      = "hip.quantize_linear"(%ctx, %sum, %out_scale, %out_zp, ...)    -> tensor<...xi8>
  return %q ...
}
```

---

## The Scheme pattern (rewrite)

```scheme
(define-rewrite-pattern (hip-qadd-fusion op rewriter)
  :if-match
    %lhs_scale = hip.constant          ()  :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %dq_lhs    = hip.dequantize_linear (%ctx %lhs %lhs_scale (:optional %lhs_zp) %dq_lhs_init)
    %rhs_scale = hip.constant          ()  :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %dq_rhs    = hip.dequantize_linear (%ctx %rhs %rhs_scale (:optional %rhs_zp) %dq_rhs_init)
    %out_scale = hip.constant          ()  :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %sum       = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)  :where (single-consumer? %sum)
    %q         = hip.quantize_linear   (%ctx %sum %out_scale (:optional %out_zp) %q_init)
  :then-let
    ([!out-type  (mlir::Value::getType %q)]
     [lhs-scale  (scale-attr %lhs_scale)]   ; extract splat float → FloatAttr
     [lhs-zp     (zp-attr %lhs_zp)]         ; present → IntegerAttr; absent → 0
     [rhs-scale  (scale-attr %rhs_scale)]   [rhs-zp  (zp-attr %rhs_zp)]
     [out-scale  (scale-attr %out_scale)]   [out-zp  (zp-attr %out_zp)]
     [%init      (hip-build-init rewriter !out-type %sum_init)])
  :rewrite %q :with
    (%result = hip.qadd (%ctx %lhs %rhs %init)
              ("lhs_scale" = lhs-scale) ("lhs_zp" = lhs-zp)
              ("rhs_scale" = rhs-scale) ("rhs_zp" = rhs-zp)
              ("output_scale" = out-scale) ("output_zp" = out-zp)
              -> !out-type))
```

---

## Output MLIR (qadd)

```mlir
func.func @qadd(%ctx: !hip.context, %lhs: tensor<1x128x32xi8>, %rhs: tensor<1x128x32xi8>)
               -> tensor<1x128x32xi8> {
  %init   = tensor.empty() : tensor<1x128x32xi8>
  %result = "hip.qadd"(%ctx, %lhs, %rhs, %init) {
              lhs_scale    = 2.500000e-01 : f32,
              lhs_zp       = -5 : i64,
              rhs_scale    = 5.000000e-01 : f32,
              rhs_zp       = 3 : i64,
              output_scale = 1.250000e-01 : f32,
              output_zp    = 7 : i64
            } -> tensor<1x128x32xi8>
  return %result : tensor<1x128x32xi8>
}
```

6 ops → 2 ops. Scales and zero-points are now **attributes**, not operands.

---

## Debug info — for free

Every op emitted by `begin-mlir-code` carries `mlir::FileLineColLoc` from the **Scheme source**:

```
$ crest-opt --mlir-print-debuginfo input.mlir

%0 = "hipsr.placeholder"(...)  loc("min.sls":54:23)
%1 = shape.broadcast %a, %b   loc("min.sls":56:41)
%2 = "hipsr.min"(...)          loc("min.sls":59:18)
```

- Derived from the syntax annotation of `#'op-name` at **macro expand time**
- No `UnknownLoc` — diagnostics point to the exact `.sls` line
- Zero effort: automatic, not opt-in

---

## Getting started

```scheme
(import (crest))               ; define-rewrite-pattern, define-conversion-pattern,
                               ; begin-mlir-code, :if-match, :then-let, :rewrite ...
(import (mlir IR Value))       ; mlir::Value::getType, getDefiningOp, ...
(import (mlir IR Operation))   ; mlir::Operation::getAttr, getLoc, ...
```

Register and run:

```scheme
(add-rewrite-pattern    patterns hip-qadd-fusion  10) ; benefit = 10
(add-conversion-pattern patterns "onnx.MatMul" onnx-matmul->hipsr type-converter 1)
```

```sh
crest-opt --crest-pass="module=passes/hip-fusion" input.mlir
```

Full API docs: `scheme/crest.sls`  ·  Samples: `samples/passes/`

---

# Thank you

**CREST DDR** — structural matching, pure-Scheme analysis, automatic source locations.

```scheme
(define-rewrite-pattern (my-fusion op rewriter)
  :if-match  %root = my.expensive_op (%a %b) :where (fusable? %a %b)
  :then-let  ([!ty (mlir::Value::getType %root)])
  :rewrite   %root :with
    (%r = my.fused_op (%a %b) ("attr" = (compute %a %b) :f32) -> !ty))
```
