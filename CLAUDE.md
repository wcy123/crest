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

For CREST-specific utilities with no direct MLIR counterpart, use `crest::`:
```cpp
Sregister_symbol("crest::Operation::setF32Attr", ...);
Sregister_symbol("crest::RewriterBase::build", ...);
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

### Rule 7 — No backward-compatibility shims

Do not create wrapper libraries that alias old names to new ones.
Callers must use the canonical C++ names directly. When a function
moves to a new module, update all callers — do not leave an alias.

## Summary checklist for a new binding

- [ ] One `.cpp` file in `lib/Bindings/<Path>/` matching the header path
- [ ] `// Mirrors mlir/<Path>/<Header>.h` comment on line 6
- [ ] `Sregister_symbol("mlir::Class::method", ...)` with full C++ name
- [ ] `scheme/mlir/<Path>/<Name>/ffi.sls` with `%` prefixed exports
- [ ] `scheme/mlir/<Path>/<Name>.sls` re-exporting without `%`
- [ ] Both `.sls` files have `;; Mirrors mlir/<Path>/<Header>.h` in docstring
- [ ] Module name `(mlir Path Name)` matches header path exactly
