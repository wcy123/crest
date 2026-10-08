# CREST — Conversion and Rewriting Engine for Scheme Transformations

CREST is a homoiconic pattern DSL for MLIR — patterns are Scheme macros, so
constraints and rewrite logic are plain Scheme functions with no C++ escapes
and a seconds-level edit-reload cycle. Unlike [PDL](https://mlir.llvm.org/docs/PDLL/)
and [DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/), CREST generates
both `RewritePattern` and `ConversionPattern` subclasses, covering dialect
conversion passes that neither DSL supports.

Three macros form the public surface:

| Macro | Use case |
|---|---|
| `define-rewrite-pattern` | Greedy rewrite — fuse, fold, simplify ops |
| `define-conversion-pattern` | Dialect conversion with `TypeConverter` |
| `begin-mlir-code` | Inline op emission DSL — used inside the above |

→ **[Getting started](docs/getting-started.md)** — build instructions, prerequisites, deployment.

---

## Example 1 — Dialect conversion: `onnx.MatMul` → `hipsr.matmul`

**Input:**
```mlir
func.func @matmul(%ctx: !hipsr.context, %a: tensor<?x4096xf16>, %b: tensor<4096x1024xf16>)
                 -> tensor<?x1024xf16> {
  %0 = "onnx.MatMul"(%a, %b) : (tensor<?x4096xf16>, tensor<4096x1024xf16>) -> tensor<?x1024xf16>
  "onnx.Return"(%0) : (tensor<?x1024xf16>) -> ()
}
```

**Output** (after `--crest-pass="module=passes/onnx-to-hipsr"`):
```mlir
func.func @matmul(%ctx: !hipsr.context, %a: tensor<?x4096xf16>, %b: tensor<4096x1024xf16>)
                 -> tensor<?x1024xf16, #hipsr.mem<device>> {
  %0 = "hipsr.placeholder"(%ctx, %a, %b) ({
  ^bb0(%sa: !shape.shape, %sb: !shape.shape):
    // K equality check + batch broadcast constraints ...
    "hipsr.shape_yield"(%out_shape) : (!shape.shape) -> ()
  }) : (...) -> tensor<?x1024xf16, #hipsr.mem<device>>
  %1 = "hipsr.matmul"(%ctx, %a, %b, %0) : (...) -> tensor<?x1024xf16, #hipsr.mem<device>>
  return %1 ...
}
```

**The Scheme pattern:**
```scheme
(define-conversion-pattern (onnx-matmul->hipsr op operands-ref rewriter type-converter)
  :if-match
    %output = onnx.MatMul (%a %b)

  :then-let
    ([%ctx         (mlir-get-hipsr-context-arg op)]
     [!output-type (mlir::Value::getType %output)]
     [!shape-type  (mlir::shape::ShapeType::get)]
     [a-rank       (mlir::RankedTensorType::getRank (mlir::Value::getType %a))]
     [k-a-idx      (- a-rank 1)]          ; K dim index — pure Scheme arithmetic
     ...)

  :rewrite %output :with
    (%placeholder = hipsr.placeholder (%ctx %a %b !output-type)
      (^bb0 ((%a-shape : !shape-type) (%b-shape : !shape-type))
            (%ck = shape.const_size () (value = k-a-idx :index) -> !size-type)
            (%ek = shape.get_extent (%a-shape %ck) -> !size-type)
            ...
            (hipsr.shape_yield (%out)))
      -> !output-type)
    (%result = hipsr.matmul (%ctx %a %b %placeholder) -> !output-type))
```

`:then-let` runs after the match and before any IR mutation — pure Scheme,
safe to read the IR freely. `k-a-idx` is computed with plain arithmetic; no
C++ helper needed.

---

## Example 2 — Fusion rewrite: `DQ + DQ + add + Q` → `qadd`

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

Four ops collapse to one. Scales and zero-points move from operands to attributes.

**Input:**
```mlir
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
```

**The Scheme pattern:**
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
    ([!out-type (mlir::Value::getType %q)]
     [lhs-scale (scale-attr %lhs_scale)]   ; extract splat float → FloatAttr
     [lhs-zp    (zp-attr %lhs_zp)]         ; present → IntegerAttr; absent → 0
     [rhs-scale (scale-attr %rhs_scale)]   [rhs-zp  (zp-attr %rhs_zp)]
     [out-scale (scale-attr %out_scale)]   [out-zp  (zp-attr %out_zp)]
     [%init     (hip-build-init rewriter !out-type %sum_init)])
  :rewrite %q :with
    (%result = hip.qadd (%ctx %lhs %rhs %init)
              ("lhs_scale" = lhs-scale) ("lhs_zp" = lhs-zp)
              ("rhs_scale" = rhs-scale) ("rhs_zp" = rhs-zp)
              ("output_scale" = out-scale) ("output_zp" = out-zp)
              -> !out-type))
```

**Output:**
```mlir
%init   = tensor.empty() : tensor<1x128x32xi8>
%result = "hip.qadd"(%ctx, %lhs, %rhs, %init) {
            lhs_scale = 2.500000e-01 : f32, lhs_zp = -5 : i64,
            rhs_scale = 5.000000e-01 : f32, rhs_zp = 3 : i64,
            output_scale = 1.250000e-01 : f32, output_zp = 7 : i64
          } -> tensor<1x128x32xi8>
```

`:if-match` traverses the def-use graph structurally — match root `%q`, walk
back through `%sum`, `%dq_lhs`, `%dq_rhs`, and the scale constants. `:where`
guards are plain Scheme predicates; `(:optional %lhs_zp)` handles both
4-operand and 5-operand DQ forms without a separate pattern.

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

```
%0 = "hipsr.placeholder"(...)  loc("samples/passes/onnx-to-hipsr/min.sls":54:23)
%1 = shape.broadcast %a, %b   loc("samples/passes/onnx-to-hipsr/min.sls":56:41)
%2 = "hipsr.min"(...)          loc("samples/passes/onnx-to-hipsr/min.sls":59:18)
```

The location is derived from the syntax annotation of `#'op-name` at macro
expand time and encoded as `mlir::FileLineColLoc`. MLIR error messages,
`--mlir-print-ir-after-all`, and crash traces all resolve to the exact line in
the `.sls` pattern file.

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

→ See [docs/architecture.md](docs/architecture.md) for the full design.

## License

MIT — see [LICENSE](LICENSE).
