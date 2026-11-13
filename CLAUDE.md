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
  (import (rnrs) (mlir support foreign))
  (define %mlir::RankedTensorType::cloneWithEncoding
    (crest-foreign-procedure "mlir::RankedTensorType::cloneWithEncoding" (uptr uptr) uptr)))
```

The `crest-foreign-procedure` string must exactly match the `Sregister_symbol` key (see Rule 14).

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
    (void*)+[](uint64_t ctx_ptr) -> ptr { ... });
```

The unary `+` converts a non-capturing lambda to a function pointer. Named static functions are forbidden (they
leak into the TU symbol table). Exception: functions declared in shared headers that require external linkage by
definition. A builder-taking binding passes its non-capturing lambda to `register_builder_binding`
(`lib/Bindings/Support/BuilderBinding.h`) instead, which registers the three symbols.

A binding answers a Scheme object (`ptr`): the value (`Sunsigned64`, `Sinteger64`, `Strue`, `Svoid`, ...), or
`scheme_error("who", "why")` on failure (Rule 20). Scheme calls it with `crest-foreign-procedure`, not
`foreign-procedure`. A few plumbing functions (`crest::logging::*`) answer a C type and are called with
`foreign-procedure`.

### Rule 13 — Internal Scheme helpers use `%%` prefix

- `%name` — raw FFI binding (`crest-foreign-procedure` wrapper, in `ffi.sls`)
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

### Rule 14 — Every `crest-foreign-procedure` must have a matching `Sregister_symbol`

Chez Scheme resolves **all** `foreign-procedure` bindings at library load time — including
ones never imported or called. If a symbol string has no matching registration in C++,
`Sforeign_symbol` returns NULL, corrupting the library's binding table and crashing at load.

```scheme
;; WRONG — crashes at load time if C++ never calls Sregister_symbol("crest::Foo::bar", ...)
(define %crest::Foo::bar (crest-foreign-procedure "crest::Foo::bar" (uptr) uptr))
```

The two sides must also agree on the convention: a binding that answers a Scheme object is called with
`crest-foreign-procedure`; a plumbing function that answers a C type is called with the `foreign-procedure` that
declares that type. Mixing them is a crash, not an error, and nothing checks it: keep to Rule 9.

Audit: `test/bindings/ffi-symbols.mlir` reads every `.sls` file and asks Chez (`foreign-entry?`)
whether each symbol named by a `foreign-procedure` or a `crest-foreign-procedure`, and each of the three
variants of a `define-builder-binding "NAME"` (`NAME<OpBuilder>`, `NAME<RewriterBase*>`, `NAME<OpBuilder*>`),
is registered. It runs with the suite, so a missing symbol fails it. A grep of the sources cannot do this: some names are
made by macros on either side.

---

## Scheme RAII and Dynamic Parameter Convention

### Rule 10 — RAII macros: `with-current-<C++ClassName>` or `with-<C++ClassName>`

```scheme
(with-current-MLIRContext ctx body ...)    ; installs a dynamic parameter
(with-TypeConverter type-converter body ...)  ; manages lifetime, no dynamic param
(with-ConversionTarget target (ctx) body ...)
```

A macro that creates an object, binds it to a variable and frees it takes the variable first,
then the creation arguments in a list (empty when there are none):
`(with-<C++ClassName> variable (arguments ...) body ...)`. The variable is never grouped with
the arguments. `with-TypeConverter` has no creation arguments, so its keyword clauses (Rule 17) follow the
variable directly: `(with-TypeConverter type-converter :conversions (...) body ...)`.

The generic helper `with-raii` (`(mlir support RAII)`) has no C++ class. It takes the variable, an
expression that makes the resource and a procedure that frees it:
`(with-raii variable constructor destructor body ...)`. Write a `with-<C++ClassName>` macro on top
of it when the cleanup is a function call (Rule 18).

Several `with-` forms in a row are written with `with*` (`(mlir support with)`), which nests them like `let*`:
`(with* ((with-DialectRegistry registry ()) (with-MLIRContext ctx (registry))) body ...)`. A clause is a
`with-` form without its body, so a `with-` macro must take its body last.

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
| `with*` | `(mlir support with)` | none: generic, CREST-specific |

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

## Rule 17 — Scheme makes every callback; the caller owns its lifetime

