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

The generic helper `with-raii` (`(mlir support RAII)`) has no C++ class. It takes the variable, an
expression that makes the resource and a procedure that frees it:
`(with-raii variable constructor destructor body ...)`. Write a `with-<C++ClassName>` macro on top
of it when the cleanup is a function call (Rule 18).

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
| `with-mlir::OwningOpRef` | `(mlir IR OwningOpRef)` | `mlir/IR/OwningOpRef.h` |
| `with-CrestObject` | `(mlir support CrestObject)` | `lib/Bindings/Support/CrestObject.h` (CREST-specific) |
| `with-raii` | `(mlir support RAII)` | none: generic, CREST-specific |

### Rule 18 — Naming a macro that is not one constructor

Rules 10 and 12 name a macro after the C++ class it wraps, without the namespace. Some macros
wrap a *function* that returns an owning object, or have no class at all. Name them like this:

1. A macro for a function that returns an owning object is named `with-` followed by the C++ name
   of the owning class, with its namespace, as the symbols of Rule 4 are. `mlir::parseSourceFile`
   returns an `mlir::OwningOpRef`, so the macro is `with-mlir::OwningOpRef`. It lives in the module
   of the header of that class (Rule 12). After the variable comes the call that makes the object,
   as it is written in Scheme: `(with-mlir::OwningOpRef module (mlir::parseSourceFile ctx filename) body ...)`.
   The C++ line it replaces goes in its comment.
   Write the template arguments in `<>`, as in Rule 4, only when the macro behaves differently for
   different arguments. `mlir::Operation::erase` works for every operation, so `with-mlir::OwningOpRef`
   has none.
2. A helper with no C++ counterpart is generic. It lives under `(mlir support ...)` and is named
   for what it does (`with-raii`, `with-CrestObject`). Use it to build the macros of point 1.
3. Do not invent a name that no C++ API has, such as `with-MLIRModule` (MLIR has `ModuleOp` and
   `OwningOpRef`, not `MLIRModule`). Someone who knows MLIR should be able to guess the macro.
4. The macros of Rule 10 keep their short names (`with-MLIRContext`, `with-PassManager`); only
   new macros of the kind in point 1 use the full name.

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

A Scheme procedure that C++ calls later is never stored as a `ptr`: the garbage collector moves it. It gets a C
function of its own, a `foreign-callable` whose code object is locked. Who makes it and who releases the lock
depend on how long the callable is used:

- **made once per library** (an op's clause, a dialect's callback, the body of a `define-pass`): the Scheme side
  makes it at the library level with `crest-callback-entry-point` (`(crest callback)`), which answers its entry
  point, so a context makes none of its own; the C++ binding takes that address as a `uptr` and keeps a plain
  function pointer, and never releases it;
- **made for a run** (a closure the user passes to a pattern, a type converter, a walk): Scheme gives the binding
  the procedure, adapted to the C types, as a `scheme-object`, and the binding makes the owner with
  `crest::ForeignCallable<R(Args...)>::fromProcedure(procedure)` (`lib/Bindings/Support/ForeignCallable.h`),
  which deduces the prototype from the C++ type, compiles a small helper each time (about 0.3 ms, nothing is cached), and unlocks the callable
  when what calls it is destroyed. Making it runs Scheme, which can move the objects of the Scheme heap: first copy
  what you need out of Scheme memory (a `const char*` into a `std::string`, the elements of a Scheme list), then do the
  checks that can raise an error, then make the owner. An error raised while the owner exists skips its destructor and
  leaves the function locked. The comment of the class has the details and two examples.

C++ calls a callable directly through its function pointer. Chez Scheme's `foreign-callable` on Windows x64 used
to zero the upper halves of XMM6-XMM11, which that ABI makes callee-saved, and C++ compiled for LLVM 23 keeps
values in them across a call (a 16-byte `Block::iterator`). The Chez that `cmake/deps.cmake` pins is past the
upstream repair (cisco/ChezScheme#1064), so no guard is needed, not even for the function pointers that MLIR
calls by itself (the methods of `InferTypeOpInterface`); `docs/tech-note.md` ("Chez Scheme pin") has the story
and the steps to move the pin.

Only scalars cross the boundary (`uptr`, `int`, `unsigned-32`, strings); a range is a pointer and a count, read
back with `crest-callback-pointer-list`, and a list that Scheme answers is pushed through a `foreign-procedure`
into a sink that C++ passes. A callback that has a verdict (a verifier, a parser, a pass) catches an error with
`guard`, gives its text to C++ (`reportFailure`) and answers failure, so the diagnostic has the text instead of
the process ending. `scheme_call` stays for the control plane (a top-level name, or the procedure that Scheme
gave as an argument of the foreign call that is running), and for one more case: a procedure that C++ needs only
while it registers something (the `(TypeID . dispatcher)` pairs of an op's `:interfaces` entries,
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
