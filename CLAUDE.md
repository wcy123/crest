# CREST Development Rules

## Scheme Binding Convention

`BuiltinTypes.h` is the canonical example.

### Rule 1 — One header, one module

Header path → module name (PascalCase preserved):
```
mlir/IR/BuiltinTypes.h                  →  (mlir IR BuiltinTypes)
mlir/Transforms/DialectConversion.h     →  (mlir Transforms DialectConversion)
mlir/Dialect/Shape/IR/Shape.h           →  (mlir Dialect Shape IR Shape)
```

### Rule 2 — Module name maps to file path

```
(mlir IR BuiltinTypes)      →  scheme/mlir/IR/BuiltinTypes.sls
(mlir IR BuiltinTypes ffi)  →  scheme/mlir/IR/BuiltinTypes/ffi.sls
```

### Rule 3 — C++ binding file mirrors the same header

```
lib/Bindings/IR/BuiltinTypes.cpp  ←→  mlir/IR/BuiltinTypes.h
```
File must start with `// Mirrors mlir/IR/BuiltinTypes.h` on line 6.

### Rule 4 — C symbol name = full C++ qualified name

```cpp
Sregister_symbol("mlir::RankedTensorType::cloneWithEncoding", ...);
Sregister_symbol("mlir::IntegerType::get<i64>", ...);       // template param in <>
Sregister_symbol("crest::logging::info", ...);              // crest:: for FFI plumbing only
```

`crest::` is only for inherent FFI boundary problems (type adapters, memory lifecycle, I/O).
Not for business logic expressible as Scheme compositions of existing MLIR bindings.

A binding that takes a builder exists once per kind of builder shell (Rule 11), with the kind as
the last template argument: `mlir::arith::AddFOp::create<OpBuilder>`,
`mlir::arith::AddFOp::create<RewriterBase*>`, `mlir::arith::AddFOp::create<OpBuilder*>`, and
`mlir::OpBuilder::create<OperationState,OpBuilder>` for a name that already has template
arguments. C++ registers the three with `register_builder_binding("mlir::arith::AddFOp::create",
[](mlir::OpBuilder& builder, ...) { ... })`; Scheme writes one
`(define-builder-binding %mlir::arith::AddFOp::create "mlir::arith::AddFOp::create" (uptr ...) uptr)`.

An overloaded C++ function binds each overload under its own name. The first keeps the plain
name; any other puts the parameter types that tell it apart in angle brackets, before the builder
kind: `mlir::affine::AffineLoadOp::create` is `create(OpBuilder&, Location, Value, ValueRange)`
and `mlir::affine::AffineLoadOp::create<AffineMap>` is `create(OpBuilder&, Location, Value,
AffineMap, ValueRange)`; with a builder, the symbol is `...create<AffineMap,OpBuilder>`.

### Rule 5 — Raw FFI binding has `%` prefix

```scheme
;; scheme/mlir/IR/BuiltinTypes/ffi.sls
;; Mirrors mlir/IR/BuiltinTypes.h
(library (mlir IR BuiltinTypes ffi)
  (export %mlir::RankedTensorType::cloneWithEncoding ...)
  (define %mlir::RankedTensorType::cloneWithEncoding
    (foreign-procedure "mlir::RankedTensorType::cloneWithEncoding" (uptr uptr) uptr)))
```

The `foreign-procedure` string must exactly match the `Sregister_symbol` key (see Rule 14).

### Rule 6 — Public binding re-exports without `%`

```scheme
;; scheme/mlir/IR/BuiltinTypes.sls
;; Mirrors mlir/IR/BuiltinTypes.h
(library (mlir IR BuiltinTypes)
  (export mlir::RankedTensorType::cloneWithEncoding ...)
  (import (mlir IR BuiltinTypes ffi) ...)
  (define mlir::RankedTensorType::cloneWithEncoding
    %mlir::RankedTensorType::cloneWithEncoding))
```

Constructors needing a context use `case-lambda`:
```scheme
(define mlir::IndexType::get
  (case-lambda
    [()    (%mlir::IndexType::get (current-mlir-context))]
    [(ctx) (%mlir::IndexType::get ctx)]))
```

### Rule 7 — Public modules never export `%`-prefixed bindings

`%` names are private FFI primitives; they stay in `ffi.sls`. If a `%` binding is only
used internally within the same `.sls` file, omit it from `(export ...)` entirely.

### Rule 8 — No backward-compatibility shims

When a function moves to a new module, update all callers. No alias wrappers.

### Rule 9 — Use anonymous lambdas in `Sregister_symbol` calls

```cpp
// CORRECT
Sregister_symbol("mlir::IndexType::get",
    (void*)+[](uint64_t ctx_ptr) -> uint64_t { ... });
```

