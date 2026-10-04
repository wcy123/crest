<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

# CREST Architecture

CREST is a Scheme-hosted engine for writing MLIR conversion and rewrite patterns.
It is structured in four layers, each with a distinct role.

---

## Layer 1 — MLIR FFI bindings (`scheme/mlir/`)

Thin `foreign-procedure` wrappers around the MLIR C API, organized to mirror
MLIR's own namespace structure:

| Library | Maps to |
|---|---|
| `(mlir core operation)` | `mlir_operation_*` |
| `(mlir core value)` | `mlir_value_*` |
| `(mlir core context)` | Dynamic parameter `current-mlir-context` |
| `(mlir core builder)` | Dynamic parameters for rewriter, block builder, insertion point |
| `(mlir core attribute)` | Generic dispatch via runtime C-symbol lookup |
| `(mlir core conversion)` | `TypeConverter`, `ConversionTarget`, `RewritePatternSet` |
| `(mlir core ir)` | Re-export hub — no logic |
| `(mlir dialects/*)` | Per-dialect op constructors and type predicates |

**Notable design:** `(mlir core attribute)` resolves attribute type functions
(`mlir_make_attr_<type>`) at runtime via `foreign-entry?`. New attribute types
registered in C++ are discoverable from Scheme without any Scheme change.

**Dynamic parameters** (`current-mlir-context`, `current-rewriter`,
`current-block-builder`, `current-loc`) are installed with `parameterize` in
the same style MLIR uses thread-local state in C++. Deep call trees get the
right context without it being threaded through every argument list.

---

## Layer 2 — DDR: Declarative Dialect Rewriting (`scheme/crest/ddr/`)

A Scheme macro DSL that compiles declarative pattern descriptions into MLIR
`ConversionPattern` and `RewritePattern` lambdas at Chez expansion time. The
two entry points are:

```scheme
(define-conversion-pattern ...)   ; → mlir::ConversionPattern
(define-rewrite-pattern ...)      ; → mlir::OpRewritePattern
```

### Why a custom DSL rather than PDL or DRR?

PDL (Pattern Description Language) and DRR (TableGen-based Declarative Rewriting)
are MLIR's established pattern DSLs. Neither can be used here for a structural
reason: **both generate only `RewritePattern` subclasses**. They have no support
for `ConversionPattern` / `OpConversionPattern`, which require
`ConversionPatternRewriter`, type-converted operand adaptors, and
`applyFullConversion` / `applyPartialConversion`. Every dialect lowering pass —
the primary workload in the MLIR ecosystem — depends on this infrastructure.
PDLL documents this explicitly as a planned but missing feature with no RFC yet.

DDR generates `ConversionPattern` subclasses. It is currently the only
DSL-based option that does.

### The host language is not an escape hatch — it is the design

PDL and DRR are closed DSLs. Anything outside their expressibility requires
C++ `native` blocks or `NativeCodeCall` string escapes, which means a full
rebuild and a context switch to a different language.

DDR is an open DSL: the `:where` guard and `:rewrite` body accept arbitrary
Scheme. A named helper function in the same `.sls` file serves the same purpose
as a PDLL `Constraint` or a DRR `NativeCodeCall` — but without leaving Scheme,
without C++, and without a recompile:

```scheme
;; A named constraint — callable from any pattern in the same library:
(define (quantized-tensor? v)
  (mlir-attr-isa (mlir-value-get-type v) ':quantized))

;; Use it in a match guard:
(define-conversion-pattern (lower-cast op operands-ref rw tc)
  %cast = "onnx.Cast" (%data)
  :where (quantized-tensor? %data)
  :rewrite ...)
```

The Turing-complete host is not a fallback for hard cases — it is the mechanism
for all constraints, type predicates, and shape computations. Complex logic
(axis normalization, shape broadcasting, `operandSegmentSizes` construction)
lives in plain Scheme functions in the same file, with the same
seconds-level edit–test loop as the pattern itself.

### Comparison

