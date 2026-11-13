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
7. [`define-dialect` reference](#7-define-dialect-reference)
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

DRR generates only `RewritePattern` subclasses. PDLL patterns can run in a dialect conversion through `PDLConversionConfig` (MLIR built with `MLIR_ENABLE_PDL_IN_PATTERNMATCH`), but their constraints and non-trivial rewrites are native C++. CREST writes the whole conversion pattern in Scheme.

### Edit–reload cycle

In development mode (the default), pattern `.sls` files are loaded at runtime
from directories listed in `CREST_PATH`. Edit a `.sls` file and re-run — no
rebuild required.

```bash
export CREST_PATH=/my-project/passes:/path/to/crest/samples
build/tools/crest-opt/crest-opt --crest-pass="passes=passes/my-pass" input.mlir
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
    init   = tensor.empty () -> !out-type
    result = hip.qadd (%ctx %lhs %rhs init)
             (lhs_scale    : lhs-scale)
             (output_scale : out-scale)
             (lhs_zp       : lhs-zp)
             -> !out-type)
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

The four parameters after the name map to [`matchAndRewrite(Operation* op, ArrayRef<Value> operands, ConversionPatternRewriter& rewriter)`](https://mlir.llvm.org/doxygen/classmlir_1_1ConversionPattern.html#a4e9e0cb68cd4d6f30b1b02b1f3d1e5a3).
`operands-ref` carries the type-converted operands; read them with `crest::CArrayRef::size` and
`crest::CArrayRef::at` from `(crest support array-ref)`: `(crest::CArrayRef::at operands-ref 0)` is the first
operand.

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

- `operand-list` — positional operands; each must be a bound `%var` or `_` (wildcard, discards).

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
  - **`(:attr "name")`** — fetches the named attribute from `:current-op`; answers `#f` if the op has none (use `(:has-attr? "name")` or `(:attr-or "name" default)` when the attribute is optional).

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

### Wildcard `_`

`_` matches without binding a name, in both operand and result position.
Every `_` occurrence is independent — two `_` in different positions are
never treated as a shared value.

**Operand wildcard** — skip operands that are irrelevant to the rewrite:

```scheme
;; Match hip.quantize_linear but ignore the axis and init operands
%q = hip.quantize_linear (%ctx %sum %scale _ _)
```

**Result wildcard** — bind only the results you need from a multi-result op:

```scheme
;; Match test.split but only use its second result
(_ %second) = test.split (%x)
%out         = test.use   (%second)
```

Note: two `_` in different ops are **not** a diamond — they match
independently even if the underlying SSA values differ:

```scheme
%left  = test.add (%x _)   ; _ matches any value
%right = test.sub (%y _)   ; this _ is unrelated to the one above
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
  init   = tensor.empty () -> !out-type
  result = hip.qadd (%ctx %lhs %rhs init)
           (lhs_scale : lhs-scale)
           -> !out-type
```

Before emission starts, the insertion point is set to immediately before the
root op (equivalent to
[`setInsertionPoint(op)`](https://mlir.llvm.org/doxygen/classmlir_1_1OpBuilder.html#a3c5f7fcaf5c4db5a7b3db573e3e14f2f))
so new ops appear in place of the matched subgraph. The last emitted op's
result replaces `%root` in all uses.

A root with no result has no `%var` to name it, so it is written `op`, the pattern's first
parameter (`:rewrite op :with`). Nothing replaces it: after the new ops are emitted the old op is
erased.

Op-form syntax — see [§5 `begin-mlir-code`](#5-begin-mlir-code) for the full reference.

---

## 5. `begin-mlir-code`

`begin-mlir-code` emits MLIR ops with the **ambient builder**: the builder shell held by
`current-OpBuilder`, either a `CrestBox<OpBuilder>` or the pattern's `CrestBox<RewriterBase*>`. Its argument list is a **flat
sequence** — no builder argument and no outer parentheses around op-forms.
This mirrors MLIR's textual format, which MLIR C++ developers will find familiar.

```scheme
(begin-mlir-code
  i64 = (mlir::IntegerType::get<i64>)
  c0  = arith.constant () (value : 0 :i64) -> i64
  ty  = (mlir::Value::getType %a)
  sum = arith.addi (%a %b) -> ty)
```

### Supplying the builder

Inside `:rewrite :with` bodies and `^bb` block bodies the builder is already installed:
the pattern's rewriter at the `:rewrite :with` level. A `^bb` body keeps the same object and
moves its insertion point to the end of the new block, restoring it afterwards. A Scheme helper called from those bodies can therefore call `begin-mlir-code`
directly, with no builder parameter:

```scheme
(define (%%emit-pair v ty)                 ; called from a :rewrite :with body
  (begin-mlir-code
    a = test.step_a (v) -> ty
    b = test.step_b (a) -> ty))
```

Anywhere else, install a builder for the dynamic extent with `with-current-OpBuilder`.
The builder is a shell:

```scheme
;; A pattern's rewriter `rw` is a CrestBox<RewriterBase*> shell: install it as it is.
(with-current-OpBuilder rw
  (mlir::RewriterBase::setInsertionPoint rw op)
  (begin-mlir-code
    r = my.op (v) -> ty))

;; A builder you create yourself: with-OpBuilder binds the shell and frees it on
;; exit; with-current-OpBuilder installs it.
(with-OpBuilder b (mlir::OpBuilder::atBlockEnd block)
  (with-current-OpBuilder b
    (begin-mlir-code
      r = my.op (v) -> ty)))
```

With no builder installed, `begin-mlir-code` raises `no active builder` when it creates its
first op. There is no explicit builder argument: to use a particular builder, install it with
`with-current-OpBuilder` as above. A builder written as the first argument is not a builder; it
is evaluated like any other expression and ignored.

Every emitted op carries a `FileLineColLoc` from the `.sls` source line.

### Op-form syntax

The argument list is **flat** — op boundaries are detected automatically.
An op-form starts at a recognizable boundary pattern:

```
result-var = dialect.op-name (operands...) modifiers... -> result-type
(r0 r1) = dialect.op-name (operands...) modifiers... -> (type0 type1)
result-var = dialect.op-name (operands...) modifiers...        ; result types inferred, see below
dialect.op-name (operands...) modifiers...
```

The `-> result-type` can be left out when the op implements `mlir::InferTypeOpInterface`
(a C++ op such as `arith.addi`, checked in `test/dsl/op-builders/cxx-ops.mlir`, or an op of a Scheme dialect, see
[Op-level `:interfaces`](#op-level-interfaces)): the types come from the operands and attributes
given to the op-form, as `builder.create<AddOp>(loc, lhs, rhs)` gets them in C++. The regions are
not there yet: an op-form fills them after the op exists, so an op whose inference reads them
(`scf.if`) needs its `-> type`, as the `scf::IfOp` builders of C++ take the result types; the error
says so (`test/dsl/op-builders/regions.mlir`). An explicit `->` is used as written. Leaving it out for an op that is not registered, or does not
implement the interface, raises `no result type for <op>: ... write -> type`; an error that the
op's own `inferReturnTypes` raises is part of the message.

Op names contain `.` (e.g. `arith.constant`, `toy.func`). Result vars do not.
Any parenthesized item that doesn't match an op-form pattern is a Scheme expression.

**Key design**: op-forms are NOT wrapped in their own `()` — the flat argument
list is scanned left-to-right and op boundaries are detected syntactically.

### Scheme expressions and the value of the form

```scheme
(begin-mlir-code
  elem    = test.load (v) -> ty
  stepped = (%%step elem ty)        ; bind the value of a Scheme expression
  (log stepped)                     ; run for effect; the value is dropped
  next    = test.use (stepped) -> ty)
```

- `var = (expr)` binds `var` to the value of `expr`. Later items can use it as an operand, in
  a `-> var` result type, or in any other expression.
- A bare `(expr)` runs for effect and its value is dropped, unless it is the last item.
- The value of `begin-mlir-code` is the value of its **last item**, like Scheme's `begin`:
  an op-form with results gives the result `Value` (the last one for `(a b) = ...`), an op-form
  with no results gives the `Operation*`, and an expression gives its own value.

### Special forms

Two special forms are available anywhere inside `begin-mlir-code`:

**`:builder`** — the ambient builder, i.e. `(current-OpBuilder)`: the builder shell (the
pattern's rewriter, in `:rewrite :with` and in `^bb` bodies).
Use it to pass the builder to a Scheme helper that calls a typed binding such as
`mlir::LLVM::CallOp::create`; a helper that only calls `begin-mlir-code` needs no builder
parameter. **Not** an MLIR operand (builders are not `mlir::Value`s):

```scheme
;; Pass to a Scheme helper that emits further ops using the active builder
(%%emit-prologue :builder loc)
```

**`(:arg N)`** — shorthand for `(mlir::Block::getArgument (current-Block) N)`.
Only valid inside a `^bb0 ,@types` dynamic block body where `current-Block`
is installed.

### Location override

**`:loc loc-expr`** — op-level modifier that overrides the automatically-derived
Scheme source location with a runtime `mlir::Location` value. It is a bare keyword followed
by one expression (not parenthesised). Place it among the modifiers, between the operand
list and the `->` (by convention, at the end):

```scheme
;; Without :loc — op carries the .sls file:line:col from the begin-mlir-code form
r = toy.constant () (value : attr) -> !t

;; With :loc — op carries the Toy AST source location instead
r = toy.constant () (value : attr) :loc toy-loc -> !t

;; Inline shorthand for a file:line:column location
r = toy.constant () (value : attr) :loc ("example.toy" 7 3) -> !t

;; Useful in codegen from a parsed AST to carry source-language locations:
(begin-mlir-code
  toy.func ()
    (sym_name : name :string)
    (^bb0 ,@arg-types
      ...)
    :loc proto-loc)        ; ← mlir::FileLineColLoc from the Toy prototype
```

### Attributes

Attributes use `(name : val)` syntax where `name` is the attribute name
(as a symbol or string) and `val` is any Scheme expression returning an `mlir::Attribute`.
Common types have shorthands that construct the attribute automatically:

| Shorthand | Expands to |
|---|---|
| `(name : val :string)` | `mlir::StringAttr::get` |
| `(name : val :index)` | `mlir::IntegerAttr::get<index>` |
| `(name : val :i8)` | `mlir::IntegerAttr::get<i8>` |
| `(name : val :i16)` | `mlir::IntegerAttr::get<i16>` |
| `(name : val :i32)` | `mlir::IntegerAttr::get<i32>` |
| `(name : val :i64)` | `mlir::IntegerAttr::get<i64>` |
| `(name : val :f32)` | `mlir::FloatAttr::get<f32>` |
| `(name : val :f64)` | `mlir::FloatAttr::get<f64>` |
| `(name : val :i8-array)` | `mlir::DenseI8ArrayAttr::get` |
| `(name : val :i16-array)` | `mlir::DenseI16ArrayAttr::get` |
| `(name : val :i32-array)` | `mlir::DenseI32ArrayAttr::get` |
| `(name : val :i64-array)` | `mlir::DenseI64ArrayAttr::get` |
| `(name : val :unit)` | `mlir::UnitAttr::get` (val ignored) |

```scheme
;; Shorthand: keyword tag constructs the attribute automatically
idx = (mlir::IndexType::get)
c = arith.constant ()
    (value : 42 :index)
    -> idx

;; Array shorthands take a Scheme list or vector; val is evaluated, so quote a literal list
(shapes : '(1 2 3) :i64-array)

;; General form: val is any Scheme expression returning an mlir::Attribute
my.op ()
  (scale : (mlir::FloatAttr::get<f32> 0.5))
  (zp    : (mlir::IntegerAttr::get<i64> 0))
```

### Result types

`-> !type` where `!type` is a Scheme variable or a literal holding an `mlir::Type`. A
parenthesised form after `->` is always a **list of types**, one expression per element, so
`-> (mlir::IndexType::get)` is a one-element list holding the procedure, not a call, and fails when
the op is created. To use a call as the type, bind it first with `var = (expr)` or `let`.
Multi-result ops list all types in `(...)`:

```scheme
;; Single result
r = my.op (%x) -> !out-type
;; Multi-result — one -> per result type
(r0 r1) = my.op (%x) -> !type-a -> !type-b
```

### Regions

Region modifiers immediately follow the operand list (and any attribute modifiers).
Each `(^label ...)` form creates one region with one block:

```scheme
;; Single region, single block with static arguments
op = my.region_op (%x)
     (^bb0 ((arg0 : !i32) (arg1 : !i32))
           r = arith.addi (%arg0 %arg1) -> !i32
           my.yield (%r))
     -> !i32
```

Multiple single-block regions — list `^bb` shorthands consecutively
(each shorthand creates exactly one region with one block):

```scheme
;; Two regions (e.g. scf.if: then-region and else-region)
op = scf.if (%cond)
     (^then ()
            a = compute_a (%x) -> !i32
            scf.yield (%a))
     (^else ()
            b = compute_b (%y) -> !i32
            scf.yield (%b))
     -> !i32
```

One region with multiple blocks — use the explicit `:region` wrapper:

```scheme
op = my.op ()
     (:region
       (^entry ()
               cf.br () ^exit)
       (^exit ((v : !i32))
              cf.return (%v)))
     -> !i32
```

Multiple regions each with multiple blocks — use multiple `:region` wrappers:

```scheme
op = my.op ()
     (:region
       (^r0-entry () cf.br () ^r0-exit)
       (^r0-exit  () my.yield ()))
     (:region
       (^r1-entry () cf.br () ^r1-exit)
       (^r1-exit  () my.yield ()))
     -> !i32
```

To keep the body of an existing op instead of building one, use `:move-region`:

```scheme
:rewrite op :with
  func.func ()
    (sym_name : (mlir::Operation::getAttr op "sym_name"))
    (:move-region op)          ; region 0 of op; (:move-region op 1) is region 1
```

`(:move-region src-op [idx])` takes any expression that yields an operation, and `idx` defaults
to 0. It reserves a region slot like `(^bb ...)`, so the order among region modifiers is kept.
After the new op is created, the blocks of region `idx` of `src-op` are moved into the slot with
the pattern's `mlir::RewriterBase::inlineRegionBefore`; the block arguments and ops are the same
ones, not copies. It needs the pattern's rewriter: if the ambient builder is a plain `OpBuilder`
(installed by hand with `with-current-OpBuilder`), it raises an error that says so.

The move leaves the source region empty. That is fine when `src-op` is erased afterwards, which
is the op the pattern replaces. Taking the region of an op that stays, when that op requires its
region (`func.func`, `scf.for`, ...), makes it invalid, and the verifier reports it at the end
of the pass. This is the user's responsibility, as it is when the move is written by hand. The
feature is meant for an isolated destination such as `func.func` or `gpu.func`, whose body uses
only its own arguments. For a destination that is not isolated, values the body captures from
outside must still be in scope, and the terminators must still match the new op; the move does
neither. Block-argument types are not converted either.

In summary:

| Form | Regions | Blocks per region | Block args |
|---|---|---|---|
| `(^bb ...)` | 1 | 1 | static |
| `(^bb ...) (^bb ...)` | N | 1 each | static |
| `(^bb ,@types ...)`  | 1 | 1 | dynamic |
| `(:region (^a ...) (^b ...))` | 1 | N | static |
| `(:region ...) (:region ...)` | N | N each | static |
| `(:move-region src-op [idx])` | 1 | those of the source region | the source's |

The body of every `^label` block is a recursive `begin-mlir-code` call — the
same flat op-form syntax. Regions can be nested arbitrarily deep.
See `samples/passes/onnx-to-hipsr/matmul.sls` for a real-world example.

### Dynamic block arguments

When the number or types of block arguments are not known at compile time,
use `,@types-expr` to splice a runtime list of `mlir::Type` values:

```scheme
;; arg-types is a Scheme list of mlir::Type values computed at match time
fn = my.func ()
     (^bb0 ,@arg-types
       ;; (:arg N) is shorthand for the Nth block argument
       r = arith.addi ((:arg 0) (:arg 1)) -> !i32
       my.return (%r))
     -> !i32
```

The `,@` prefix is Chez Scheme's unquote-splicing — a visual marker that this
list is computed at runtime rather than fixed at compile time.

The block body is a recursive `begin-mlir-code` call — the same op-form
syntax is available (nested regions, attribute shorthands, multi-result
ops, etc.) with the same builder as the ambient builder, its insertion point moved to the end of the
new block.

Inside the block body, **`(:arg N)`** is a shorthand for
`(mlir::Block::getArgument (current-Block) N)` where `current-Block` is a
dynamic parameter installed by the `^label ,@...` form.

```scheme
;; Concrete example: rewrite test.copy(%v) → test.with_block(%v) where
;; the block arg type is determined at runtime from %v's type.
(define-rewrite-pattern (%%pattern op rewriter)
  :if-match
    %out = test.copy (%v)
  :then-let
    ([!vtype   (mlir::Value::getType %v)]
     [arg-types (list !vtype)])
  :rewrite %out :with
    result = test.with_block (%v)
             (^bb0 ,@arg-types
               my.yield ((:arg 0)))     ; (:arg 0) → first block argument
             -> !vtype
```

Use dynamic block args when generating functions whose argument lists vary
(e.g. lowering to `func.func` from an AST), and static `((arg : type) ...)`
when the count and types are fixed.

---

## 6. Pass entry points

A pass is an ordinary R6RS `library` that exports `pass-entry-point`, which
`(define-pass-entry-point (op) body ...)` defines: `pass-entry-point` is the name that
`--crest-pass="passes=passes/my-pass"` calls at runtime. An error of the body becomes an error on the module, with
its Scheme position in the text, and the pass fails. Everything else in the library is plain Scheme: helper
functions, type predicates, constants.

### Greedy rewrite pass

```scheme
(library (passes my-pass)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest)
          (passes my-pass patterns))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
          :patterns (("root.op-name" my-pattern 10)))))))
```

`apply-patterns` makes the `RewritePatternSet`, registers the patterns, runs the greedy driver on
the root op, frees the set, and returns `#t` on success or `#f` on failure. Keys, all optional:

| Key | Value |
|---|---|
| `:patterns` | A list of `(root-op-name pattern-fn [benefit])` entries. `root-op-name` is the op the pattern is dispatched on (e.g. `"hip.quantize_linear"`), `pattern-fn` is defined by `define-rewrite-pattern`, `benefit` is an integer (higher is tried first, default `1`) |
| `:populate` | A procedure of the pattern set, or a list of them; runs after `:patterns`. Use it to keep a table next to its patterns (see `define-pattern-set`) |

Mistakes in the form (unknown or repeated key, key without a value, malformed entry) are reported
when the library compiles.

`define-pattern-set` defines such a procedure from a table, so a library can export its patterns
and a pass can say `:populate`:

```scheme
(define-pattern-set my:patterns
  ("root.op-name" my-pattern 10)
  ("root.other"   other-pattern))

(apply-patterns module-op ctx :populate (list my:patterns))
```

`add-rewrite-pattern` (in `(mlir Transforms DialectConversion)`) is the underlying call, for code
that fills a set by hand inside `:populate` or `with-RewritePatternSet`.

### Dialect conversion pass

`apply-conversion` runs a dialect conversion from a declaration. It makes the `TypeConverter`,
the `ConversionTarget` and the `RewritePatternSet`, fills them, applies the conversion and frees
them, and returns `#t` on success or `#f` on failure:

```scheme
(library (passes my-conversion)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest)
          (passes my-conversion patterns))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
          :mode              partial
          :type-converter    (lambda (type) (if (tensor? type) (tensor->memref type) type))
          :legal-dialects    ("affine" "arith" "func" "memref" "builtin")
          :illegal-dialects  ("toy")
          :dynamically-legal (("toy.print" (lambda (op) (operand-is-memref? op))))
          :patterns          (("toy.constant" my-constant-pattern)
                              ("toy.add"      my-add-pattern 10)
                              ("toy.print"    my-print-pattern :no-type-converter))
          :populate          (lambda (tc patterns)
                               (populate-more-patterns tc patterns)))))))
```

Every key is optional.

| Key | Value | Meaning |
|---|---|---|
| `:mode` | `partial` or `full` | `applyPartialConversion` or `applyFullConversion`; default `full` |
| `:type-converter` | a procedure `(type) -> type or #f`, or `llvm` | added as a conversion callback of a new `TypeConverter`; `llvm` makes an `LLVMTypeConverter` instead |
| `:legal-dialects`, `:illegal-dialects`, `:legal-ops` | lists of names | `addLegalDialect`, `addIllegalDialect`, `addLegalOp` |
| `:dynamically-legal` | `((name predicate) ...)` | `addDynamicallyLegalOp`; the predicate gets the op |
| `:patterns` | `((name pattern [benefit] [:no-type-converter]) ...)` | one registration each; benefit defaults to 1; `:no-type-converter` registers the pattern so that it sees the original operand types |
| `:populate` | `(lambda (tc patterns) ...)` | called after `:patterns` with the type converter and the pattern set, for `populate…Patterns` calls |
| `:configure-type-converter` | a procedure `(lambda (tc) ...)` | called with the type converter after `:type-converter`, for setup helpers that take the converter |
| `:configure-target` | a procedure `(lambda (target tc) ...)` | called with the conversion target and the converter after the legal/illegal keys, for setup helpers that take the target |

A mistake in the form is reported when the library compiles, at the key. Names, benefits and
lambdas are ordinary expressions. The low-level pieces it is built from stay available from
`(mlir Transforms DialectConversion)`: `with-TypeConverter`, `with-ConversionTarget`,
`type-converter-add-conversion`, `target-add-legal-dialect`, `target-add-illegal-dialect`,
`target-add-legal-op`, `target-add-dynamically-legal-op`, `add-conversion-pattern`,
`add-conversion-pattern/ctx`, `mlir::applyPartialConversion` and `apply-full-conversion`.

`add-conversion-pattern`, `type-converter-add-conversion` and the other functions that register a callback take the
**address** of a C function, not a procedure: a procedure is an error that says how to make one.
Patterns made by `define-conversion-pattern` and `define-rewrite-pattern` already are such addresses. The
friendly way to give procedures is a clause of the macro that makes the C++ object, which makes the C
functions around its body and releases them after it, so running a conversion many times does not leak
(`test/dsl/callback-leaks`):

```scheme
(with-TypeConverter type-converter
    :conversions             ((lambda (type) type))
    :source-materializations ((lambda (builder type inputs loc) #f))
  (with-ConversionTarget target (ctx :dynamically-legal
                                     (("func.func"
                                       (lambda (op) (= 1 (type-converter-is-signature-legal type-converter op)))))
                                     :unknown-legal (lambda (op) #t))
    (with-RewritePatternSet patterns (ctx :conversion-patterns (("onnx.Cast" my-pattern type-converter 1))
                                          :rewrite-patterns (("test.rw" other-pattern 1)))
      (apply-full-conversion module-op target patterns))))
```

A callback that uses the type converter or the target is written inside these scopes, as the second entry
above uses `type-converter`, so the scope releases it. A pattern from `define-rewrite-pattern` or
`define-conversion-pattern` is a plain procedure, so it goes in a clause. `define-c-callable` from `(crest callback)`
is for a function that registers patterns and returns before they are applied (`add-rewrite-pattern`,
`add-conversion-pattern`): it needs the address of a C function that outlives the call, made once at the library level.

---

## 7. `define-dialect` reference

`define-dialect` is CREST's core abstraction for defining MLIR dialects entirely
in Scheme. A dialect definition declares its ops, their parse/print formats, type
predicates, interface implementations, and optional dialect-level callbacks — all
in one place, with no C++ code required.

### Minimal example

```scheme
(define-dialect toy
  (define-op constant
    :summary    "tensor constant from a dense attribute"
    :attributes ((value mlir::DenseElementsAttr))
    :results    ((output mlir::isa<RankedTensorType>?))
    (:parse (parser state)
      (let ([attr (mlir::OpAsmParser::parseAttribute parser state "value")])
        (and attr
             (begin (mlir::OperationState::addType
                      state (mlir::DenseElementsAttr::getType attr))
                    #t))))
    (:print (op printer name)
      (mlir::OpAsmPrinter::printString printer " ")
      (mlir::OpAsmPrinter::printAttribute
        printer (mlir::Operation::getAttr op "value")))))
```

`(define-dialect toy ...)` defines the dialect named `toy`. All ops become
available as `toy.op-name` in MLIR IR once the dialect is loaded into a context.

### `define-op` clauses

Each `(define-op name clause ...)` inside `define-dialect` defines one MLIR op.
The op's full MLIR name is `dialect-name.op-name` (e.g. `toy.constant`).

| Clause | Purpose |
|---|---|
| `:summary "text"` | Human-readable description (documentation only) |
| `:operands ((name predicate) ...)` | Operand fields — default `:required`; append `:optional` or `:variadic` to change cardinality: `(name predicate :optional)` |
| `:attributes ((name predicate) ...)` | Attribute fields — default `:required`; append `:optional` to allow absence: `(name predicate :optional)`; `:buildable-type :i64` (or `:i8 :i16 :i32 :f32 :f64 :index`) at the end gives the attribute the type an `:assembly-format` leaves out, see [`:assembly-format`](#assembly-format) |
| `:results ((name predicate) ...)` | Result fields; `predicate` is called on the result's `mlir::Type` uptr |
| `:assembly-format "format"` | The text form of the op as one ODS format string, see [`:assembly-format`](#assembly-format) |
| `(:parse (parser state) body ...)` | Custom assembly parser (not with `:assembly-format`) |
| `(:print (op printer name) body ...)` | Custom assembly printer (not with `:assembly-format`) |
| `(:verify (op) body ...)` | Extra verifier called after attribute/type checks |
| `(:fold (op operand-attributes) body ...)` | Folder: return `#f` (no fold), or a list with one entry per result, `(fold-value v)` for an existing value (usually an operand) or `(fold-attribute a)` for a constant the dialect's `:materialize-constant` turns into an op; `'()` means folded in place. `operand-attributes` has one entry per operand: its constant attribute, or `#f`. A `constant-like` op folds to its own value. The context is not installed in the callback: wrap attribute creation in `(with-current-MLIRContext (mlir::Operation::getContext op) ...)` |
| `(:get-canonicalization-patterns (patterns) body ...)` | The op's own canonicalization patterns (C++ `hasCanonicalizer`): `patterns` is the pattern set being filled, to which `add-rewrite-pattern` (or a `define-pattern-set` procedure) adds patterns; MLIR's canonicalizer pass finds them without the tool registering anything |
| `:traits (name ...)` | MLIR traits of the op (needs LLVM 23; see below) |

The callbacks of an op are made into C functions once, when the library of the dialect is loaded, and
every context that loads the dialect shares them. A `:verify`, `:verify-regions` or `:parse` that raises a
Scheme error does not end the process: it fails and the diagnostic has the text of the error. So does a
`:fold` that answers something that `fold-value` and `fold-attribute` did not make (the message says so).
A `:fold` that answers `'()` has changed the op in place.

**Type predicates** in `:operands`, `:attributes`, `:results` are Scheme
procedures called at verification time. For example:
- `:results ((output mlir::isa<RankedTensorType>?))` — result must be ranked
- `:operands ((lhs mlir::Value))` — any non-null value (`mlir::Value` is `(lambda (v) (not (zero? v)))`)

### `define-pass` — passes written in Scheme

```scheme
(define-pass (tag-functions op)       ; defines (tag-functions), which makes a new pass each call
  (mlir::Operation::setAttr! op "tagged" (mlir::StringAttr::get (mlir::Operation::getContext op) "yes"))
  #t)                                 ; #f fails the pass

(with-PassManager pm (ctx)
  (mlir::OpPassManager::addPass (mlir::PassManager::nest pm "func.func") (tag-functions))
  (mlir::PassManager::run! pm module-op))
```

`op` is the operation the pass runs on (the `PassManager` decides: nested on `func.func` it runs on each
function); the body returns `#f` to fail the pass, after saying why with `mlir::Operation::emitError`. The
pass is an `mlir::Pass` (`lib/Crest/SchemePass.cpp`), so it mixes with C++ passes in one pipeline. Scheme
is single-threaded: contexts made from Scheme have multithreading disabled; with `crest-opt` use
`--mlir-disable-threading`. A body that raises a Scheme error does not end the process: the pass fails and
the diagnostic has the text of the error. The body is made into a C function once, where the pass is defined,
and every pass that `(tag-functions)` makes shares it. Toy's shape inference and its lowerings to affine and
LLVM are passes.

### `define-type` — dialect types

A dialect can define types of its own with `define-type` next to its ops. A type has a name and a list
of *attribute* parameters (a type parameter is a `TypeAttr`); it is built on MLIR's
`DynamicTypeDefinition`, so it works on LLVM 22 and 23 and needs no C++:

```scheme
(define-dialect toy
  (define-type struct
    (:verify (params) ...)          ; #t, #f, or an error message string; optional
    (:parse (parser) ...)           ; after the name: the list of parameter attributes, or #f
    (:print (printer params) ...))) ; after the name; :parse and :print come together, or neither
```

`!toy.struct<tensor<2xf64>, tensor<3xf64>>` is printed as the name followed by what `:print` writes (here
`<...>`). A `:verify` that says `#f` gives MLIR's message ("invalid type parameters"), and one that raises a
Scheme error gives the text of the error, as does a `:parse`. Without `:parse`/`:print` the generic
`<attr, ...>` syntax is used. The dialect generates
`(toy.struct? type)`, `(toy.struct ctx params)` (the type, or 0 when `:verify` rejects the parameters, after
emitting its message) and `(toy.struct-params type)`.

### `:assembly-format`

`:assembly-format` gives the text form of an op as one string in the syntax of TableGen's declarative
assembly format (MLIR's `Operations.md`, "Declarative Assembly Format"), and generates the `:parse` and
`:print` callbacks from it. Toy declares `toy.print` as in the C++ tutorial's `Ops.td`:

```scheme
(define-op print
  :operands   ((input %%f64-tensor-or-memref-value?))
  :assembly-format "$input attr-dict `:` type($input)")      ; toy.print %0 : tensor<2x3xf64>
```

| Element | Meaning |
|---|---|
| `` `:` `` `` `,` `` `` `(` `` `` `)` `` `` `<` `` `` `>` `` `` `[` `` `` `]` `` `` `->` `` and `` `keyword` `` | a literal |
| `$name` | an operand (required, optional or variadic) or an attribute of the op |
| `type($x)` | the type of an operand or of a result |
| `type(results)` | the types of all results, comma separated |
| `functional-type(operands, results)` | `(operand types) -> result types`; `($inputs, results)` when `$inputs` is the op's only operand |
| `operands` | all operands (the types then come from `functional-type`) |
| `attr-dict` | the attributes no `$attribute` printed, as `{...}` |
| `( elements )?` | an optional group: it is there if its first element, the *anchor* `$x^` (an optional operand), is |

The rules are those of ODS: `attr-dict`, every operand with its type and every result type appear once. A
lone optional or variadic operand needs no `operandSegmentSizes` attribute (it takes the operands the
required ones leave). The printed spacing is that of `mlir-tblgen` (`OpFormatGen.cpp`): a space between
elements except around `(`, `)`, `[`, `]`, `<`, `>` and `,`, so a format prints what its C++ twin prints.
Mistakes in the string are reported when the library compiles, with the column.

**Result types left out.** An op that has `mlir::InferTypeOpInterface` in its `:interfaces` may leave every
result type out of the format: the parser asks the interface for them once the operands and attributes are
in, and the printer prints none (`%0 = inf.add %a, %b : i32, i32` has the type of `%a`). Some result types in
the format and some not is an error; so is leaving them all out in an op without the interface
(`test/dsl/assembly-format-infer`).

**Attributes with a buildable type.** ODS knows the type of an `I64Attr`, so it prints `[1]` and parses `1` as
an `i64`. An attribute field says the same with `:buildable-type` and one of `:i8 :i16 :i32 :i64 :f32 :f64
:index`:

```scheme
:attributes ((index %%integer-attr? :buildable-type :i64))   ; $index prints [1] and parses as 1 : i64
```

As in C++, a text that still writes the type (`[1 : i64]`) is not accepted; the generic form is how a typed
attribute is written. A field with `:buildable-type` in an op that has no `:assembly-format` is an error
(`test/dsl/assembly-format-typed-attr`).

Not in the first version, each reported as such: the literals `=` `{` `}` `?` `+` `*`, `custom<...>`,
`prop-dict`, `regions`, `successors`, `oilist`, `qualified`, `attr-dict-with-keyword`, `type(operands)`, `else`
groups, optional attributes, an optional operand outside a group (it is the first element of one), a group whose
first element is not an optional operand, result types inside a group or inferred from traits (they are inferred
only through `InferTypeOpInterface`, all or none), and more than one optional or variadic operand. An op that needs
them keeps a hand-written `:parse` and `:print`, as `toy.add` and `toy.func` do.

### Op traits

`:traits (name ...)` attaches MLIR traits to the op through `DynamicOpDefinition::addTrait`, so the
verifier and passes see them. A trait with arguments is a list: `(has-parent "toy.func")`. The names are
CREST's, in one table in `lib/Crest/Trait.cpp`:

| Name | Meaning |
|---|---|
| `terminator`, `no-terminator` | the op ends a block / its regions need no terminator |
| `commutative`, `constant-like` | the MLIR traits of the same name (`constant-like` is only useful with a `:fold` that returns the value) |
| `zero-operands`, `zero-results`, `zero-regions` | verified |
| `same-operands-and-result-type`, `same-operands-and-result-shape` | verified |
| `isolated-from-above` | a region of the op may not use values defined outside it (verified) |
| `(has-parent "op.name" ...)` | the parent op must be one of the names (verified, with MLIR's message). MLIR's own `HasParent` is a template on the parent class, so `hasTrait<HasParent<...>>` is false for a Scheme op |
| `pure` | no memory effects and speculatable: attaches `AlwaysSpeculatableImplTrait` and the `MemoryEffectOpInterface` (no effects) and `ConditionallySpeculatable` (speculatable) interfaces, which is what the canonicalizer's dead-code removal, CSE and `isPure` ask |

A non-list value is reported when the library compiles; an unknown or repeated name, or wrong arguments,
when the dialect loads. Before LLVM 23 `addTrait` does not exist, and a dialect that asks for a trait fails
to load with a message saying so. The two interfaces behind `pure` can also be listed by hand in
`:interfaces` (`mlir::MemoryEffectOpInterface`, `mlir::ConditionallySpeculatable`, from
`(mlir Interfaces SideEffectInterfaces)`). Passes that run on a dialect with Scheme callbacks (verifiers,
folders) must not run multithreaded: pass `--mlir-disable-threading` to `crest-opt`.

### Op-level `:interfaces`

An op can implement MLIR op interfaces (like `FunctionOpInterface`) by listing
them in the `:interfaces` clause of `define-op`. Each entry is `(interface-name method-clause ...)`, and each
method clause is `(method-name (formals) body ...)`, where the first formal is the op. The interfaces are part of
the definition of the op: they exist in a context that loads the dialect (`op->getName().hasInterface<...>()` is
true there), and in no other.

**CREST has no default for an interface.** In C++ the op class gives the methods of its interfaces, and a Scheme op
has no class, so the op gives them as clauses. Where MLIR has a default for a method (the `Trait` of the interface
has one), an op that does not give the clause gets MLIR's default, and the macro of the interface writes it in
Scheme (`scheme/mlir/Interfaces/*.sls`), so nothing hides in C++. For a method that Scheme cannot implement (an
answer that is a `MutableOperandRange`, or a use range of a symbol) CREST ships a C function, and a clause names it
with a keyword. The clauses are checked when the library compiles: a missing clause, a clause for a method that the
interface does not have, two clauses for one method and a clause with the wrong number of arguments are errors.

| Interface | The op gives | MLIR's default, if the op gives none | The op also declares |
|---|---|---|---|
| `CallableOpInterface` | `getCallableRegion`, `getArgumentTypes`, `getResultTypes` | | `ArgAndResultAttrsOpInterface` |
| `FunctionOpInterface` | `getFunctionType`, `setFunctionTypeAttr` | `cloneTypeWith`, `verifyBody` (the entry block matches the function type), `verifyType` | `SymbolOpInterface`, `CallableOpInterface`, `ArgAndResultAttrsOpInterface` |
| `CallOpInterface` | `getCallableForCallee`, `setCalleeFromCallable`, `getArgOperands`, `getArgOperandsMutable` (`:all-operands`) | `resolveCallable`, `resolveCallableInTable` (a symbol lookup) | `ArgAndResultAttrsOpInterface` |
| `ArgAndResultAttrsOpInterface` | the six methods, or `:standard` (the `arg_attrs` and `res_attrs` attributes) | | |
| `SymbolOpInterface` | nothing | all sixteen: `sym_name`, `sym_visibility`, the uses of `SymbolTable` | |
| `MemoryEffectOpInterface` | `getEffects` (`:none`: no effects) | | |
| `ConditionallySpeculatable` | `getSpeculatability` (`:always`, or 0, 1, 2) | | |
| `InferTypeOpInterface` | `inferReturnTypes` | `refineReturnTypes`, `isCompatibleReturnTypes` | |

The trait `pure` gives an op `MemoryEffectOpInterface` with no effects and `ConditionallySpeculatable` with
`:always`; a clause for either interface replaces the answer. An op that declares an interface that extends another
declares the other too (the third column): an op that does not cannot be registered, and the error says which
(`test/dsl/interface-dsl/callable-clauses-errors.mlir`). A function op and a call op in full, as Toy writes them:

```scheme
(define-op func
  :summary "function definition"
  :interfaces ((mlir::SymbolOpInterface)
               (mlir::ArgAndResultAttrsOpInterface :standard)
               (mlir::CallableOpInterface
                (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                (getArgumentTypes (self)
                  (mlir::FunctionType::getInputs
                    (mlir::TypeAttr::getValue
                      (mlir::Operation::getAttr self "function_type"))))
                (getResultTypes (self)
                  (mlir::FunctionType::getResults
                    (mlir::TypeAttr::getValue
                      (mlir::Operation::getAttr self "function_type")))))
               (mlir::FunctionOpInterface
                (getFunctionType (self)
                  (mlir::TypeAttr::getValue
                    (mlir::Operation::getAttr self "function_type")))
                (setFunctionTypeAttr (self attr)
                  (mlir::Operation::setAttr! self "function_type" attr)))))

(define-op call
  :results    ((output mlir::Value?))
  :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
               (mlir::CallOpInterface
                (getCallableForCallee (self)
                  (mlir::CallInterfaceCallable::get<SymbolRefAttr>
                   (mlir::Operation::getAttr self "callee")))
                (setCalleeFromCallable (self callee)
                  (mlir::Operation::setAttr! self "callee"
                   (mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> callee)))
                (getArgOperands (self)
                  (crest::OperandRange::get self 0 (mlir::Operation::getNumOperands self)))
                (getArgOperandsMutable :all-operands))))
```

The clauses in more detail:

- `FunctionOpInterface`: `getFunctionType` answers the `Type`, `setFunctionTypeAttr (op attr)` gets a `TypeAttr`,
  `cloneTypeWith (op inputs results)` answers a `Type` (the two ranges are lists of `Type`s), and `verifyBody` and
  `verifyType` answer `#t` for success. An error that a verifier raises does not end the process: the verifier
  fails and the diagnostic carries the text of the error (`mlir::Operation::emitOpError`).
- `CallableOpInterface`: `getCallableRegion` answers the `Region`, `getArgumentTypes` and `getResultTypes` a list
  of `Type`s.
- `CallOpInterface`: a callee is a `CallInterfaceCallable`, a symbol reference or a value, as a number: make one
  with `mlir::CallInterfaceCallable::get<SymbolRefAttr>` or `get<Value>` and take it apart with `dyn_cast<...>`,
  which answers `#f` for the other kind. `getArgOperands` answers an operand range, made with
  `(crest::OperandRange::get op start count)`.
- `SymbolOpInterface`: the visibility is a number, 0 public, 1 private, 2 nested. The methods are callable on an op
  from Scheme: `mlir::SymbolOpInterface::getVisibility`, `isPrivate`, `setPrivate`, ... of
  `(mlir IR SymbolInterfaces)`.
- `MemoryEffectOpInterface` and `ConditionallySpeculatable`: 0 is not speculatable, 1 speculatable, 2 speculatable
  if the operations in its regions are.
- `InferTypeOpInterface` lets an op-form leave out `-> type` (see [§5](#5-begin-mlir-code)). `inferReturnTypes`
  gets the context, the location (or `#f`), the list of operand `Value`s and the alist of `(name . Attribute)`,
  and returns the list of result `Type`s (`#f` to say it cannot tell). `isCompatibleReturnTypes (inferred
  actual)` says whether the result types of the op fit what `inferReturnTypes` answered (two lists of `Type`s, a
  boolean); MLIR's default is that they are equal. `refineReturnTypes (context location operands attributes
  return-types)` gets the result types the op has and answers the types it may have (`#f` to refuse); MLIR's
  default checks that what `inferReturnTypes` answers is compatible with them, with an error at the location if
  not. Toy's `add`, `mul`, `transpose` and `constant` give the second: they infer `tensor<*xf64>` and shape
  inference makes the result ranked, so they say that any `f64` tensor fits, as the ODS ops of C++ that override
  `isCompatibleReturnTypes` do. CREST does not check the result types of an op against the interface when it
  verifies the op: a `:verify` that wants that calls the methods itself.

```scheme
(import (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

(define-op add
  :operands   ((lhs mlir::Value?) (rhs mlir::Value?))
  :results    ((out mlir::Value?))
  :interfaces ((mlir::InferTypeOpInterface
                (inferReturnTypes (context location operands attributes)
                  (list (mlir::Value::getType (car operands)))))))
```

With `FunctionOpInterface` on the function op, `CallOpInterface` on the call op, the dialect's
`DialectInlinerInterface` and a terminator (`:traits (terminator)`, LLVM 23), MLIR's own `--inline`
pass inlines calls in a Scheme dialect (`test/dsl/call-op-interface`).

The name of an interface in `:interfaces` is a macro that the dialect's library must import from the library of
the interface (`(mlir Interfaces FunctionInterfaces)`, `(mlir Interfaces CallInterfaces)`, `(mlir IR SymbolInterfaces)`,
`(mlir Interfaces SideEffectInterfaces)`, `(mlir Interfaces InferTypeOpInterface)`). It makes a C function for each
method with `foreign-callable` (`(crest interface)` and `(crest callback)`), once, when the library is loaded, and
answers the pair of the interface's `TypeID` (`mlir::FunctionOpInterface::getInterfaceID`, and so on) and a
dispatcher of those functions. When a context registers the op, C++ finds how to install the interface by the
`TypeID`, inserts `CrestModel<Interface>` (the `Concept` of the interface with every slot null) in the interface
map of the op's definition, and puts each function in its slot (`docs/tech-note.md`, "Interfaces of a Scheme
op"). MLIR then calls Scheme directly. This is what `MLIR`'s `--inline`, `dyn_cast` and `hasInterface` see, and what
C++ keeps instead of the Scheme procedure, as for everything else that C++ calls back into Scheme: the callbacks of
a dialect, of its ops and types, passes, and conversions (see
[Extending with custom C++ bindings](#11-extending-with-custom-c-bindings)). The dialect has to be loaded into the
context (`dialects-in-scheme=` or `--crest-scheme-dialect=` with an op in the input, or `load-scheme-dialect!`) for
MLIR to see the interfaces (`test/dsl/op-builders`, `unittests/Crest/InterfaceTest.cpp`). Platforms: Linux x86-64
and Windows x64 are tested; the prototype of each slot as a C function depends on the platform
(the types of `define-c-callable`), and arm64 is not tested.

### Dialect-level `:interfaces`

A dialect can implement MLIR dialect interfaces (like `mlir::DialectInlinerInterface`)
by placing an `:interfaces` clause directly inside `define-dialect`, before any
`define-op`:

```scheme
(define-dialect toy
  (:interfaces ((mlir::DialectInlinerInterface
                  ;; Required: all three isLegalToInline overloads
                  (isLegalToInline/call   (call callable wouldBeCloned) #t)
                  (isLegalToInline/region (dest src wouldBeCloned) #t)
                  (isLegalToInline/op     (op dest wouldBeCloned) #t)
                  ;; Optional: the terminator of a callee of one block. `replacements` is a
                  ;; CArrayRef of the Values that stand for the results of the call.
                  (handleTerminator/value (op replacements)
                    (do ([i 0 (+ i 1)])
                        ((= i (crest::CArrayRef::size replacements)))
                      (mlir::Value::replaceAllUsesWith
                        (crest::CArrayRef::at replacements i)
                        (mlir::Operation::getOperand op i))))
                  ;; Optional: the terminator of a block of a callee of more blocks
                  (handleTerminator/block (op new-dest) ...)
                  ;; Optional: insert a cast op at type-mismatched call boundaries
                  (materializeCallConversion (builder input result-type loc)
                    (with-OperationState (s loc "toy.cast")
                      (mlir::OperationState::addOperands s input)
                      (mlir::OperationState::addTypes s result-type)
                      (mlir::OpBuilder::create<OperationState> builder s))))))
  (define-op constant ...) ...)
```

The clause has the shape of the op-level `:interfaces`: entries `(interface-name method-clause ...)`,
whose name is a macro that the dialect's library must import
(`(only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface)`). The macro makes a C function with
`foreign-callable` for each clause, once, when the library is loaded, and answers the pair of the interface's
`TypeID` (`mlir::DialectInlinerInterface::getInterfaceID`) and a dispatcher of those functions. The expander
keeps the list of the dialect's pairs as slot 11 of the callbacks vector. When a context loads the dialect,
C++ gives it each interface through a table keyed by the `TypeID` (`lib/Crest/Dialect.cpp`), so a context
makes no callable of its own (`test/dsl/call-op-interface/inliner-leak.mlir`) and
`dialect->getRegisteredInterface<mlir::DialectInlinerInterface>()` finds it. `mlir::DialectInlinerInterface`
is the only dialect-level interface there is: another name loads with the error "no way to install an
interface of :interfaces". The clause is parsed as the op-level one is, and may appear more than once.

### Dialect-level callbacks

Less common hooks are placed as `(:keyword (formals) body ...)` clauses directly
inside `define-dialect`:

| Clause | C++ virtual | Use case |
|---|---|---|
| `(:parse-type (parser) body)` | `parseType` | Custom type assembly syntax |
| `(:print-type (type printer) body)` | `printType` | Custom type printing |
| `(:parse-attribute (parser type) body)` | `parseAttribute` | Custom attribute syntax |
| `(:print-attribute (attr printer) body)` | `printAttribute` | Custom attribute printing |
| `(:materialize-constant (builder value type loc) body)` | `materializeConstant` | Constant materialization |
| `(:get-canonicalization-patterns (pattern-set) body)` | `getCanonicalizationPatterns` | Dialect-wide canonicalization |
| `(:verify-op-attr (op attr) body)` | `verifyOperationAttribute` | Attribute attachment rules |
| `(:verify-region-arg-attr (op region-index arg-index attr) body)` | `verifyRegionArgAttribute` | Rules for an attribute of a block argument |
| `(:verify-region-result-attr (op region-index result-index attr) body)` | `verifyRegionResultAttribute` | Rules for an attribute of a function result |
| `(:get-dependent-dialects () body)` | the dialects loaded first | A list of dialect names (strings) to load before this one |
| `(:initialize (dialect) body)` | `initialize` | Runs once per context, after the dependencies |

A parse callback that fails answers `#f`. A verifier says yes with any value but `#f`; it reports its
own message (`mlir::Operation::emitError`) and answers `#f`. An error that a verifier raises does not end
the process: the verifier fails and the diagnostic has the text of the error. The callbacks are made
into C functions once, when the library of the dialect is loaded, and a context that loads the dialect
shares them (`test/dsl/dialect-callbacks`).

The verifiers of the attributes (`:verify-op-attr` and the two for a function's arguments and results)
get a `NamedAttribute`: `mlir::NamedAttribute::getName` answers its name (a `StringAttr`, read with
`mlir::StringAttr::getValue`), `mlir::NamedAttribute::getValue` its value, and `mlir::Attribute::print` the
text of an attribute, all of `(mlir IR Attributes)`. The `NamedAttribute` lives for the call of the verifier.

The printer that `:print-type` and `:print-attribute` get is a `DialectAsmPrinter`, an `mlir::AsmPrinter`.
`(mlir IR OpImplementation)` has its methods: `mlir::AsmPrinter::printType`, `printAttribute`,
`printKeywordOrString` (a keyword as it is, anything else quoted) and `printString` (quoted), and
`mlir::AsmPrinter::getStream`, whose stream takes raw text with `llvm::raw_ostream::write` of
`(llvm Support raw_ostream)`. A dialect type of `define-type` prints through `:print-type` when the dialect
has one (`test/dsl/dialect-callbacks/dialect-callback-print.mlir`: `!dcp.pair<i32, f32>` is parsed and
printed as `!dcp.pair<i32 & f32>`). MLIR keeps the pretty `!dialect.name<...>` form only when what the callback
printed after the dialect name is an identifier followed by `<...>`; anything else comes out as
`!dialect<...>`. `:print-attribute` is reached for an attribute of the dialect, and a Scheme dialect has none
(there is no `define-attribute`), so it has no test.

The `:populate-default-attrs` clause of an op gets the `OperationName` and the `NamedAttrList` that MLIR is
filling: `mlir::NamedAttrList::get` (0 when the list has no such attribute), `append` (adds one) and `set`
(replaces or adds), and `mlir::OperationName::getContext`, all of `(mlir IR OperationSupport)`
(`test/dsl/op-callbacks`).

### Loading the dialect

A dialect is loaded from Scheme via the `mlir::DialectRegistry`:

```scheme
;; Preferred: pre-register before MLIRContext is created (parser-safe)
(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert reg "toy" "toy/ch4/toy")
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::getOrLoadDialect ctx "toy")
    ...))
```

Or lazily via `crest::load-scheme-dialect!` after the context is created (safe
only when no ops of this dialect appear in input IR yet):

```scheme
(load-scheme-dialect! ctx "toy" "toy/ch4/toy")
```

### Parsing a file: who frees the module

`mlir::parseSourceFile` answers the module as a plain address. Nothing owns it, so it is never freed
unless the program erases it with `mlir::Operation::erase`. A program that parses once and exits does not
need to care. A program that parses many files, or runs in a loop, loses about one kilobyte per small
module. Use `with-mlir::OwningOpRef` of `(mlir IR OwningOpRef)`. It runs its body and
erases the module when the body ends, by returning, by an error or by an escape (it is built on the
generic `with-raii` of `(crest support RAII)`, which you can use for any resource that a function frees).
The name is the C++ class that owns the module, and the second part is the call that makes it:

```scheme
(with-mlir::OwningOpRef module (mlir::parseSourceFile ctx "input.mlir")
  (if (zero? module)                       ; 0: the file could not be parsed, the parser said why
      (display "cannot parse\n")
      (display (mlir::Operation::print module))))
```

Do not erase the module inside the body. It works for any operation that nothing else owns, as
`mlir::OwningOpRef` does in C++: the call can be any call that returns one, so a module that you build
(`mlir::ModuleOp::create`) can be given to the macro too.

A library that does not load (not found, an error in it or when it runs, or the dialect name not
exported) is reported when the dialect is registered, not when its first op is parsed:
`mlir::DialectRegistry::insert` and `load-scheme-dialect!` raise a Scheme error that names the library,
`crest-opt --crest-scheme-dialect=` prints `error: Failed to import Scheme library: <library>: <reason>` and
exits with status 1, and `--crest-pass="dialects-in-scheme=..."` reports it as a pass failure.

### Inspecting the expansion

```bash
DEBUG_DEFINE_DIALECT=1 \
CREST_PATH=samples \
  crest-opt /dev/null --crest-pass="passes=toy/ch4/toy" 2>/dev/null
```

Or use the helper script:

```bash
tools/debug-define-dialect samples/toy/ch4/toy.sls
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
  --crest-pass="passes=passes/hip-fusion" \
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

### `CREST_DEBUG_BEGIN_MLIR_CODE=<file>`

Set it to a file path to see what each `begin-mlir-code` form expands to. Every expansion is
appended to the file under a header with the form's source position, so a library with many
forms ends up in one file:

```bash
CREST_DEBUG_BEGIN_MLIR_CODE=/tmp/expanded.scm CREST_SCHEME_BINARY_DIR=$(mktemp -d) \
  CREST_PATH=$(pwd)/samples build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect --crest-pass="passes=passes/hip-fusion" test/hip-fusion/qadd.mlir
```

```
;; begin-mlir-code at /path/to/crest/samples/passes/hip-fusion/qadd.sls:96:7
(let* ([g0 (let ([g0 (with-OperationState g1
                       ((apply mlir::FileLineColLoc::get
                               '("/path/to/crest/samples/passes/hip-fusion/qadd.sls" 96 16))
                        "tensor.empty")
                       ...
                       (%%crest:create-op! (%%current-builder) g1))])
             g0)]
       [init (mlir::Operation::getResult g0 0)]
       ...
       [result (mlir::Operation::getResult g2 0)])
  result)
```

The block above is abridged. The dump is the `let*` that `begin-mlir-code` produces, with the op-creation code left as
`with-OperationState` and friends. The file is never truncated: delete it between runs.
The expansion happens when a library is compiled, so use a fresh `CREST_SCHEME_BINARY_DIR`
or a library that is not cached yet, or nothing is written.

### Source locations on emitted ops

Every op emitted by `begin-mlir-code` (inside `:rewrite :with`) carries a
`FileLineColLoc` pointing to the exact `.sls` line.

```bash
CREST_PATH=$(pwd)/samples \
  build/tools/crest-opt/crest-opt \
  -allow-unregistered-dialect \
  --crest-pass="passes=passes/onnx-to-hipsr" \
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

## 9. MLIR bindings reference

This section lists commonly used bindings. The set is not exhaustive — bindings
are added on demand as new MLIR APIs are needed. Library names mirror MLIR header
paths. Import only what you use.

### Context parameters

CREST uses Scheme dynamic parameters to thread C++ context pointers implicitly.
Each parameter follows the `current-<C++ClassName>` / `with-current-<C++ClassName>`
convention from CLAUDE.md Rules 10–11:

| Parameter | Macro | Defined in | Set by |
|---|---|---|---|
| `current-MLIRContext` | `with-current-MLIRContext` | `(mlir IR MLIRContext)` | user / `with-current-MLIRContext` |
| `current-Block` | `with-current-Block` | `(mlir IR Block)` | `^bb0` block bodies |
| `current-OpBuilder` | `with-current-OpBuilder` | `(mlir IR Builders)` | `:rewrite :with` and `^bb` bodies; user code via `with-current-OpBuilder` |

`current-OpBuilder` holds a builder shell: a `CrestBox<OpBuilder>` or the pattern's
`CrestBox<RewriterBase*>`. Every binding that takes a builder accepts either kind (and a
`CrestBox<OpBuilder*>` that MLIR passes to a callback): the Scheme side checks the shell's type
and calls the matching C++ symbol. Because the real rewriter is kept, rewriter-only operations (`replaceOp`,
`eraseOp`, `inlineRegionBefore`, ...) work on the same handle and reach the real rewriter,
including what the conversion rewriter overrides. `with-OpBuilder` creates a builder and binds
the shell; it does not install it (CLAUDE.md Rule 10) — wrap the body in `with-current-OpBuilder`
for that. `with-InsertionGuard` saves a builder's insertion point and restores it on exit.

`%%current-builder` (internal) is what `begin-mlir-code` uses to create each op: it returns
`(current-OpBuilder)` or raises `no active builder` if that is `#f`. `:builder` returns
`(current-OpBuilder)` as is.

The context hierarchy during a pattern rewrite:

```
:rewrite :with                → current-OpBuilder = rw (the pattern's rewriter shell)
  ^bb0 block body             → current-Block = block
                                current-OpBuilder = rw, insertion point at the end of block,
                                restored when the body ends
```

### Core IR

| Import | Key exports |
|---|---|
| `(mlir IR MLIRContext)` | `current-MLIRContext`, `with-current-MLIRContext`, `mlir::parseSourceFile` |
| `(mlir IR Operation)` | `mlir::Operation::getName`, `getResult`, `getRegion`, `getAttr`, `setAttr!`, `getContext`, `getNumResults`, `getNumOperands` |
| `(mlir IR Value)` | `mlir::Value::getType`, `getDefiningOp`, `getUses`, `mlir::OpResult::getResultNumber` |
| `(mlir IR Block)` | `mlir::Block::getArgument`, `getNumArguments`, `current-Block`, `with-current-Block` |
| `(mlir IR Region)` | `mlir::Region::front`, `getParentOp` |

### Types

| Import | Key exports |
|---|---|
| `(mlir IR BuiltinTypes)` | `mlir::IndexType::get`, `mlir::IntegerType::get<i64>`, `mlir::Float32Type::get`, `mlir::Float64Type::get`, `mlir::RankedTensorType::get`, `mlir::RankedTensorType::getShape`, `mlir::RankedTensorType::getRank`, `mlir::RankedTensorType::cloneWithEncoding` |

### Attributes

| Import | Key exports |
|---|---|
| `(mlir IR AffineMap)` | `mlir::AffineMap::get`, `mlir::AffineMap::getMultiDimIdentityMap`, `mlir::AffineMap::getConstantMap` |
| `(mlir IR AffineExpr)` | `mlir::getAffineDimExpr`, `mlir::getAffineSymbolExpr`, `mlir::getAffineConstantExpr`, `mlir::AffineExpr::operator+`, `operator-`, `operator*`, `floorDiv`, `ceilDiv`, `operator%`, `mlir::AffineExpr?` |
| `(mlir IR BuiltinAttributes)` | `mlir::IntegerAttr::get<i64>`, `mlir::AffineMapAttr::get`, `mlir::FloatAttr::get<f32>`, `mlir::StringAttr::get`, `mlir::DenseElementsAttr::isSplat`, `mlir::DenseElementsAttr::getSplatValue<APFloat>`, `mlir::DenseElementsAttr::getSplatValue<APInt>`, `mlir::DenseI32ArrayAttr::get`, `mlir::DenseI64ArrayAttr::get` |

### Builders

| Import | Key exports |
|---|---|
| `(mlir IR Builders)` | `mlir::OpBuilder::atBlockEnd`, `mlir::OpBuilder::create<OperationState>`, `mlir::OpBuilder::setInsertionPointToEnd`, `current-OpBuilder`, `with-current-OpBuilder`, `with-OpBuilder`, `with-InsertionGuard` |

### Pattern matching and rewriting

| Import | Key exports |
|---|---|
| `(mlir IR PatternMatch)` | `with-RewritePatternSet` |
| `(mlir Transforms GreedyPatternRewriteDriver)` | `mlir::applyPatternsGreedily` |
| `(mlir Transforms DialectConversion)` | `with-TypeConverter`, `with-ConversionTarget`, `type-converter-add-conversion`, `target-add-legal-dialect`, `target-add-illegal-dialect`, `target-add-legal-op`, `target-add-dynamically-legal-op`, `add-conversion-pattern`, `add-conversion-pattern/ctx`, `add-rewrite-pattern`, `apply-full-conversion`, `mlir::applyPartialConversion` |

### Location

| Import | Key exports |
|---|---|
| `(mlir IR Location)` | `mlir::UnknownLoc::get`, `mlir::FileLineColLoc::get` |

### CREST public API

```scheme
(import (crest))
```

Exports: `define-rewrite-pattern`, `define-conversion-pattern`, `begin-mlir-code`,
`apply-conversion`, `affine-map`, `affine-map-attr` (see [affine-map-dsl.md](affine-map-dsl.md)),
`make-unbound-value`, `unbound-value?`, `current-Block`, `with-current-Block`, `current-OpBuilder`,
`with-current-OpBuilder`, and the DSL keywords: `:if-match :then-let :rewrite :with :where`,
`:debug-parse :debug-validate :debug-analyze :debug-codegen`, `= : -> :region :regions`, `:any`,
`:current-op :attr :has-attr? :attr-or`, `:optional :variadic`, the attribute keywords
`:string :index :i8 :i16 :i32 :i64 :f32 :f64 :i8-array :i16-array :i32-array :i64-array :unit`,
`:loc :move-region` and `:arg :builder`.

`add-rewrite-pattern`, `add-conversion-pattern` and the other registration functions are not
exported by `(crest)`; import them from `(mlir Transforms DialectConversion)`. A library that uses
the DSL imports `(except (rnrs) =)`, so that the DSL's `=` is the one in scope.

---

## 10. Deployment

### Development mode (default)

Pattern `.sls` files are loaded from `CREST_PATH` at runtime. On first import
Chez compiles and caches the library as a `.so`; subsequent runs are fast.
The `.sls` files must be co-deployed with the binary and must match the
compiled version — a mismatch fails at runtime.

```bash
export CREST_PATH=/deploy/passes
./crest-opt --crest-pass="passes=passes/my-pass" input.mlir
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
    Sregister_symbol("myDialect::MyOp::getCount",
        (void*)+[](uint64_t op_ptr) -> ptr {
            if (!op_ptr)
                return crest::scheme_error("myDialect::MyOp::getCount", "null operation pointer");
            auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
            return Sunsigned64(op->getNumOperands());
        });
});
```

The function answers a Scheme object: the value, or `crest::scheme_error` on failure, which Scheme raises after
the C++ call has returned (CLAUDE.md Rule 20). Then declare and use it in Scheme:

```scheme
;; In your ffi.sls:
(import (crest support foreign))
(define %myDialect::MyOp::getCount
  (crest-foreign-procedure "myDialect::MyOp::getCount" (uptr) uptr))

;; In your public .sls:
(define myDialect::MyOp::getCount %myDialect::MyOp::getCount)
```

A binding that takes a builder is different: a builder is one of three kinds of shell, and each C++
symbol takes exactly one. Register it with `register_builder_binding`
(`lib/Bindings/Support/BuilderBinding.h`), which registers the three symbols, and declare it in
`ffi.sls` with `define-builder-binding` from `(crest support BuilderBinding)`. See CLAUDE.md
Rule 4.

A binding that calls back into Scheme never makes or releases the callback: it takes a plain C function pointer
(a `uptr` on the Scheme side) and calls it. The function pointer has the type that C++ or MLIR declares for the
callback, result type included (`mlir::WalkResult (*)(uint64_t)`, `int (*)(uint64_t)`, `void (*)()`), and the
Scheme site writes the same: `(define-c-callable name ((x uptr)) int body)`. The Scheme side makes the C function,
because the garbage collector moves Scheme procedures. `define-c-callable` from `(crest callback)` defines
one that lives for the whole program (the clause of an op, a callback of a dialect, a pattern that C++ keeps)
and answers its address; `with-c-callable/lambda` makes one for the length of a body and releases it after, also on an error. An error of
the procedure is reported with its Scheme position in the text (`<file>:<line>:<column>: <who>: <why>`): by
`mlir::emitError` in `(current-MLIRContext)`, and the callable answers the failure value of its type; a callback
whose result is `void` ends the process with the text. A function that only calls it while
it runs (`walk`, `buildAffineLoopNest`, `modifyOpInPlace`) is a Scheme macro that takes a procedure. A function
that C++ keeps the callback in (a type conversion, a legality check, a pattern) takes the address, and its
friendly form is a clause of `with-TypeConverter`, `with-ConversionTarget` or `with-RewritePatternSet`. Only
scalars cross: pointers, integers, strings, and a range as the address of a `CArrayRef` that `crest::CArrayRef->list`
reads back as a list. See CLAUDE.md Rule 17.

Follow the CLAUDE.md binding convention: one header → one module, `%`-prefix
for raw FFI bindings, clean names in the public module.
