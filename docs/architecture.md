<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-10-04
**Document Type:** Architecture
**Status:** Draft
**Related:** [MLIR Dialect Conversion](https://mlir.llvm.org/docs/DialectConversion/), [MLIR PDLL](https://mlir.llvm.org/docs/PDLL/)

---

# CREST Architecture

CREST (**C**onversion and **R**ewriting **E**ngine for **S**cheme **T**ransformations)
is a Scheme-hosted engine for writing MLIR conversion and rewrite patterns.

## Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Layer 1 — MLIR FFI bindings](#layer-1--mlir-ffi-bindings)
  - [Layer 2 — CREST pattern DSL](#layer-2--crest-pattern-dsl)
  - [Layer 3 — Domain helpers](#layer-3--domain-helpers)
  - [Layer 4 — Pass entry points](#layer-4--pass-entry-points)
- [Deployment](#deployment)
- [Operational costs](#operational-costs)
- [Related Documents](#related-documents)

---

## Overview

Writing MLIR dialect conversion passes in C++ requires implementing
`OpConversionPattern` subclasses with `matchAndRewrite` methods, wiring
`TypeConverter` and `ConversionTarget`, and rebuilding the compiler for every
pattern change. MLIR's established pattern DSLs —
[PDL](https://mlir.llvm.org/docs/PDLL/) and
[DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/) — cannot address this:
both generate only `RewritePattern` subclasses and have no support for
[`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/);
[`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns)
does not appear in the [PDLL documentation](https://mlir.llvm.org/docs/PDLL/).

CREST provides a Scheme-hosted pattern DSL that generates `ConversionPattern`
subclasses and uses Chez Scheme as its extension language, eliminating C++
requirements for constraints, type predicates, and rewrite logic.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 4 — Pass entry points                                │
│  run-pass → register patterns → apply-full-conversion        │
└────────────────────────┬────────────────────────────────────┘
                         │ imports
┌────────────────────────▼────────────────────────────────────┐
│  Layer 2 — CREST pattern DSL                                  │
│  define-conversion-pattern / define-rewrite-pattern          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Phase 1: Parse → Phase 2: Validate →               │   │
│  │  Phase 3: Analyze → Phase 4: Codegen                │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ imports
┌────────────────────────▼────────────────────────────────────┐
│  Layer 3 — Domain helpers                                   │
│  Quantization predicates, op constructors, dialect types     │
└────────────────────────┬────────────────────────────────────┘
                         │ imports
┌────────────────────────▼────────────────────────────────────┐
│  Layer 1 — MLIR FFI bindings                                │
│  foreign-procedure wrappers around MLIR C API               │
└─────────────────────────────────────────────────────────────┘
```

### Layer 1 — MLIR FFI bindings

Thin `foreign-procedure` wrappers around the
[MLIR C API](https://mlir.llvm.org/docs/CAPI/), organized to mirror MLIR's
namespace structure:

| Library | Wraps |
|---|---|
| `(mlir core operation)` | `mlir_operation_*` |
| `(mlir core value)` | `mlir_value_*` |
| `(mlir core context)` | Dynamic parameter `current-mlir-context` |
| `(mlir core builder)` | Dynamic parameters for rewriter, block builder, insertion point |
| `(mlir core attribute)` | Generic dispatch via runtime C-symbol lookup |
| `(mlir core conversion)` | [`TypeConverter`](https://mlir.llvm.org/docs/DialectConversion/#type-converter), `ConversionTarget`, `RewritePatternSet` |
| `(mlir core ir)` | Re-export hub |
| `(mlir dialects/*)` | Per-dialect op constructors and type predicates |

`(mlir core attribute)` resolves attribute constructor functions
(`mlir_make_attr_<type>`) at runtime via `foreign-entry?`. New attribute types
registered in C++ are discoverable from Scheme without any Scheme change.

Dynamic parameters (`current-mlir-context`, `current-rewriter`,
`current-block-builder`, `current-loc`) follow the same pattern as
[MLIR's thread-local `OpBuilder` state](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-3/).
`parameterize` installs the right context for a dynamic extent without
threading it through every argument.

### Layer 2 — CREST pattern DSL

CREST's pattern DSL is implemented as a Scheme macro layer with two entry
points:

```scheme
(define-conversion-pattern ...)   ; → mlir::ConversionPattern
(define-rewrite-pattern ...)      ; → mlir::OpRewritePattern
```

#### Entry point

```scheme
(import (crest))   ; public API — define-conversion-pattern, define-rewrite-pattern, unbound-value?, …
```

#### Why CREST rather than PDLL or DRR

[PDL](https://mlir.llvm.org/docs/PDLL/) and
[DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/) generate
`RewritePattern` subclasses only. They cannot generate
[`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns)
subclasses, which require `ConversionPatternRewriter`, type-converted operand
adaptors via `OpAdaptor`, and `applyFullConversion` /
`applyPartialConversion`. Neither appears in the
[PDLL](https://mlir.llvm.org/docs/PDLL/) or
[DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/) documentation.
CREST is the only DSL-based option that supports `ConversionPattern` today.

#### Match-side constraints

A constraint in MLIR pattern matching is a predicate that must hold for a
pattern to fire — for example, "this operand's type must be quantized" or
"this axis value, after normalization, must equal the input rank minus one."

In PDLL, constraints require a C++ `native` block embedded in the `.pdll`
file. In DRR, they require `CPred<"...">` — a C++ expression as a TableGen
string. Both require a rebuild for any change.

In CREST, the `:where` guard accepts any Scheme expression. A constraint is a
plain Scheme function defined in the same `.sls` file:

```scheme
(define (last-axis? v axis)
  (let* ([rank (mlir-type-get-rank (mlir-value-get-type v))]
         [axis (if (< axis 0) (+ axis rank) axis)])  ; normalize negative
    (= axis (- rank 1))))

(define-conversion-pattern (lower-gather op operands-ref rw tc)
  :if-match
      %gather = onnx.Gather (%data %indices)
                  :where (last-axis? %data (mlir-attr-as (:attr "axis") :integer))
  :rewrite %gather :with ...)
```

The function can be tested independently, reused across patterns, and changed
without rebuilding the binary.

#### `:where` keywords: `:current-op` and `(:attr name)`

Inside a `:where` guard, two special forms are available:

- **`:current-op`** — the operation currently being matched in the DAG (not the
  root `op` parameter). Required when the guard references the matched sub-op
  rather than the root.

- **`(:attr "name")`** — fetches the named attribute from `:current-op` as a
  raw attribute pointer. Raises an error (→ silent match failure) if absent.
  Compose with the generic attr API:

```scheme
%scale = hip.constant ()
           :where (mlir-attr-isa (:attr "value") :dense-elements-splat)
```

#### Optional and variadic operands

Operands tagged `(:optional %var)` or `(:variadic %var)` are matched via
`mlir-operation-get-operands`, which reads `operandSegmentSizes` internally
and returns a list — one element per spec entry.

```scheme
%dq = hip.dequantize_linear (%ctx %x %scale (:optional %zp) %init)
```

When the optional operand is absent, `%zp` is bound to the absent sentinel.
Use `unbound-value?` in `:then-let` to distinguish present from absent:

```scheme
:then-let
    ([zp-attr (mlir-make-attr :i64
                (if (unbound-value? %zp) 0
                    (mlir-attr-into
                      (mlir-operation-get-attribute
                        (mlir-value-get-defining-op %zp) "value")
                      :splat-integer)))])
```

This eliminates separate patterns for 4-operand and 5-operand op forms.

#### The host language as extension mechanism

PDL and DRR are closed DSLs. Anything outside their expressibility — on both
the match side and the rewrite side — requires a C++ escape and a full
rebuild.

CREST's pattern DSL is open: the `:where` guard and the `:rewrite` body both
accept arbitrary Scheme. Complex rewrite logic — axis normalization, shape
broadcasting, `operandSegmentSizes` construction — is expressed as Scheme
functions in the same file, with the same edit–reload cycle as the pattern.

#### Comparison with MLIR pattern DSLs

| Dimension | DRR | PDLL | CREST |
|---|---|---|---|
| [`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns) support | [No](https://mlir.llvm.org/docs/DeclarativeRewrites/) | [No](https://mlir.llvm.org/docs/PDLL/) | **Yes** |
| Edit → test cycle | Rebuild required | Rebuild required | **Reload `.sls`** |
| Extra toolchain | `mlir-tblgen` | `mlir-pdll` + `mlir-tblgen` | **None** |
| Constraints without C++ (`:where`) | No | No | **Yes** |
| Turing-complete rewrite logic | Via C++ | Via C++ | **Native Scheme** |
| Optional / variadic operands | No | Limited | **Yes** |
| Compile-time debug flags | No | No | **Yes** |
| Patterns in deployed binary | Yes | Yes | **Yes (boot mode)** |
| Filesystem deployment dependency | No | No | Yes (dev mode) |
| FFI maintenance burden | None | None | Real |

#### Four-phase macro pipeline

`define-conversion-pattern` runs at Chez expansion time:

1. **Parse** — builds an `ast-pattern-expand` record tree. Operands become
   `ast-operand` records tagged `required`, `optional`, or `variadic`. The
   `:rewrite` body is kept as raw syntax.

2. **Validate** — checks semantic rules (`%`-prefixed names, no duplicate
   bindings, root variable present) and caches `root-op-index`,
   `root-result-idx`, `root-op-name`.

3. **Analyze** — topological DAG traversal from the root, producing a flat
   action sequence: `:set-current-op`, `:check-op`, `:bind-operand` (all-required
   ops), `:bind-operands` (ops with `:optional`/`:variadic` — delegates to
   `mlir-operation-get-operands` which reads `operandSegmentSizes`),
   `:check-eq` (DAG diamonds where a value is used by multiple ops),
   `:bind-result`, `:check-where`.

4. **Codegen** — translates the action sequence into an
   `(and check₀ check₁ …)` expression wrapped in a `guard`, producing a
   lambda with the signature of `mlir::ConversionPattern::matchAndRewrite`.

The `:rewrite` body is compiled by a separate `with-mlir-ops` macro that
translates named SSA op-forms into a `let*` of builder calls.

Debug flags (`:debug-parse`, `:debug-validate`, `:debug-analyze`,
`:debug-codegen`) print each phase's output at Chez expansion time.

### Layer 3 — Domain helpers

Any Scheme library built on top of Layer 1. This layer has no fixed structure:
users add whatever domain-specific predicates, op constructors, type helpers,
or utility functions their passes need. The included `(mlir hip fusion)` and
dialect libraries (`hipsr`, `tensor`, `func`, etc.) are examples, not the
definition of this layer.

### Layer 4 — Pass entry points

Each pass is a single `.sls` file:
1. Imports CREST patterns and domain helpers
2. Creates a `RewritePatternSet` or `ConversionTarget`
3. Calls `mlir-apply-patterns-greedy` or `mlir-apply-full-conversion`

A downstream project adds `.sls` pass files and sets `CREST_PATH` to their
directory — no C++ required for a new pass.

---

## Deployment

### Development mode (default)

The interpreter loads `.sls` files at runtime via
[Chez `library-directories`](https://cisco.github.io/ChezScheme/csug9.5/use.html#./use:h1).
`CREST_PATH` (colon-separated on POSIX, semicolon-separated on Windows, analogous
to `PATH`) adds directories for downstream passes not in the CREST tree.

First `import` of a library incurs ~100–200ms Chez compilation; subsequent
runs use the cached `.so`. `.sls` files must be co-deployed and version-matched
with the binary — a mismatch produces a runtime failure rather than a build
error.

### Boot mode (`-DCREST_EMBED_SCHEME_BOOT=ON`)

All `.sls` files are compiled at CMake build time into a single `crest.boot`
and embedded as a C byte-array in the binary. The deployed binary requires no
`.sls` files at runtime. `CREST_PATH` still works in boot mode for libraries
not in the boot.

Boot compilation uses Chez's `compile-imported-libraries` with
`library-directories` set as `(source . obj-dir)` pairs so compiled `.so`
files land in the CMake build tree, not the source tree.

Downstream projects extend the boot before `add_subdirectory(crest)`:

```cmake
list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-pass.sls")
add_subdirectory(crest)
```

---

## Operational costs

**FFI maintenance.** Each MLIR C API function used from Scheme requires a C++
`Sregister_symbol` registration and a Scheme `foreign-procedure` declaration.
The `foreign-entry?` dynamic dispatch eliminates this for attribute types;
everything else requires a manual pairing per function.

**Version coupling.** Boot mode eliminates filesystem coupling at the cost of
a build step. See the Deployment section above.

---

## Related Documents

- [MLIR Dialect Conversion](https://mlir.llvm.org/docs/DialectConversion/) — `ConversionPattern`, `TypeConverter`, `applyFullConversion`
- [MLIR PDLL](https://mlir.llvm.org/docs/PDLL/) — PDLL language reference and known limitations
- [MLIR Declarative Rewrites (DRR)](https://mlir.llvm.org/docs/DeclarativeRewrites/) — TableGen-based `RewritePattern` DSL
- [Chez Scheme User's Guide](https://cisco.github.io/ChezScheme/csug9.5/) — `library-directories`, `foreign-procedure`, `parameterize`