The unary `+` converts a non-capturing lambda to a function pointer. Named static functions
are forbidden (they leak into the TU symbol table). Exception: functions declared in shared
headers that require external linkage by definition. A builder-taking binding passes its
non-capturing lambda to `register_builder_binding` instead, which registers the three symbols.

### Rule 13 — Internal Scheme helpers use `%%` prefix

- `%name` — raw FFI binding (`foreign-procedure` wrapper, in `ffi.sls`)
- `%%name` — internal Scheme helper (not exported, not an FFI binding)

Only apply `%%` to library-level private functions. Local helpers inside a function body
do not need it.

### Rule 15 — Scheme names of bool-returning bindings end in `?`

`?` is a Scheme naming convention. When a C++ function returns `true`/`false` (a membership,
type or validity test), the Scheme export is encouraged to end in `?`:

```scheme
(define (mlir::Value? v) (not (zero? v)))
(define mlir::BlockArgument? %mlir::BlockArgument?)
(define (crest::isa<CrestBox<mlir::OperationState>>? ptr)
  (not (zero? (%crest::isa<CrestBox<mlir::OperationState>> ptr))))
```

The `Sregister_symbol` key follows Rule 4 and needs no `?`. Append `?` to the key only when it
would otherwise be a bare class name, so the predicate stays distinct from other bindings of
that class:

```cpp
Sregister_symbol("mlir::BlockArgument?", ...);                  // bare class name
Sregister_symbol("crest::isa<CrestBox<mlir::OperationState>>", ...); // already a predicate
```

### Rule 14 — Every `foreign-procedure` must have a matching `Sregister_symbol`

Chez Scheme resolves **all** `foreign-procedure` bindings at library load time — including
ones never imported or called. If a symbol string has no matching `Sregister_symbol` in C++,
`Sforeign_symbol` returns NULL, corrupting the library's binding table and crashing at load.

```scheme
;; WRONG — crashes at load time if C++ never calls Sregister_symbol("crest::Foo::bar", ...)
(define %crest::Foo::bar (foreign-procedure "crest::Foo::bar" (uptr) uptr))
```

Audit: `test/bindings/ffi-symbols.mlir` reads every `.sls` file and asks Chez (`foreign-entry?`)
whether each symbol named by a `foreign-procedure`, and each of the three variants of a
`define-builder-binding "NAME"` (`NAME<OpBuilder>`, `NAME<RewriterBase*>`, `NAME<OpBuilder*>`),
is registered. It runs with the suite, so a symbol without a `Sregister_symbol` (or a
`register_builder_binding`) fails it. A grep of the sources cannot do this: some names are made
by macros on either side.

---

## Scheme RAII and Dynamic Parameter Convention

### Rule 10 — RAII macros: `with-current-<C++ClassName>` or `with-<C++ClassName>`

```scheme
(with-current-MLIRContext ctx body ...)    ; installs a dynamic parameter
(with-TypeConverter tc () body ...)        ; manages lifetime, no dynamic param
(with-ConversionTarget target (ctx) body ...)
```

A macro that creates an object, binds it to a variable and frees it takes the variable first,
then the creation arguments in a list (empty when there are none):
`(with-<C++ClassName> variable (arguments ...) body ...)`. The variable is never grouped with
the arguments.

### Rule 11 — Dynamic parameters: `current-<C++ClassName>`

```scheme
current-MLIRContext    ; mlir::MLIRContext*  (mlir/IR/MLIRContext.h)
current-OpBuilder      ; mlir::OpBuilder*    (mlir/IR/Builders.h)
```

`current-OpBuilder` holds a builder **shell** (or `#f`): a `CrestBox<OpBuilder>` (from `atBlockEnd`)
or the pattern's `CrestBox<RewriterBase*>` (a builder MLIR passes to a callback is a
`CrestBox<OpBuilder*>`). Each C++ symbol that takes a builder takes exactly one of these shells,
so a builder binding is registered three times (see Rule 4); the Scheme side picks by the shell's
type (`define-builder-binding`). The real object is kept, so rewriter-only operations (`replaceOp`, `eraseOp`,
`inlineRegionBefore`, ...) work on the same handle and reach the real rewriter, including the
methods the conversion rewriter overrides. A raw `OpBuilder*` is never a valid handle.

### Rule 12 — RAII macro placement follows the C++ header

| Macro | Module | C++ header |
|---|---|---|
| `with-current-MLIRContext` | `(mlir IR MLIRContext)` | `mlir/IR/MLIRContext.h` |
| `with-RewritePatternSet` | `(mlir IR PatternMatch)` | `mlir/IR/PatternMatch.h` |
| `with-OpBuilder` | `(mlir IR Builders)` | `mlir/IR/Builders.h` |
| `with-TypeConverter` | `(mlir Transforms DialectConversion)` | `mlir/Transforms/DialectConversion.h` |
| `with-ConversionTarget` | `(mlir Transforms DialectConversion)` | `mlir/Transforms/DialectConversion.h` |
| `with-CrestObject` | `(mlir support CrestObject)` | `lib/Bindings/Support/CrestObject.h` (CREST-specific) |

