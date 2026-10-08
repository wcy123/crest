# CREST — Conversion and Rewriting Engine for Scheme Transformations

[![CI](https://github.com/wcy123/crest/actions/workflows/ci.yml/badge.svg)](https://github.com/wcy123/crest/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

CREST is a homoiconic pattern DSL for MLIR built on [Chez Scheme](https://cisco.github.io/ChezScheme/).
Patterns are Scheme macros — guards and analysis are plain Scheme functions, no C++ required.
Edit a `.sls` pattern file and re-run: no rebuild, no relink, changes take effect immediately.

> **Status:** Used in production at AMD for quantization and dialect conversion passes targeting ROCm/HIP backends.

Three macros form the public surface:

| Macro | Use case |
|---|---|
| `define-rewrite-pattern` | Greedy rewrite — fuse, fold, simplify ops |
| `define-conversion-pattern` | Dialect conversion with `TypeConverter` |
| `begin-mlir-code` | Inline op emission DSL — used inside the above |

**[Getting started →](docs/getting-started.md)** — build instructions, prerequisites, deployment.

---

## Why not PDL / DRR / C++?

[PDL](https://mlir.llvm.org/docs/PDLL/) and [DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/)
generate only `RewritePattern` subclasses. Neither supports
[`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns),
`TypeConverter`, or `applyFullConversion` — the machinery required for dialect
conversion passes. **CREST is the only DSL-based option that covers dialect conversion.**

| | DRR | PDLL | CREST |
|---|---|---|---|
| `ConversionPattern` support | No | No | **Yes** |
| Edit → test cycle | full rebuild | full rebuild | **reload `.sls`** |
| Match constraints without C++ | No | No | **Yes** (plain Scheme) |
| Optional / variadic operands | No | Limited | **Yes** |
| Emitted op → pattern file:line | No | No | **Yes** |

For patterns DRR and PDLL cannot express, the only fallback is C++ boilerplate.
A quantization fusion in C++:

```cpp
struct QAddFusion : OpRewritePattern<QuantizeLinearOp> {
  LogicalResult matchAndRewrite(QuantizeLinearOp op,
                                PatternRewriter &rw) const override {
    auto add = op.getInput().getDefiningOp<AddOp>();
    if (!add || !add->hasOneUse()) return failure();
    auto dqL = add.getLhs().getDefiningOp<DequantizeLinearOp>();
    auto dqR = add.getRhs().getDefiningOp<DequantizeLinearOp>();
    if (!dqL || !dqR) return failure();
    if (!isSplatConstant(dqL.getScale())) return failure();
    if (!isSplatConstant(dqR.getScale())) return failure();
    // ... extract float values, build OperationState, setAttr × 6, ...
    // ~60 more lines, plus a rebuild cycle on every change
  }
};
```

The same pattern in CREST — match, analysis, and emission in one form, no rebuild needed:

```lisp
(define-rewrite-pattern (hip-qadd-fusion op rewriter)
  :if-match
    %dq_lhs = hip.dequantize_linear (%ctx %lhs %lhs_scale (:optional %lhs_zp) %dq_lhs_init)
    %dq_rhs = hip.dequantize_linear (%ctx %rhs %rhs_scale (:optional %rhs_zp) %dq_rhs_init)
    %sum    = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)  :where (single-consumer? %sum)
    %q      = hip.quantize_linear   (%ctx %sum %out_scale (:optional %out_zp) %q_init)
  :then-let
    ([lhs-scale (scale-attr %lhs_scale)]  [lhs-zp (zp-attr %lhs_zp)]
     [rhs-scale (scale-attr %rhs_scale)]  [rhs-zp (zp-attr %rhs_zp)]
     [out-scale (scale-attr %out_scale)]  [out-zp (zp-attr %out_zp)] ...)
  :rewrite %q :with
    (%result = hip.qadd (%ctx %lhs %rhs %q_init)
              ("lhs_scale" = lhs-scale) ("lhs_zp" = lhs-zp)
              ("output_scale" = out-scale) ("output_zp" = out-zp)
              -> !out-type))
```

---

## Example 1 — Fusion rewrite: `DQ + DQ + add + Q` → `qadd`

**Command**

```bash
CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="module=passes/hip-fusion" \
  --split-input-file test/hip-fusion/qadd.mlir
```

```
  Before                                 After

  %a:i8 ──► [dequantize] ──┐
                            ├──► [add] ──► [quantize] ──► %q:i8
  %b:i8 ──► [dequantize] ──┘
                                                ↓
                                         %a:i8 ──┐
                                                  ├──► [qadd] ──► %q:i8
                                         %b:i8 ──┘
                                         (scales/zp as attributes)
```

**Input [`test/hip-fusion/qadd.mlir`](test/hip-fusion/qadd.mlir):**

```text
%lhs_scale = "hip.constant"() {value = dense<0.25> : tensor<f32>} : () -> tensor<f32>
%lhs_zp    = "hip.constant"() {value = dense<-5>   : tensor<i8>}  : () -> tensor<i8>
%rhs_scale = "hip.constant"() {value = dense<0.5>  : tensor<f32>} : () -> tensor<f32>
%rhs_zp    = "hip.constant"() {value = dense<3>    : tensor<i8>}  : () -> tensor<i8>
%out_scale = "hip.constant"() {value = dense<0.125>: tensor<f32>} : () -> tensor<f32>
%out_zp    = "hip.constant"() {value = dense<7>    : tensor<i8>}  : () -> tensor<i8>
%dq_lhs = "hip.dequantize_linear"(%ctx, %lhs, %lhs_scale, %lhs_zp, %e0) -> tensor<1x128x32xf32>
%dq_rhs = "hip.dequantize_linear"(%ctx, %rhs, %rhs_scale, %rhs_zp, %e1) -> tensor<1x128x32xf32>
%sum    = "hip.add"(%ctx, %dq_lhs, %dq_rhs, %e2)                         -> tensor<1x128x32xf32>
%q      = "hip.quantize_linear"(%ctx, %sum, %out_scale, %out_zp, %e3)    -> tensor<1x128x32xi8>
```

**The Scheme pattern: [`samples/passes/hip-fusion/qadd.sls`](samples/passes/hip-fusion/qadd.sls)**

```lisp
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
    ([!out-type (mlir::Value::getType %q)]
     [lhs-scale (scale-attr %lhs_scale)]  [lhs-zp (zp-attr %lhs_zp)]
     [rhs-scale (scale-attr %rhs_scale)]  [rhs-zp (zp-attr %rhs_zp)]
     [out-scale (scale-attr %out_scale)]  [out-zp (zp-attr %out_zp)]
     [%init     (hip-build-init rewriter !out-type %sum_init)])
  :rewrite %q :with
    (%result = hip.qadd (%ctx %lhs %rhs %init)
              ("lhs_scale" = lhs-scale) ("lhs_zp" = lhs-zp)
              ("rhs_scale" = rhs-scale) ("rhs_zp" = rhs-zp)
              ("output_scale" = out-scale) ("output_zp" = out-zp)
              -> !out-type))
```

`:if-match` traverses the def-use graph structurally. `:where` guards are plain Scheme predicates.
`(:optional %lhs_zp)` handles both 4-operand and 5-operand DQ forms without a separate pattern.

**Output [`docs/examples/qadd-output.mlir`](docs/examples/qadd-output.mlir):**

The greedy rewriter does not DCE unregistered-dialect ops, so the original dead
ops remain in the output — a subsequent DCE pass removes them. The fused result:

```text
    %12 = tensor.empty() : tensor<1x128x32xi8>
    %13 = "hip.qadd"(%arg0, %arg1, %arg2, %12) {
            lhs_scale = 2.500000e-01 : f32, lhs_zp = -5 : i64,
            rhs_scale = 5.000000e-01 : f32, rhs_zp = 3 : i64,
            output_scale = 1.250000e-01 : f32, output_zp = 7 : i64
          } : (!hip.context, tensor<1x128x32xi8>, tensor<1x128x32xi8>, tensor<1x128x32xi8>)
            -> tensor<1x128x32xi8>
    return %13 : tensor<1x128x32xi8>
```

---

## Example 2 — Dialect conversion: `onnx.MatMul` → `hipsr.matmul`

**Command**

```bash
CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="module=passes/onnx-to-hipsr" \
  --split-input-file test/onnx-to-hipsr/matmul.mlir
```

**Input [`test/onnx-to-hipsr/matmul.mlir`](test/onnx-to-hipsr/matmul.mlir):**

```text
func.func @matmul(%ctx: !hipsr.context, %a: tensor<?x4096xf16>, %b: tensor<4096x1024xf16>)
                 -> tensor<?x1024xf16> {
  %0 = "onnx.MatMul"(%a, %b) : (tensor<?x4096xf16>, tensor<4096x1024xf16>) -> tensor<?x1024xf16>
  "onnx.Return"(%0) : (tensor<?x1024xf16>) -> ()
}
```

**The Scheme pattern: [`samples/passes/onnx-to-hipsr/matmul.sls`](samples/passes/onnx-to-hipsr/matmul.sls)**

The full pattern is in the linked file. Key structure:

```lisp
(define-conversion-pattern (onnx-matmul->hipsr op operands-ref rewriter type-converter)
  :if-match
    %output = onnx.MatMul (%a %b)
  :then-let
    ([%ctx         (mlir-get-hipsr-context-arg op)]
     [!output-type (mlir::Value::getType %output)]
     [!shape-type  (mlir::shape::ShapeType::get)]
     [a-rank       (mlir::RankedTensorType::getRank (mlir::Value::getType %a))]
     [k-a-idx      (- a-rank 1)])         ; K dim index — pure Scheme arithmetic
  :rewrite %output :with
    (%placeholder = hipsr.placeholder (%ctx %a %b !output-type)
      (^bb0 ((%a-shape : !shape-type) (%b-shape : !shape-type))
            ; K-equality + batch-broadcast shape constraints (~30 ops, see .sls)
            (hipsr.shape_yield (%out)))
      -> !output-type)
    (%result = hipsr.matmul (%ctx %a %b %placeholder) -> !output-type))
```

`:then-let` runs after the match and before any IR mutation — safe to read the IR freely.
`k-a-idx` is plain Scheme arithmetic; no C++ helper needed.

**Output [`docs/examples/matmul-output.mlir`](docs/examples/matmul-output.mlir)** (abbreviated):

```text
func.func @matmul(%ctx: !hipsr.context, %a: tensor<?x4096xf16>, %b: tensor<4096x1024xf16>)
                 -> tensor<?x1024xf16, #hipsr.mem<device>> {
  %0 = "hipsr.placeholder"(%ctx, %a, %b) ({
  ^bb0(%sa: !shape.shape, %sb: !shape.shape):
    ; K equality + batch broadcast shape constraints (~30 ops)
    "hipsr.shape_yield"(%result_shape) : (!shape.shape) -> ()
  }) : (...) -> tensor<?x1024xf16, #hipsr.mem<device>>
  %1 = "hipsr.matmul"(%ctx, %a, %b, %0) : (...) -> tensor<?x1024xf16, #hipsr.mem<device>>
  return %1 : tensor<?x1024xf16, #hipsr.mem<device>>
}
```

---

## Debug info — for free

Every op emitted by `begin-mlir-code` carries `mlir::FileLineColLoc` from the
Scheme source — no `UnknownLoc`, no manual `getLoc` threading:

```bash
CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="module=passes/onnx-to-hipsr" \
  --split-input-file --mlir-print-debuginfo \
  test/onnx-to-hipsr/min.mlir
```

```text
%0 = "hipsr.placeholder"(...)  loc("samples/passes/onnx-to-hipsr/min.sls":54:23)
%1 = shape.broadcast %a, %b   loc("samples/passes/onnx-to-hipsr/min.sls":56:41)
%2 = "hipsr.min"(...)          loc("samples/passes/onnx-to-hipsr/min.sls":59:18)
```

Locations are derived from the syntax annotation of `#'op-name` at macro expand time.
MLIR error messages, `--mlir-print-ir-after-all`, and crash traces resolve to the
exact `.sls` line — no extra work required.

---

## Architecture

```
samples/passes/      — example passes (hip-fusion, onnx-to-hipsr)
scheme/              — core Scheme libraries (mlir IR/dialects/support)
lib/Interpreter/     — Chez Scheme runtime wrapper
lib/Bindings/        — MLIR → Scheme FFI
lib/Passes/          — --crest-pass pipeline registration
tools/crest-opt/     — mlir-opt-style driver
```

See [docs/architecture.md](docs/architecture.md) for the full design.

## License

MIT — see [LICENSE](LICENSE).
