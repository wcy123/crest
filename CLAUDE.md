# CREST Development Rules

## Scheme Binding Convention

Every MLIR C++ header file that we bind has exactly one Scheme module pair.
`BuiltinTypes.h` is the canonical example to follow.

### Rule 1 — One header, one module

Each binding module corresponds to exactly one MLIR public header file:

```
mlir/IR/BuiltinTypes.h  →  (mlir IR BuiltinTypes)
mlir/IR/Operation.h     →  (mlir IR Operation)
mlir/IR/Value.h         →  (mlir IR Value)
…
```

The module name mirrors the header path verbatim (PascalCase preserved):
```
mlir / IR / BuiltinTypes .h   →   (mlir IR BuiltinTypes)
mlir / Transforms / DialectConversion .h   →   (mlir Transforms DialectConversion)
mlir / Dialect / Shape / IR / Shape .h     →   (mlir Dialect Shape IR Shape)
```

### Rule 2 — Module name matches header path

The library name `(mlir IR BuiltinTypes)` maps to file:
```
scheme/mlir/IR/BuiltinTypes.sls
```
The ffi companion `(mlir IR BuiltinTypes ffi)` maps to:
```
scheme/mlir/IR/BuiltinTypes/ffi.sls
```

### Rule 3 — C++ binding file mirrors the same header

```
lib/Bindings/IR/BuiltinTypes.cpp   ←→   mlir/IR/BuiltinTypes.h
lib/Bindings/IR/Operation.cpp      ←→   mlir/IR/Operation.h
…
```

The C++ file must start with:
```cpp
// Mirrors mlir/IR/BuiltinTypes.h
```

### Rule 4 — C symbol name = full C++ qualified name

Every `Sregister_symbol` call uses the full C++ name:
```cpp
Sregister_symbol("mlir::RankedTensorType::cloneWithEncoding", ...);
Sregister_symbol("mlir::isa<RankedTensorType>", ...);
Sregister_symbol("mlir::Operation::getResult", ...);
```

For template specializations, encode the parameter in `<>`:
```cpp
Sregister_symbol("mlir::IntegerType::get<i64>", ...);
Sregister_symbol("mlir::DenseElementsAttr::getSplatValue<APFloat>", ...);
```

For CREST-specific **FFI infrastructure** with no direct MLIR counterpart, use `crest::`:
```cpp
Sregister_symbol("crest::logging::info", ...);   // logging — Scheme can't call stderr directly
```

**`crest::` is only for FFI plumbing** — C++ code that solves an inherent boundary problem
between Scheme and C++ (type adapters, memory lifecycle, I/O). It is **not** for business logic
that could be expressed as a Scheme composition of existing MLIR bindings.

Wrong (avoidable logic in C++, now deleted):
```cpp
Sregister_symbol("crest::Operation::setF32Attr", ...);  // was just setAttr + FloatAttr::get
```

Right (genuine FFI infrastructure):
```cpp
Sregister_symbol("crest::logging::info", ...);  // Scheme has no direct stderr/diagnostic API
```

### Rule 5 — Raw FFI binding has `%` prefix

`scheme/mlir/IR/BuiltinTypes/ffi.sls`:
```scheme
;; Mirrors mlir/IR/BuiltinTypes.h
(library (mlir IR BuiltinTypes ffi)
  (export %mlir::RankedTensorType::cloneWithEncoding ...)
  ...
  (define %mlir::RankedTensorType::cloneWithEncoding
    (foreign-procedure "mlir::RankedTensorType::cloneWithEncoding" (uptr uptr) uptr))
```

- `%` prefix marks a raw FFI binding
- The `foreign-procedure` string exactly matches the `Sregister_symbol` key
- File header must have: `;; Mirrors mlir/IR/BuiltinTypes.h`

### Rule 6 — Public binding re-exports without `%`

`scheme/mlir/IR/BuiltinTypes.sls`:
```scheme
;; Mirrors mlir/IR/BuiltinTypes.h
(library (mlir IR BuiltinTypes)
  (export mlir::RankedTensorType::cloneWithEncoding ...)
  (import (mlir IR BuiltinTypes ffi) ...)
  ...
  (define mlir::RankedTensorType::cloneWithEncoding
    %mlir::RankedTensorType::cloneWithEncoding)
```

- No `%` prefix on public exports
- Constructors that need a context use `case-lambda`:
  ```scheme
  (define mlir::IndexType::get
    (case-lambda
      [()    (%mlir::IndexType::get (current-mlir-context))]
      [(ctx) (%mlir::IndexType::get ctx)]))
  ```
- File header must start with: `;; Mirrors mlir/IR/BuiltinTypes.h`
  (or list multiple headers if the module spans more than one)

### Rule 7 — Public modules never export `%`-prefixed bindings

`%`-prefixed bindings are private FFI primitives and must stay in `ffi.sls` files.
The public `.sls` module re-exports only clean names (without `%`):