C++ never makes, owns, locks or releases a callback. A binding that needs one takes a plain C function pointer
as its parameter (`mlir::WalkResult (*visit)(uint64_t)`) and calls it. Scheme makes the C function, a
`foreign-callable` whose code object is locked (the garbage collector moves Scheme objects, so a procedure is never
stored as a `ptr`), and whoever calls the low-level function decides how long it lives (`(crest callback)`). **The C
function has the prototype that C++ or MLIR declares, result type included**, and the Scheme site writes it:
`(uptr) int`, `(uptr uptr) void`, `(uptr) walk-result`. The result types are `void`, `int`, `uptr`, `unsigned-8`,
`walk-result` (`mlir::WalkResult`, constants in `(mlir Support WalkResult)`) and
`logical-result` (`llvm::LogicalResult`). A callback never answers a Scheme object, and C++ decodes nothing:

- `(crest-make-static-c-callable (kind ...) result-kind proc)` makes it, locks it for good and answers its address.
  Use it only at the library level, for a callback that uses no state of a run (an op's clause, a dialect's
  callback, the body of a `define-pass`, a pattern made by `define-conversion-pattern`): it is made once, when the
  library loads. A callback that uses the state of a run (a type converter, a target) is made by `with-c-callable`
  or by a clause, so that a scope releases it; never make one per run with this.
- `(with-c-callable (name (kind ...) result-kind value) body ...)` makes it for `body` and unlocks it after, also on an
  error. `value` is a procedure, or the address of a locked callable that the caller made (reused, never
  unlocked by the macro; an error if it is not locked).
- A function that only calls the callback while it runs (`mlir::Operation::walk`,
  `mlir::affine::buildAffineLoopNest`, `mlir::RewriterBase::modifyOpInPlace`) is a Scheme macro that takes a
  procedure and wraps it in `with-c-callable`.
- A function that C++ keeps the callback in (`type-converter-add-conversion`, `add-conversion-pattern`,
  `target-add-dynamically-legal-op`, ...) takes the **address** and raises an error for a procedure. The friendly
  form is a clause of the macro that makes the C++ object, which makes the callables around its body:
  `with-TypeConverter` (`:conversions`, `:source-materializations`, `:target-materializations`),
  `with-ConversionTarget` (`:dynamically-legal`, `:unknown-legal`), `with-RewritePatternSet` (`:rewrite-patterns`,
  `:conversion-patterns`, `:conversion-patterns/ctx`). The adapters (`rewrite-pattern->c`,
  `conversion-pattern->c`, `type-conversion->c`, `materialization->c`, `legality->c`) turn a friendly procedure
  into one with C types; they pass an address through.

**No error leaves a callable.** C++ calls a callable through a C function pointer, so an error that escaped it
would cross the C++ frames (Rule 20). MLIR's prototypes have no room for an error, so the guard of every callable
(`crest-make-static-c-callable`, `with-c-callable`) catches it with
`guard` and reports it through MLIR's own channel:

- **result `void`**: nothing can say "failed", so the process ends with the text `<file>:<line>:<column>: <who>: <why>`
  (`llvm::report_fatal_error`): the Scheme position of the callback, then the error.
