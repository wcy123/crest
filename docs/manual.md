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
7. [Debugging](#7-debugging)
8. [MLIR bindings reference](#8-mlir-bindings-reference)
9. [Deployment](#9-deployment)
10. [Extending with custom C++ bindings](#10-extending-with-custom-c-bindings)

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

### Attributes

The general form `("name" = val)` sets an attribute where `val` is any Scheme
expression returning an `mlir::Attribute`. Common types have shorthands that
construct the attribute for you:

| Shorthand | Expands to |
|---|---|
| `("name" = val :index)` | `mlir::IntegerAttr::get<index>` |
| `("name" = val :i64)` | `mlir::IntegerAttr::get<i64>` |
| `("name" = val :f32)` | `mlir::FloatAttr::get<f32>` |
| `("name" = val :i32-array)` | `mlir::DenseI32ArrayAttr::get` |
| `("name" = val :i64-array)` | `mlir::DenseI64ArrayAttr::get` |
| `("name" = val :unit)` | `mlir::UnitAttr::get` (val ignored) |

```scheme
;; Shorthand: integer tag constructs the attribute automatically
(%c = arith.constant ()
     ("value" = 42 :index)
     -> (mlir::IndexType::get))

;; General form: val is any Scheme expression returning an mlir::Attribute
(%op = my.op ()
      ("scale" = (mlir::FloatAttr::get<f32> 0.5))
      ("zp"    = (mlir::IntegerAttr::get<i64> 0)))
```

### Result types

`-> !type` where `!type` is any Scheme expression returning an `mlir::Type`.
Multi-result ops list all types:

```scheme
;; Single result
(%r = my.op (%x) -> !out-type)
;; Multi-result — number of types must equal number of result variables
((%r0 %r1) = my.op (%x) -> (!type-a !type-b))
```

### Regions

Regions follow the attribute list. Each region is a sequence of blocks;
each block starts with `^label` and optional block arguments, followed by
op-forms:

```scheme
;; Single region, single block with arguments
(%op = my.region_op (%x)
      (^bb0 ((%arg0 : !i32) (%arg1 : !i32))
            (%r = arith.addi (%arg0 %arg1) -> !i32)
            (my.yield (%r)))
      -> !i32)
```

Multiple single-block regions — list `^bb` shorthands consecutively
(each shorthand creates exactly one region with one block):

```scheme
;; Two regions (e.g. scf.if: then-region and else-region)
(%op = scf.if (%cond)
      (^then ()
             (%a = compute_a (%x) -> !i32)
             (scf.yield (%a)))
      (^else ()
             (%b = compute_b (%y) -> !i32)
             (scf.yield (%b)))
      -> !i32)
```

One region with multiple blocks — use the explicit `:region` wrapper:

```scheme
(%op = my.op ()
      (:region
        (^entry ()
                (cf.br () ^exit))
        (^exit ((%v : !i32))
               (cf.return (%v))))
      -> !i32)
```

Multiple regions each with multiple blocks — use multiple `:region` wrappers:

```scheme
(%op = my.op ()
      (:region
        (^r0-entry () (cf.br () ^r0-exit))
        (^r0-exit  () (my.yield ())))
      (:region
        (^r1-entry () (cf.br () ^r1-exit))
        (^r1-exit  () (my.yield ())))
      -> !i32)
```

In summary:

| Form | Regions | Blocks per region | Block args |
|---|---|---|---|
| `(^bb ...)` | 1 | 1 | static |
| `(^bb ...) (^bb ...)` | N | 1 each | static |
| `(^bb builder ,@pairs ...)` | 1 | 1 | dynamic |
| `(:region (^a ...) (^b ...))` | 1 | N | static |
| `(:region ...) (:region ...)` | N | N each | static |

The body of every `^label` block is a recursive `begin-mlir-code` call — the
same op-form syntax, the same result variables, the same attribute and region
modifiers. Regions can be nested arbitrarily deep.
See `samples/passes/onnx-to-hipsr/matmul.sls` for a real-world example.

### Dynamic block arguments

When the number or types of block arguments are not known at compile time,
use `,@pairs-expr` to splice a runtime list of `(name . type)` pairs:

```scheme
;; arg-types is a Scheme list of mlir::Type values computed at match time
(%fn = my.func ()
      (^bb0 builder ,@(map cons arg-names arg-types)
        ;; (:arg N) is shorthand for the Nth block argument
        (%r = arith.addi ((:arg 0) (:arg 1)) -> !i32)
        (my.return (%r)))
      -> !i32)
```

The `,@` prefix is Chez Scheme's unquote-splicing — a visual marker that this
list is computed at runtime rather than fixed at compile time. Each pair's
`cdr` is the argument type; the `car` (a symbol or string) is documentation
only and is not bound in the body.

The block body is a recursive `begin-mlir-code` call with `builder` as the
active builder, so the full op-form syntax is available (nested regions,
attribute shorthands, multi-result ops, etc.).

Inside the block body, **`(:arg N)`** is a shorthand for
`(mlir::Block::getArgument (current-block) N)` where `current-block` is a
dynamic parameter installed by the `^label ,@...` form. It is only valid
inside such a dynamic block body.

```scheme
;; Concrete example: rewrite test.copy(%v) → test.with_block(%v) where
;; the block arg type is determined at runtime from %v's type.
(define-rewrite-pattern (%%pattern op rewriter)
  :if-match
    %out = test.copy (%v)
  :then-let
    ([!vtype   (mlir::Value::getType %v)]
     [arg-pairs (list (cons 'arg !vtype))])  ; one (name . type) pair
  :rewrite %out :with
    (%result = test.with_block (%v)
             (^bb0 builder ,@arg-pairs
               (my.yield ((:arg 0))))   ; (:arg 0) → first block argument
             -> !vtype))
```

Use dynamic block args when generating functions whose argument lists vary
(e.g. lowering to `func.func` from an AST), and static `((arg : type) ...)`
when the count and types are fixed.

---

## 6. Pass entry points

A pass is an ordinary R6RS `library` that exports a function named `run-pass`.
`run-pass` is a convention — it is the name that `--crest-pass="module=passes/my-pass"`
calls at runtime. Everything else in the library is plain Scheme: helper
functions, type predicates, constants — no CREST macros required.

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

`add-rewrite-pattern` arguments:

| Argument | Description |
|---|---|
| `pattern-set` | The `RewritePatternSet` to register into |
| `root-op-name` | String — the op name this pattern is dispatched on (e.g. `"hip.quantize_linear"`) |
| `pattern-fn` | The pattern function defined by `define-rewrite-pattern` |
| `benefit` | Integer — higher benefit patterns are tried first; use `1` when there is no ordering concern |

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
          (with-ConversionTarget (target)
            (with-RewritePatternSet (ps)
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

## 7. Debugging

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

---

## 8. MLIR bindings reference

This section lists commonly used bindings. The set is not exhaustive — bindings
are added on demand as new MLIR APIs are needed. Library names mirror MLIR header
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

## 9. Deployment

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

## 10. Extending with custom C++ bindings

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
