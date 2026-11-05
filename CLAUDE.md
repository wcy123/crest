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
headers that require external linkage by definition.

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

Audit: `grep -h 'foreign-procedure' scheme/**/*.sls | sed 's/.*"\([^"]*\)".*/\1/'` lists every
C symbol referenced from Scheme; each must appear in a `Sregister_symbol` call in `lib/`.

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

`current-OpBuilder` holds a **raw** `OpBuilder*` (or `#f`), never a CrestObject shell. A pattern's
rewriter is a `CrestBox<RewriterBase*>` shell: unwrap it with `(crest::as_ptr<mlir::OpBuilder> rw)`
(the C++ upcast adjusts the address; `RewriterBase` is polymorphic, so its `OpBuilder` base is not
at offset 0). Bindings that take a builder take that raw pointer; rewriter-only operations
(`replaceOp`, `eraseOp`, `inlineRegionBefore`, ...) keep taking the shell.

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

## Checklist for a new binding

- [ ] `lib/Bindings/<Path>/<Name>.cpp` with `// Mirrors mlir/<Path>/<Name>.h` on line 6
- [ ] `Sregister_symbol("mlir::Class::method", (void*)+[](…){…})` — anonymous lambda
- [ ] `scheme/mlir/<Path>/<Name>/ffi.sls` — `%`-prefixed exports, `Mirrors` comment
- [ ] `scheme/mlir/<Path>/<Name>.sls` — clean-name re-exports, `Mirrors` comment
- [ ] Module name `(mlir Path Name)` matches header path exactly
- [ ] Every `foreign-procedure` string matches a `Sregister_symbol` key in C++ (Rule 14)
- [ ] `%%` on internal Scheme helpers; `%` only on raw FFI bindings