- **any other result**: `mlir::emitError` with the same text, then the failure value of the type (0, `#f`,
  `interrupt` for a `WalkResult`). MLIR carries on from there as it does for its own failures. The diagnostic has
  no location of its own: the Scheme position is in the text. The position is read when the macro expands (`(mlir support srcloc)`); a macro that wraps the procedure
  of its user in a template lambda passes `:source expression` (the user's form) or, when the procedure is a value
  that reached the macro later, `:location expression` (the position as data). A DSL such as `define-dialect` builds
  `(lambda ...)` forms: `syntax->first-file+line+col` finds the part that is the user's.
- **the context**: a diagnostic belongs to a context. The guard uses `(current-MLIRContext)`; with none the process
  ends with the text. Scheme code that calls C++ sets it (`with-current-MLIRContext`). A tool that C++ drives sets it
  by calling the parameter, a Chez parameter applied to one argument (`crest::setCurrentContext`,
  `lib/Crest/CurrentContext.h`): `CrestDialect::initialize` does for every context that loads a Scheme dialect, and
  the pass runners (`--crest-pass`, `define-pass`) for the context of the op.
- C++ never calls a Scheme procedure itself: `InferTypeOpInterface` gives the words of MLIR's call to Scheme
  (`crest::InferTypeOpInterface::decode`), the clause runs in Scheme inside the callable, and its answer goes back
  through `push`. The one exception is the pass of `--crest-pass`, which has no C prototype to match: it is called
  by name through `crest-call-guarded`, which uses the same guard and answers 1, or 0 after the error was reported.

Nesting (C++ -> Scheme -> C++ -> Scheme) needs no bookkeeping: each failure is reported where it happens. An error
in a callable with a `void` result ends the process, so a program that has to go on makes its callbacks
total. `test/dsl/callback-diagnostics`, `test/dsl/c-callable-results` and `test/dsl/callback-errors` check each kind.

C++ does not check the prototype: a mismatch between the Scheme types and the C++ function pointer type crashes.
A callback used after its scope ends crashes too. `test/dsl/callback-leaks` checks that scoped callables are
released, `test/dsl/c-callable` the macro.

C++ calls a callable directly through its function pointer. Chez Scheme's `foreign-callable` on Windows x64 used
to zero the upper halves of XMM6-XMM11, which that ABI makes callee-saved, and C++ compiled for LLVM 23 keeps
values in them across a call (a 16-byte `Block::iterator`). The Chez that `cmake/deps.cmake` pins is past the
upstream repair (cisco/ChezScheme#1064), so no guard is needed, not even for the function pointers that MLIR
calls by itself (the methods of `InferTypeOpInterface`); `docs/tech-note.md` ("Chez Scheme pin") has the story
and the steps to move the pin.

Only scalars cross the boundary (`uptr`, `int`, `unsigned-32`, strings); a range is a pointer and a count, read
back with `crest-callback-pointer-list`, and a list that Scheme answers is pushed through a `foreign-procedure`
into a sink that C++ passes. A callback that has a verdict (a verifier, a parser, a pass) answers its verdict, and its error is a
diagnostic, as above. `scheme_call` stays for the control plane (a top-level name, or the procedure that Scheme
gave as an argument of the foreign call that is running), and for one more case: a procedure that C++ needs only
while it registers something (the `(TypeID . dispatcher)` pairs of an op's `:interfaces` entries,
`lib/Crest/Op.cpp`) is held in a `crest::LockedSchemeObject` for that call, and C++ gets the entry points from the
dispatcher with `scheme_call`. The dispatcher answers entries that Scheme made once, when the library was loaded.

---

## Rule 19 — An interface of a Scheme op has no implementation in C++

The model of an interface is `crest::CrestModel<mlir::XInterface>` (`lib/Crest/Interface.h`): its `Concept` with every
slot null. C++ implements no method, and there is no model with defaults and no trampoline. Each slot holds the
callable that Scheme made for a clause (`installInterfaceEntry`), so MLIR calls Scheme directly.

- Where MLIR has a default for a method (the `Trait` of the interface has one), the macro of the interface writes it in
  Scheme (`scheme/mlir/**`); where MLIR has none, the op gives the clause, and a missing clause is an error when the
  library compiles. The macro is a table for `op-interface-expand` (`(crest interface)`), which checks the clauses.
- A slot that Scheme cannot write (its answer is a C++ object that Scheme cannot build, such as a `MutableOperandRange`
  or a use range) gets a C function that CREST ships, named by a keyword of the clause (`:all-operands`) or as MLIR's
  default.
- The prototype of a slot as a C function depends on the platform (a class of one pointer is answered through a pointer
  on Windows x64). `crest-make-static-c-callable` (`(crest callback)`) writes it from the C++ types of the slot (the
  kinds `object`, `logical-result`, `walk-result`, `range` and `type-range`, and the `Concept*` that MLIR passes first
  is a leading `uptr`, as `interface.sls` writes it), and
  `SlotAbiTest` (`unittests/Crest/InterfaceTest.cpp`) calls a callable of each kind through a function pointer of the
  exact type of the slot, on Linux and Windows.
- An interface that extends others needs them in the map first, and the op declares them: `require*Clauses` raises an
  error at registration when a base has a null slot.

---

## Rule 20 — Errors are values; no error crosses a C function

C++ never raises a Scheme error. An error that escaped a C++ frame would skip every
destructor in it and in the frames above it (leaks, locks never undone), and Chez keeps about 200 bytes for each
such escape (`S_call_help`; `cmake/patches/chez-release-escaped-frames.patch` explains it and is not applied).
So failure is an ordinary return value, and Scheme raises it after the C++ call has returned.

- **A binding answers a Scheme object**: the value, or on failure `scheme_error("mlir::Block::getArgument",
  "block pointer is null")` (`lib/Bindings/Support/Result.h`), the pair `(who . why)`, `who` a symbol and `why` a
  string (the text is a Twine: `"index " + llvm::Twine(i)`). Scheme calls it through `crest-foreign-procedure`
  (`(mlir support foreign)`), which raises the pair with `(error who why)` in Scheme. No value that a binding
  answers is a pair of a symbol and a string.
- **The lookups of a handle that Scheme gives** answer a pointer, or `nullptr`: `CrestBox<T>::inner(address)`,
  `as_ref<T>(address)` and `as_context(address)`. The binding checks it and answers `scheme_error`.
- **C++ calls Scheme** (Rule 17): the callable has the C prototype that MLIR declares and reports an error of its
  procedure itself, as a diagnostic or, for a `void` result, by ending the process. C++ reads no error from it:
  there is no slot, no flag, no counter, and no pair.
- **No raising from C++ at all**: not `llvm::report_fatal_error` for an error in the program's input (it is for an
  internal invariant that generated code broke).
- **Destructors run**: because nothing is skipped, a binding may hold `std::string`, `SmallVector`,
  `unique_ptr` and `LockedSchemeObject` when it fails. `test/dsl/errors-are-values`, `test/dsl/error-path-leak` and
  `FailingBindingDoesNotLeakCppMemory` (`unittests/Interpreter`) check that a failing binding leaves no heap behind.

**An object the caller must free has a warning.** A binding that answers an object that nothing else owns (a `new`
box, a module, a block, a pass not yet added) carries a `LEAK WARNING:` comment that names the `with-` macro that
frees it (`with-MLIRContext`, `with-DialectRegistry`, `with-PassManager`, `with-OpBuilder`, `with-mlir::OwningOpRef`,
`crest::OpAsmParser::freeOperands`). Samples and tests use the macro; none calls the raw binding and forgets it.
A Scheme program does not call `exit` inside a scope: `exit` does not unwind, so the scope's cleanup never runs.
Raise a value, and call `exit` from a `guard` at the top (`toyc.sls` does, with `%%quit`).

**MLIR keeps some names and strings as pointers, not copies.** The name that a dialect is given (the table of loaded
dialects, every printed `!name.type`) must live as long as the context: intern it with
`mlir::StringAttr::get(ctx, name).getValue()`, never pass a `std::string` of the call (`use-after-free`;
`test/dsl/dialect-name-lifetime`).

**Checking.** `docs/tech-note.md`, "Checking for memory leaks", runs the whole suite under valgrind.

---

## Checklist for a new binding

- [ ] `lib/Bindings/<Path>/<Name>.cpp` with `// Mirrors mlir/<Path>/<Name>.h` on line 6
- [ ] `Sregister_symbol("mlir::Class::method", (void*)+[](…) -> ptr {…})` — anonymous lambda (Rule 9)
- [ ] `scheme/mlir/<Path>/<Name>/ffi.sls` — `%`-prefixed exports, `Mirrors` comment
- [ ] `scheme/mlir/<Path>/<Name>.sls` — clean-name re-exports, `Mirrors` comment
- [ ] Module name `(mlir Path Name)` matches header path exactly
- [ ] Every `crest-foreign-procedure` string matches a `Sregister_symbol` key in C++ (Rule 14)
- [ ] `%%` on internal Scheme helpers; `%` only on raw FFI bindings
- [ ] A binding that takes a builder: `register_builder_binding` in C++, `define-builder-binding` in `ffi.sls`
- [ ] A binding that calls back into Scheme: a callable from `crest-make-static-c-callable`, owned per Rule 17
- [ ] A new op interface: its macro is a table for `op-interface-expand`, the C++ attach function only calls
      `installInterfaceEntry` (Rule 19), and a slot with a new kind of C++ type gets a case in `SlotAbiTest`
- [ ] A binding that answers an object nothing else owns: a `LEAK WARNING:` comment and a `with-` macro that frees it
      (Rule 20); a binding that fails answers an error (`fail(...)`), it never raises (Rule 20)