---

## Rule 16 — Prefer `(rime loop)` for iterations

Use `(for (rime loop) expand)` and the `loop` macro instead of named `let` for numeric
ranges, list walks, and accumulation. When the library also imports `(crest dialect)`,
use `(for (except (rime loop) :name) expand)` to avoid the `:name` conflict.
Full reference: https://github.com/wcy123/rime/blob/main/doc/loop.md

```scheme
;; PREFER
(loop :for i :from 0 :below n :do (f i))

;; AVOID
(let lp ([i 0]) (when (< i n) (f i) (lp (+ i 1))))
```

Key keywords: `:for :from :to :below :in :on :collect :do :if :when :unless :recur :break :finally`.

Named `let` is still fine for irregular recursion (mutual, non-linear stepping).

---

## Rule 17 — C++ keeps C functions, not Scheme procedures

A Scheme procedure that C++ calls later is never stored as a `ptr`: the garbage collector moves it. The Scheme
side makes a C function for it with `crest-callback-entry-point` (`(crest callback)`), which builds a
`foreign-callable`, locks its code object and answers its entry point; the C++ binding takes that address as a
`uptr`. Who releases the lock depends on how long the callable is used:

- **made once per library** (an op's clause, a dialect's callback, the body of a `define-pass`): create it at
  the library level, so a context makes none of its own; C++ keeps a plain function pointer and never releases it;
- **made for a run** (a closure the user passes to a pattern, a type converter, a walk): C++ holds it in a
  `crest::ForeignCallable<R(Args...)>` (`lib/Bindings/Support/ForeignCallable.h`) that unlocks it when what
  calls it is destroyed. Construct the owner first in the binding, before an early return or a check that can
  raise (an error that leaves through Scheme skips destructors).

C++ calls a callable through `crest::callForeign(fn, args...)` (`lib/Bindings/Support/XmmGuard.h`;
`ForeignCallable::operator()` does it): Chez Scheme's `foreign-callable` on Windows x64 did not preserve the upper
halves of XMM6-XMM11, which that ABI makes callee-saved (its entry and exit code saved them as 64-bit doubles), and
C++ compiled for LLVM 23 keeps values in them across a callback (a 16-byte `Block::iterator`), so the call saves and
restores them (`XmmGuard_x64.asm`). The Chez that `cmake/deps.cmake` pins is past the upstream repair of that
(cisco/ChezScheme#1064), so a callable that MLIR calls through a function pointer of its own (the methods of
`InferTypeOpInterface`) is stored in that pointer as it is.

Only scalars cross the boundary (`uptr`, `int`, `unsigned-32`, strings); a range is a pointer and a count, read
back with `crest-callback-pointer-list`, and a list that Scheme answers is pushed through a `foreign-procedure`
into a sink that C++ passes. A callback that has a verdict (a verifier, a parser, a pass) catches an error with
`guard`, gives its text to C++ (`reportFailure`) and answers failure, so the diagnostic has the text instead of
the process ending. `scheme_call` stays for the control plane (a top-level name, or the procedure that Scheme
gave as an argument of the foreign call that is running), and for one more case: a procedure that C++ needs only
while it registers something (the `(TypeID . dispatcher)` pairs of an op's `:interface2` entries,
`lib/Crest/Op.cpp`) is held in a `crest::LockedSchemeObject` for that call, and C++ gets the entry points from the
dispatcher with `scheme_call`. The dispatcher answers entries that Scheme made once, when the library was loaded. A test that makes the callable per run checks that
it is released (`test/dsl/apply-conversion/leak.mlir`).

---

## Checklist for a new binding

- [ ] `lib/Bindings/<Path>/<Name>.cpp` with `// Mirrors mlir/<Path>/<Name>.h` on line 6
- [ ] `Sregister_symbol("mlir::Class::method", (void*)+[](…){…})` — anonymous lambda
- [ ] `scheme/mlir/<Path>/<Name>/ffi.sls` — `%`-prefixed exports, `Mirrors` comment
- [ ] `scheme/mlir/<Path>/<Name>.sls` — clean-name re-exports, `Mirrors` comment
- [ ] Module name `(mlir Path Name)` matches header path exactly
- [ ] Every `foreign-procedure` string matches a `Sregister_symbol` key in C++ (Rule 14)
- [ ] `%%` on internal Scheme helpers; `%` only on raw FFI bindings
- [ ] A binding that takes a builder: `register_builder_binding` in C++, `define-builder-binding` in `ffi.sls`
- [ ] A binding that calls back into Scheme: a callable from `crest-callback-entry-point`, owned per Rule 17
