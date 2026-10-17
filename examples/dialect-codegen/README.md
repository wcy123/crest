# Dialect Code Generation Example

This example demonstrates using CREST as a **compile-time code generator** for MLIR dialects, replacing TableGen's `-gen-dialect-decls` and `-gen-dialect-defs` backends.

## What This Does

**Input:** Scheme DSL definition of a dialect
```scheme
(define hip-dialect
  (define-dialect
    :name "hip"
    :cpp-namespace "::mlir::hip"
    :description "HIP dialect for AMD GPU operations"
    :depends-on ("::mlir::arith::ArithDialect" ...)))
```

**Output:** C++ code (.h.inc and .cpp.inc files)
- Dialect class declaration
- Constructor implementation
- Namespace handling
- Dependent dialect loading

## Running the Example

```bash
cd examples/dialect-codegen
./run-example.sh
```

## Architecture

### 1. Semantic Model (`scheme/mlir/codegen/semantic-model.sls`)
- Pure data structures
- No code generation logic
- `dialect` record type with all metadata

### 2. User DSL (`scheme/mlir/codegen/dialect-dsl.sls`)
- `define-dialect` macro
- Keyword-based syntax
- Compile-time validation

### 3. Code Generator (`scheme/mlir/codegen/dialect-gen.sls`)
- Reads semantic model
- Generates C++ as S-expressions
- Separate functions for decls vs defs

### 4. C++ Printer (`scheme/mlir/codegen/cpp-printer.sls`)
- S-expression → text conversion
- Handles classes, namespaces, functions
- Proper indentation and formatting

## Comparison with TableGen

### TableGen Way
```tablegen
// HipDialect.td
def Hip_Dialect : Dialect {
  let name = "hip";
  let cppNamespace = "::mlir::hip";
  let description = [{...}];
  let dependentDialects = [...];
}
```

```bash
# Generate code
mlir-tblgen -gen-dialect-decls HipDialect.td > HipDialect.h.inc
mlir-tblgen -gen-dialect-defs HipDialect.td > HipDialect.cpp.inc

# Full rebuild needed on any change
ninja MLIRHipDialect  # 30-120s
```

### CREST Way
```scheme
;; hip-dialect.sls
(define hip-dialect
  (define-dialect :name "hip" ...))

(display (sexp->cpp (generate-dialect-decl hip-dialect)))
```

```bash
# Generate code
scheme --program hip-dialect.sls > HipDialect.h.inc

# No rebuild (if using runtime CREST patterns)
# Or minimal rebuild (if structure changed)
```

## Key Advantages

### 1. Unified Semantic Model
```scheme
;; Same dialect record generates:
(generate-dialect-decl hip-dialect)  ; .h.inc
(generate-dialect-def hip-dialect)   ; .cpp.inc
(generate-dialect-docs hip-dialect)  ; .md
(generate-python-binding hip-dialect) ; .py
```

All outputs stay in sync - they're derived from one source.

### 2. Composability via Macros
```scheme
;; Define custom dialect helpers
(define-syntax define-amd-dialect
  (syntax-rules ()
    [(_ name desc)
     (define-dialect
       :name name
       :cpp-namespace (string-append "::mlir::amd::" name)
       :description desc
       :depends-on ("::mlir::arith::ArithDialect"
                    "::mlir::tensor::TensorDialect"))]))

;; Use it
(define-amd-dialect "hip" "HIP GPU operations")
(define-amd-dialect "vaip" "VAIP NPU operations")
```

TableGen has no equivalent - can't define custom abstractions.

### 3. Introspection
```scheme
;; Query dialect at compile time
(if (member? "::mlir::tensor::TensorDialect"
             (dialect-dependent-dialects hip-dialect))
    (display "Uses tensors\n"))

;; Generate conditional code
(when (dialect-use-default-attr-printer hip-dialect)
  (generate-attr-printer-impl hip-dialect))
```

### 4. External Data Sources
```scheme
;; Generate from JSON spec
(define onnx-spec (read-json "onnx-operators.json"))

(define onnx-dialect
  (define-dialect
    :name "onnx"
    :cpp-namespace "::mlir::onnx"
    :description (spec-description onnx-spec)
    :depends-on (spec-dependencies onnx-spec)))
```

Impossible in TableGen - it's a static declaration language.

## Next Steps

1. **Add operation definition support**
   - `define-mlir-op` macro
   - Arguments/results with `dag` type
   - Assembly format DSL

2. **Type and attribute definitions**
   - `define-mlir-type` macro
   - `define-mlir-attr` macro

3. **CMake integration**
   - `add_crest_dialect()` function
   - Dependency tracking
   - Parallel builds

4. **Validation**
   - Compare output with TableGen byte-for-byte
   - Build in MLIR and run tests
   - Measure iteration time

## Files

```
examples/dialect-codegen/
├── README.md                # This file
├── hip-dialect.sls          # Example dialect definition
└── run-example.sh           # Run the example

scheme/mlir/codegen/
├── semantic-model.sls       # Data structures
├── dialect-dsl.sls          # User-facing macros
├── dialect-gen.sls          # Code generation
└── cpp-printer.sls          # S-exp → C++ converter
```

## Status

**Current:** Dialect declaration/definition generation (this example)  
**Next:** Operation definitions with arguments/results  
**Future:** Complete TableGen replacement for custom dialects
