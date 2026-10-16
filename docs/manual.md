# CREST Manual

CREST (**C**onversion and **R**ewriting **E**ngine for **S**cheme **T**ransformations)
is a Scheme-hosted DSL for writing MLIR rewrite and dialect-conversion patterns.
Patterns are Scheme macros — edit a `.sls` file and re-run: no rebuild, no relink.

**Contents**

1. [Concepts](#1-concepts)
2. [Pattern anatomy](#2-pattern-anatomy)
3. [Match DSL reference](#3-match-dsl-reference)
4. [Rewrite DSL reference](#4-rewrite-dsl-reference)
5. [`begin-mlir-code`](#5-begin-mlir-code)
6. [Pass entry points](#6-pass-entry-points)
7. [Writing a new pass](#7-writing-a-new-pass)
8. [Debugging](#8-debugging)
9. [MLIR bindings reference](#9-mlir-bindings-reference)
10. [Deployment](#10-deployment)
11. [Extending with custom C++ bindings](#11-extending-with-custom-c-bindings)

---

## 1. Concepts

### Two pattern types

| Macro | MLIR base class | Use case |
|---|---|---|
| `define-rewrite-pattern` | `mlir::OpRewritePattern` | Greedy rewrites: fusion, folding, simplification |
| `define-conversion-pattern` | `mlir::ConversionPattern` | Dialect conversion with `TypeConverter` and `applyFullConversion` |

DRR and PDLL only generate `RewritePattern` subclasses. CREST is the only DSL that covers dialect conversion.

### Edit–reload cycle

In development mode (the default), pattern `.sls` files are loaded at runtime
from directories listed in `CREST_PATH`. Edit a `.sls` file and re-run — no
rebuild required.

```bash
export CREST_PATH=/my-project/passes:/path/to/crest/samples
build/tools/crest-opt/crest-opt --crest-pass="module=passes/my-pass" input.mlir
```

### CREST_PATH

`CREST_PATH` is a colon-separated list of directories (semicolon on Windows)
where the Chez Scheme runtime searches for `.sls` files — analogous to `PATH`.
It extends (not replaces) the built-in CREST scheme library directory.

---

## 2. Pattern anatomy

A complete greedy-rewrite pattern:

```scheme
(define-rewrite-pattern (hip-qadd-fusion op rewriter)
  ;;  ①  Match                                     ② Guards
  :if-match
    %lhs_scale = hip.constant          ()   :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %dq_lhs    = hip.dequantize_linear (%ctx %lhs %lhs_scale (:optional %lhs_zp) %dq_lhs_init)
    %rhs_scale = hip.constant          ()   :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %dq_rhs    = hip.dequantize_linear (%ctx %rhs %rhs_scale (:optional %rhs_zp) %dq_rhs_init)
    %out_scale = hip.constant          ()   :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
    %sum       = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)
                   :where (single-consumer? %sum)
    %q         = hip.quantize_linear   (%ctx %sum %out_scale (:optional %out_zp) %q_init)
  ;; ③  Compute before IR mutation
  :then-let
    ([!out-type  (mlir::Value::getType %q)]
     [lhs-scale  (scale-attr %lhs_scale)]
     [out-scale  (scale-attr %out_scale)]
     [lhs-zp     (zp-attr %lhs_zp)])
  ;; ④  Rewrite
  :rewrite %q :with
    (%init   = tensor.empty () -> !out-type)
    (%result = hip.qadd (%ctx %lhs %rhs %init)
             ("lhs_scale" = lhs-scale)
             ("output_scale" = out-scale)
             ("lhs_zp"    = lhs-zp)
             -> !out-type))
```

| Section | Purpose |
|---|---|
| [Signature](#pattern-signatures) | Rewrite: `(name op rewriter)` — Conversion: `(name op operands-ref rewriter type-converter)` |
| [`:if-match`](#3-match-dsl-reference) | Structural traversal of the def-use graph |
| [`:where`](#where-guard) | Arbitrary Scheme predicate guarding the preceding op |
| [`:then-let`](#then-let) | Bindings computed after match, before IR mutation |
| [`:rewrite %root :with`](#rewrite-root-with) | New ops to emit; `%root` is replaced with the last emitted op |

### Pattern signatures

CREST generates two kinds of C++ pattern subclass, selected by the macro name:

**`define-rewrite-pattern`** → [`mlir::OpRewritePattern`](https://mlir.llvm.org/doxygen/classmlir_1_1OpRewritePattern.html)

```scheme
(define-rewrite-pattern (name op rewriter)
  :if-match ... :rewrite ...)
```

The three parameters map to [`matchAndRewrite(Operation* op, PatternRewriter& rewriter)`](https://mlir.llvm.org/doxygen/classmlir_1_1RewritePattern.html#a6f5af0f52c32a9f8d9c3696a8d2c87e4).

**`define-conversion-pattern`** → [`mlir::ConversionPattern`](https://mlir.llvm.org/doxygen/classmlir_1_1ConversionPattern.html)

```scheme
(define-conversion-pattern (name op operands-ref rewriter type-converter)
  :if-match ... :rewrite ...)
```

The five parameters map to [`matchAndRewrite(Operation* op, ArrayRef<Value> operands, ConversionPatternRewriter& rewriter)`](https://mlir.llvm.org/doxygen/classmlir_1_1ConversionPattern.html#a4e9e0cb68cd4d6f30b1b02b1f3d1e5a3).
`operands-ref` carries the type-converted operands; fetch them with `(mlir-get-remapped-operands operands-ref)`.

---

## 3. Match DSL reference

### Op binding

```
%result-var = dialect.op-name (operand-list)
%result-var = :any            (operand-list)
```

- `%result-var` — bound to the single result `mlir::Value`. For multi-result ops: `(%r0 %r1) = dialect.op`.
- `dialect.op-name` — a Scheme symbol compared against `mlir::Operation::getName` (must match exactly). A string literal is also accepted.
- **`:any`** — wildcard op name; skips the `:check-op` step entirely so the binding matches an operation of any name. Useful when only the operand structure or a `:where` guard matters, not the op name. Example from `qdq-roundtrip.sls` — match a layout op of unknown dialect between a DQ and a Q:

  ```scheme
  %q      = hip.quantize_linear   (%ctx %layout %out_scale)
  %layout = :any                  (%ctx %dq)          ; any layout op — name is irrelevant
  %dq     = hip.dequantize_linear (%ctx %input %in_scale)
    :where (hip-can-requantize-layout-op? (mlir::Value::getDefiningOp %layout) op)
  ```

- `operand-list` — positional operands; each must be a bound `%var` or `%_` (wildcard, discards).

The **root op** is the variable named in `:rewrite root :with` — the order of
bindings in `:if-match` does not matter. The root op is what the pattern is
registered on (via `add-rewrite-pattern`) and what the rewriter replaces.

### `:where` guard

```scheme
%sum = hip.add (%ctx %a %b %init)
         :where (single-consumer? %sum)
```

- Evaluated after the op binding succeeds.
- Any Scheme expression; must return a truthy value for the match to continue.
- Two special forms available inside `:where`:
  - **`:current-op`** — the `mlir::Operation*` of the op just matched.
  - **`(:attr "name")`** — fetches the named attribute from `:current-op`; raises a condition (→ silent match failure) if absent.

```scheme
%scale = hip.constant ()
           :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
```

### Optional operands

```scheme
%dq = hip.dequantize_linear (%ctx %x %scale (:optional %zp) %init)
```

When the operand is present, `%zp` is bound to its
value; when absent, `%zp` is bound to the absent sentinel. Test with
`unbound-value?`:

```scheme
:then-let ([zp (if (unbound-value? %zp) 0 (extract-zp %zp))])
```

### Variadic operands

```scheme
%op = my.op (%ctx (:variadic %inputs) %init)
```

`%inputs` is bound to a Scheme list of `mlir::Value*`.

### Multiple and consecutive groups

Both `:optional` and `:variadic` support multiple variables and can appear
consecutively in one operand list:

```scheme
;; Two independent optional slots
%op = my.op (%x (:optional %a %b) %y)

;; Two variadic groups — each bound to a list
%op = my.op ((:variadic %inputs %weights))

;; Mixed: required, optional, variadic
%op = my.op (%x (:optional %y) (:variadic %z))
```


### `operandSegmentSizes` attribute

Requires an `operandSegmentSizes` attribute on the op. If absent, the pattern
silently fails to match.

### DAG diamonds (shared values)

When the same `%var` appears as an operand of multiple ops, CREST
automatically verifies they refer to the same value. No special syntax
needed — just reuse the same `%var`:

```scheme
%shared = some.op (...)
%a      = foo.op  (%shared ...)
%b      = bar.op  (%shared ...)   ; same %shared → pointer check emitted
```

### Wildcard `%_`

`%_` matches without binding a name, in both operand and result position.
Every `%_` occurrence is independent — two `%_` in different positions are
never treated as a shared value.

**Operand wildcard** — skip operands that are irrelevant to the rewrite:

```scheme
;; Match hip.quantize_linear but ignore the axis and init operands
%q = hip.quantize_linear (%ctx %sum %scale %_ %_)
```

**Result wildcard** — bind only the results you need from a multi-result op:

```scheme
;; Match test.split but only use its second result
(%_ %second) = test.split (%x)
%out         = test.use   (%second)
```

Note: two `%_` in different ops are **not** a diamond — they match
independently even if the underlying SSA values differ:

```scheme
%left  = test.add (%x %_)   ; %_ matches any value
%right = test.sub (%y %_)   ; this %_ is unrelated to the one above
%out   = test.combine (%left %right)
```

---

## 4. Rewrite DSL reference

### `:then-let`

```scheme
:then-let
  ([binding-name  scheme-expression]
   [!type-binding (mlir::Value::getType %some-val)]
   ...)
```

- All bindings are computed sequentially before any IR mutation.
- `!name` prefix — a naming convention signalling the binding holds an
  `mlir::Type`. The `!` is just part of the Scheme identifier; CREST assigns
  it no special meaning.
- Safe to read IR here (e.g. `mlir::Operation::getAttr`, `mlir::Value::getType`).
- Raise an error to abort the rewrite: `(error "my-pattern" "precondition failed")`.

### `:rewrite %root :with`

```scheme
:rewrite %q :with
  (%init   = tensor.empty () -> !out-type)
  (%result = hip.qadd (%ctx %lhs %rhs %init)
           ("lhs_scale" = lhs-scale)
           -> !out-type))
```

Before emission starts, the insertion point is set to immediately before the
root op (equivalent to
[`setInsertionPoint(op)`](https://mlir.llvm.org/doxygen/classmlir_1_1OpBuilder.html#a3c5f7fcaf5c4db5a7b3db573e3e14f2f))
so new ops appear in place of the matched subgraph. The last emitted op's
result replaces `%root` in all uses.

Op-form syntax — see [§5 `begin-mlir-code`](#5-begin-mlir-code) for the full reference.

---

## 5. `begin-mlir-code`

`begin-mlir-code` emits MLIR ops via the current rewriter. It is used
implicitly inside `:rewrite :with` and can also be called standalone:

```scheme
(begin-mlir-code
  (%c0  = arith.constant () ("value" = (mlir::IntegerAttr::get<i64> 0)) -> (mlir::IntegerType::get<i64>))
  (%sum = arith.addi (%a %b) -> (mlir::Value::getType %a)))
```

Every emitted op carries a `FileLineColLoc` from the `.sls` source line.

### Op-form syntax

Each statement is an op-form:

```
(%result-var = dialect.op-name (operand ...) ("attr" = val) ... -> !result-type)
```

- `("attr-name" = val)` — sets a named attribute; `val` is any Scheme expression
  returning an `mlir::Attribute`.
- `-> !type` — result type expression (an `mlir::Type`).
- Multi-result: `((%r0 %r1) = ...)`.
- **Region-bearing ops** — one or more regions follow the attribute list.
  Each region is a sequence of blocks; each block starts with `^bb<n>` and
  optional block arguments, followed by op-forms:

  ```scheme
  ;; Single region, single block with arguments
  (%op = my.region_op (%x)
        (^bb0 ((%arg0 : !i32) (%arg1 : !i32))
              (%r = arith.addi (%arg0 %arg1) -> !i32)
              (my.yield (%r)))
        -> !i32)
  ```

  Multiple blocks in one region — each block after the first is a new `^bb`:

  ```scheme
  (%op = cf.cond_br (%cond)
        (^bb0 ()
              (cf.br (%x) ^bb1))
        (^bb1 ((%v : !i32))
              (cf.return (%v)))
        -> !i32)
  ```

  Multiple regions — list them one after the other:

  ```scheme
  ;; shape.assuming has one region; hipsr.placeholder nests shape.assuming inside
  (%res = shape.assuming (%witness)
        (^bb0 ()
              (%r = compute (%a) -> !shape-type)
              (shape.assuming_yield (%r)))
        -> !shape-type)
  ```

  Regions can be nested: an op-form inside `^bb` can itself have regions.
  See the `hipsr.placeholder` pattern in `samples/passes/onnx-to-hipsr/matmul.sls`
  for a real-world example of nested regions.

---

## 6. Pass entry points

### Greedy rewrite pass

```scheme
(library (passes my-pass)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest)
          (passes my-pass patterns))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps ctx)
          (add-rewrite-pattern ps "root.op-name" my-pattern 10)
          (mlir::applyPatternsGreedily module-op ps))))))
```

`add-rewrite-pattern` arguments: `(pattern-set root-op-name pattern-fn benefit)`.

### Dialect conversion pass

```scheme
(library (passes my-conversion)
  (export run-pass)
  (import (except (rnrs) =)
          (mlir Transforms DialectConversion)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest)
          (passes my-conversion patterns))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter (tc)
          (with-ConversionTarget (target ctx)
            (with-RewritePatternSet (ps ctx)
              ;; Mark source dialect illegal, target dialect legal
              (mlir::ConversionTarget::addIllegalDialect! target "onnx")
              (mlir::ConversionTarget::addLegalDialect!   target "hipsr")
              ;; Register type conversions
              (mlir::TypeConverter::addConversion! tc convert-tensor-type)
              ;; Register patterns
              (add-conversion-pattern ps "onnx.MatMul" my-matmul-pattern 10 tc)
              (mlir::applyFullConversion module-op target ps tc))))))))
```

---

## 7. Writing a new pass

### Step 1 — Create the pattern file

```
my-project/
  passes/
    my-pass.sls          ← pass entry point
    my-pass/
      patterns.sls       ← pattern definitions
      helpers.sls        ← domain helpers
```

### Step 2 — Write the pattern

`passes/my-pass/patterns.sls`:

```scheme
#!r6rs
(library (passes my-pass patterns)
  (export my-fusion)
  (import (except (rnrs) =)
          (crest)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i64>))

  (define-rewrite-pattern (my-fusion op rewriter)
    :if-match
      %input = source.op (%a %b)
        :where (mlir::IntegerType? (mlir::Value::getType %input))
    :then-let
      ([!result-type (mlir::Value::getType %input)])
    :rewrite %input :with
      (%result = target.op (%a %b) -> !result-type)))
```

### Step 3 — Write the pass entry point

`passes/my-pass.sls`:

```scheme
#!r6rs
(library (passes my-pass)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest)
          (passes my-pass patterns))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps ctx)
          (add-rewrite-pattern ps "source.op" my-fusion 10)
          (mlir::applyPatternsGreedily module-op ps))))))
```

### Step 4 — Run

```bash
export CREST_PATH=/my-project/passes:/path/to/crest/samples
build/tools/crest-opt/crest-opt \
  --crest-pass="module=passes/my-pass" \
  input.mlir
```

---

## 8. Debugging

### `CREST_DEBUG_MATCH=1`

Set before loading the pattern (i.e. before the first run). CREST re-generates
the match code with per-step diagnostics. Every failed check prints:

- The Scheme expression that returned `#f`
- The actual op at that position

```bash
CREST_DEBUG_MATCH=1 CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="module=passes/hip-fusion" \
  test/hip-fusion/qadd.mlir 2>&1 | grep warning
```

Example output when `hip.add` is replaced by `hip.sub`:

```
warning: samples/passes/hip-fusion/qadd.sls:83:20: [hip-qadd-fusion]
  :check-op FAILED: (and (string=? (mlir::Operation::getName
    (vector-ref all-operations 5)) "hip.add") ...)
  actual: %11 = "hip.sub"(%arg0, %7, %9, %10) : (!hip.context, ...) -> tensor<...>
```

No C++ changes, no rebuild — just set the variable, re-run, debug, unset, re-run.

### Compile-time debug flags

Add as keyword arguments after the pattern name (at expansion time only):

```scheme
(define-rewrite-pattern (my-pattern op rewriter)
  :debug-parse    ; print parsed AST
  :debug-validate ; print validated AST
  :debug-analyze  ; print action sequence
  :debug-codegen  ; print generated Scheme code
  :if-match ...)
```

Output goes to stderr at library load time.

### Source locations on emitted ops

Every op emitted by `begin-mlir-code` (inside `:rewrite :with`) carries a
`FileLineColLoc` pointing to the exact `.sls` line.

```bash
CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="module=passes/onnx-to-hipsr" \
  --mlir-print-debuginfo \
  test/onnx-to-hipsr/matmul.mlir 2>/dev/null | head -5
```

```
%c1 = shape.const_size 1 loc("samples/passes/onnx-to-hipsr/matmul.sls":45:12)
%c0 = shape.const_size 0 loc("samples/passes/onnx-to-hipsr/matmul.sls":46:12)
```

MLIR error messages and `--mlir-print-ir-after-all` traces resolve to the
exact `.sls` line automatically.

### Scheme REPL

Chez Scheme ships a REPL. Load CREST libraries interactively:

```bash
CREST_PATH=$(pwd)/samples \
  build/_deps/chezscheme-build/ta6le/bin/ta6le/scheme \
  --libdirs "$(pwd)/scheme"

> (import (crest))
> (import (mlir IR BuiltinTypes))
> (mlir::IndexType::get)   ; etc.
```

---

## 9. MLIR bindings reference

All bindings follow the CLAUDE.md convention: library names mirror MLIR header
paths. Import only what you use.

### Core IR

| Import | Key exports |
|---|---|
| `(mlir IR MLIRContext)` | `with-current-MLIRContext`, `current-MLIRContext`, `mlir::MLIRContext::new` |
| `(mlir IR Operation)` | `mlir::Operation::getName`, `getResult`, `getRegion`, `getAttr`, `setAttr!`, `getContext`, `getNumResults`, `getNumOperands` |
| `(mlir IR Value)` | `mlir::Value::getType`, `getDefiningOp`, `getUses` |
| `(mlir IR Block)` | `mlir::Block::getArgument`, `getNumArguments` |
| `(mlir IR Region)` | `mlir::Region::front`, `getParentOp` |
| `(mlir IR OpResult)` | `mlir::OpResult::getResultNumber` |

### Types

| Import | Key exports |
|---|---|
| `(mlir IR BuiltinTypes)` | `mlir::IndexType::get`, `mlir::IntegerType::get<i64>`, `mlir::FloatType::get<f32>`, `mlir::RankedTensorType::get`, `mlir::RankedTensorType::getShape`, `mlir::RankedTensorType::getRank`, `mlir::RankedTensorType::cloneWithEncoding` |
| `(mlir IR Type)` | `mlir::Type::getFromOpaquePointer` |

### Attributes

| Import | Key exports |
|---|---|
| `(mlir IR BuiltinAttributes)` | `mlir::IntegerAttr::get<i64>`, `mlir::FloatAttr::get<f32>`, `mlir::StringAttr::get`, `mlir::DenseElementsAttr::isSplat`, `mlir::DenseElementsAttr::getSplatValue<APFloat>`, `mlir::DenseElementsAttr::getSplatValue<APInt>`, `mlir::DenseI32ArrayAttr::get`, `mlir::DenseI64ArrayAttr::get` |

### Pattern matching and rewriting

| Import | Key exports |
|---|---|
| `(mlir IR PatternMatch)` | `with-RewritePatternSet`, `with-RewriterBase`, `current-RewriterBase`, `with-OpBuilder` |
| `(mlir Transforms GreedyPatternRewriteDriver)` | `mlir::applyPatternsGreedily` |
| `(mlir Transforms DialectConversion)` | `with-TypeConverter`, `with-ConversionTarget`, `mlir::applyFullConversion`, `mlir::applyPartialConversion`, `mlir::ConversionTarget::addIllegalDialect!`, `mlir::ConversionTarget::addLegalDialect!`, `mlir::TypeConverter::addConversion!` |

### Location

| Import | Key exports |
|---|---|
| `(mlir IR Location)` | `mlir::UnknownLoc::get`, `mlir::FileLineColLoc::get` |

### CREST public API

```scheme
(import (crest))
```

Exports: `define-rewrite-pattern`, `define-conversion-pattern`,
`add-rewrite-pattern`, `add-conversion-pattern`,
`begin-mlir-code`, `unbound-value?`,
`mlir-get-remapped-operands`.

---

## 10. Deployment

### Development mode (default)

Pattern `.sls` files are loaded from `CREST_PATH` at runtime. On first import
Chez compiles and caches the library as a `.so`; subsequent runs are fast.
The `.sls` files must be co-deployed with the binary and must match the
compiled version — a mismatch fails at runtime.

```bash
export CREST_PATH=/deploy/passes
./crest-opt --crest-pass="module=passes/my-pass" input.mlir
```

### Boot mode (embedded)

Compile all `.sls` files into a single `crest.boot` embedded in the binary.
No `.sls` files required at runtime.

```bash
cmake -B build -DCREST_EMBED_SCHEME_BOOT=ON
cmake --build build
```

Add downstream passes to the boot before `add_subdirectory(crest)`:

```cmake
list(PREPEND CREST_BOOT_SOURCE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/passes")
list(PREPEND CREST_BOOT_ROOTS       "${CMAKE_CURRENT_SOURCE_DIR}/passes/my-pass.sls")
add_subdirectory(crest)
```

`CREST_PATH` still works in boot mode for libraries not in the boot image.

---

## 11. Extending with custom C++ bindings

Register additional MLIR APIs from a downstream project without modifying CREST:

```cpp
// In your plugin's initialization code:
extern "C" void crest_register_extra_bindings(void (*fn)());

crest_register_extra_bindings([]() {
    Sregister_symbol("myDialect::MyOp::create",
        (void*)+[](uint64_t builder, uint64_t loc, uint64_t type) -> uint64_t {
            auto b = *reinterpret_cast<mlir::OpBuilder*>(builder);
            // ... create op ...
            return reinterpret_cast<uint64_t>(op.getOperation());
        });
});
```

Then declare and use in Scheme:

```scheme
;; In your ffi.sls:
(define %myDialect::MyOp::create
  (foreign-procedure "myDialect::MyOp::create" (uptr uptr uptr) uptr))

;; In your public .sls:
(define myDialect::MyOp::create %myDialect::MyOp::create)
```

Follow the CLAUDE.md binding convention: one header → one module, `%`-prefix
for raw FFI bindings, clean names in the public module.