```scheme
;; WRONG — leaks raw FFI into the public API
(library (mlir IR Region)
  (export %mlir::Region::push_back ...))   ; % names must never appear here

;; CORRECT — clean name re-exported
(library (mlir IR Region)
  (export mlir::Region::front ...)
  (define mlir::Region::front %mlir::Region::front))
```

If a `%` binding is only used internally within the same `.sls` file, it must
not appear in `(export ...)` at all.

### Rule 8 — No backward-compatibility shims

Do not create wrapper libraries that alias old names to new ones.
Callers must use the canonical C++ names directly. When a function
moves to a new module, update all callers — do not leave an alias.

### Rule 9 — Use anonymous lambdas in `Sregister_symbol` calls

Every `Sregister_symbol` call must use a non-capturing lambda converted to a
function pointer with the unary `+` operator — never a named static function:

```cpp
// WRONG — named static function leaks into TU-level symbol table
static uint64_t mlir_ir_index_type_get(uint64_t ctx_ptr) { ... }
Sregister_symbol("mlir::IndexType::get", (void*)::mlir_ir_index_type_get);

// CORRECT — anonymous lambda, no name in the symbol table
Sregister_symbol("mlir::IndexType::get",
    (void*)+[](uint64_t ctx_ptr) -> uint64_t {
      ...
    });
```

The unary `+` converts a non-capturing lambda to a plain function pointer.
The `(void*)` cast satisfies `Sregister_symbol`'s `void*` parameter.
Anonymous lambdas cannot be accidentally called from other TUs and the
compiler can inline or optimize them freely.

Exception: functions declared in shared headers (e.g. `Logging.h` declares
`mlir_support_logging_*`) keep external linkage by definition and are not
registered via anonymous lambdas.

## Scheme RAII and Dynamic Parameter Convention

### Rule 10 — RAII macros use `with-<C++ClassName>`

Every RAII macro that manages the lifetime of a specific C++ object is named
after the C++ class it wraps:

```scheme
(with-current-MLIRContext ctx body ...)       ; wraps mlir::MLIRContext*
(with-TypeConverter (tc) body ...)    ; wraps mlir::TypeConverter
(with-ConversionTarget (t ctx) body ...) ; wraps mlir::ConversionTarget
(with-RewritePatternSet (ps ctx) body ...) ; wraps mlir::RewritePatternSet
(with-RewriterBase (rw loc) body ...) ; installs a mlir::RewriterBase
(with-OpBuilder block body ...)       ; wraps mlir::OpBuilder
```

The generic underlying helper that takes an explicit ctor/dtor pair is `with-raii`
(no C++ class name, because it is class-agnostic).

### Rule 11 — Dynamic parameters use `current-<C++ClassName>`

Every `make-parameter` that holds a pointer to a specific C++ object is named
`current-<C++ClassName>`:

```scheme
current-MLIRContext   ; MLIRContext* (mlir/IR/MLIRContext.h)
current-RewriterBase  ; RewriterBase* (mlir/IR/PatternMatch.h)
current-OpBuilder     ; OpBuilder*   (mlir/IR/Builders.h)
current-InsertionPoint      ; Location     (mlir/IR/Location.h)
```

The `current-` prefix signals that the binding is a dynamic parameter, not a
value — analogous to Scheme's `current-input-port`. C++ developers reading
`(current-MLIRContext)` immediately know which C++ type is involved.

### Rule 12 — RAII module placement follows the C++ header

The RAII macro lives in the same Scheme module that wraps the C++ class:

| Macro | Module | C++ header |
|---|---|---|
| `with-current-MLIRContext` | `(mlir IR MLIRContext)` | `mlir/IR/MLIRContext.h` |
| `with-RewriterBase` | `(mlir IR PatternMatch)` | `mlir/IR/PatternMatch.h` |
| `with-RewritePatternSet` | `(mlir IR PatternMatch)` | `mlir/IR/PatternMatch.h` |
| `with-OpBuilder` | `(mlir IR Builders)` | `mlir/IR/Builders.h` |
| `with-TypeConverter` | `(mlir Transforms DialectConversion)` | `mlir/Transforms/DialectConversion.h` |
| `with-ConversionTarget` | `(mlir Transforms DialectConversion)` | `mlir/Transforms/DialectConversion.h` |
| `with-raii` | `(mlir support RAII)` | no C++ counterpart (generic helper) |

## Summary checklist for a new binding

- [ ] One `.cpp` file in `lib/Bindings/<Path>/` matching the header path
- [ ] `// Mirrors mlir/<Path>/<Header>.h` comment on line 6
- [ ] `Sregister_symbol("mlir::Class::method", ...)` with full C++ name
- [ ] `scheme/mlir/<Path>/<Name>/ffi.sls` with `%` prefixed exports
- [ ] `scheme/mlir/<Path>/<Name>.sls` re-exporting without `%`
- [ ] Both `.sls` files have `;; Mirrors mlir/<Path>/<Header>.h` in docstring
- [ ] Module name `(mlir Path Name)` matches header path exactly
- [ ] All `Sregister_symbol` calls use anonymous lambdas (`(void*)+[](…) -> T { … }`)