| Dimension | DRR | PDLL | DDR |
|---|---|---|---|
| Dialect conversion (`ConversionPattern`) | No | No | **Yes** |
| Edit → test loop | Minutes (rebuild) | Minutes (rebuild) | **Seconds (reload)** |
| Extra toolchain | `mlir-tblgen` | `mlir-pdll` + `mlir-tblgen` | **None** |
| Complex constraints without C++ | No | No | **Yes** |
| Turing-complete rewrite logic | Via C++ | Via C++ | **Native Scheme** |
| Interactive debugging | No | No | **Yes** (`-debug-matching`) |
| Deployment: patterns in binary | Yes | Yes | **Yes (boot mode)** |

### How DDR works

The `define-conversion-pattern` macro runs a four-phase pipeline at Chez
expansion time:

1. **Parse** — walks the syntax and builds an `ast-pattern-expand` record tree.
   Operand chains are flattened to `ast-operand` records tagged `required`,
   `optional`, or `variadic`. The `:rewrite` body is kept as raw syntax.

2. **Validate** — normalizes and checks semantic rules: `%`-prefixed result
   names, no duplicate bindings, root variable present. Caches
   `root-op-index`, `root-result-idx`, and `root-op-name` to avoid
   re-traversal in later phases.

3. **Analyze** — topological DAG traversal from the root, producing a flat
   action sequence: `:set-current-op`, `:check-op`, `:bind-operand`,
   `:check-eq` (for DAG diamonds where a result is shared by multiple ops).

4. **Codegen** — translates the action list to an `(and check₀ check₁ …)`
   expression wrapped in a `guard`, producing a Scheme lambda with the
   signature expected by `mlir::ConversionPattern::matchAndRewrite`.

The `:rewrite` body is compiled by a separate `with-mlir-ops` macro that
translates a flat sequence of named SSA op-forms into a `let*` of builder
calls.

Debug flags (`:debug-parse`, `:debug-validate`, `:debug-analyze`,
`:debug-codegen`, `:debug-matching`) allow inspecting each phase's output
without leaving the `.sls` file.

---

## Layer 3 — Domain helpers (`scheme/mlir/hip/`, `scheme/mlir/dialects/`)

Pure Scheme libraries built on top of Layer 1. `(mlir hip fusion)` implements
quantization-aware fusion predicates (tolerance comparison, layout detection)
and op constructors used by multiple hip-fusion patterns. Dialect libraries
(`hipsr`, `tensor`, `func`, etc.) provide named constructors for each op so
patterns read as domain logic, not raw builder calls.

---

## Layer 4 — Pass entry points (`samples/passes/`)

Each pass is a single `.sls` file that:
1. Imports DDR pattern definitions and domain helpers
2. Creates a `RewritePatternSet` or `ConversionTarget`
3. Registers patterns and calls `mlir-apply-patterns-greedy` or
   `mlir-apply-full-conversion`

Pass files are the user-facing extension point. A downstream project adds its
own `.sls` pass files and points `CREST_PATH` at their directory — no C++
required for a new pass.

---

## Deployment

### Development mode (default)

The interpreter loads `.sls` files from the source tree at runtime via
`library-directories`. Edit a `.sls` file and re-run — no rebuild.
`CREST_PATH` (a colon-separated env var analogous to `PATH`) adds additional
Scheme library directories, e.g. for downstream passes not in the crest tree.

### Boot mode (`-DCREST_EMBED_SCHEME_BOOT=ON`)

All `.sls` files are compiled at CMake build time into a single `crest.boot`
and embedded in the binary as a C byte-array. The deployed binary requires no
`.sls` files at runtime. The `CREST_PATH` env var still works in boot mode for
libraries not included in the boot.

Boot compilation uses Chez's `compile-imported-libraries` with
`library-directories` set as `(source . obj-dir)` pairs, so compiled `.so`
files land in the CMake build tree — never in the source tree.

Downstream projects can extend the boot before `add_subdirectory(crest)`:

```cmake
list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-pass.sls")
add_subdirectory(crest)
```

---

## Operational costs

**FFI maintenance burden.** Each MLIR API function used from Scheme requires a
C++ registration (`Sregister_symbol`) and a Scheme `foreign-procedure`
declaration. The `foreign-entry?` dynamic dispatch mitigates this for attribute
types; everything else is a manual pairing. This is a real but bounded cost.

**Version coupling.** In development mode, `.sls` files must be
version-matched to the binary. A mismatch produces a runtime failure. Boot
mode eliminates this at the cost of a build step.
