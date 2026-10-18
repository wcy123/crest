# CREST Code Generation Design

**Author:** CREST Team  
**Status:** Active Development  
**Last Updated:** 2026-10-17

---

## Executive Summary

CREST extends its runtime pattern DSL with **compile-time code generation** capabilities, providing an opt-in alternative to MLIR's TableGen for dialect definitions. This enables:

1. **Unified semantic model** - one dialect definition generates C++ decls, defs, docs, and bindings
2. **Homoiconic code generation** - C++ structure as manipulable S-expressions before text emission
3. **Macro extensibility** - users define custom abstractions without modifying CREST
4. **External data integration** - generate MLIR from JSON/protobuf specs

**Scope:** Optional alternative to TableGen, not a replacement. Users choose per-dialect.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Design Goals](#design-goals)
3. [Architecture](#architecture)
4. [Implementation Layers](#implementation-layers)
5. [Code Generation Pipeline](#code-generation-pipeline)
6. [Comparison with TableGen](#comparison-with-tablegen)
7. [Extension Points](#extension-points)
8. [Future Work](#future-work)

---

## Problem Statement

### TableGen's Limitations

TableGen is MLIR's current code generation tool for dialect definitions. It has fundamental architectural issues:

#### 1. Backend Fragmentation

```bash
mlir-tblgen -gen-dialect-decls Ops.td  # Backend A (C++ program)
mlir-tblgen -gen-dialect-defs  Ops.td  # Backend B (different C++ program)
mlir-tblgen -gen-dialect-doc   Ops.td  # Backend C (yet another C++ program)
```

Each backend is an **independent C++ program** that parses `.td` files and emits text. No shared semantic understanding of "what is a dialect." Adding a field requires updating 3+ backends manually, with no guarantee they stay consistent.

#### 2. Nested DSL Hell

```tablegen
def MyOp : Op<"my_op"> {
  let assemblyFormat = "$lhs `,` $rhs attr-dict : type($lhs)";
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                       Different language (assembly format DSL) embedded as string
  
  let verifier = [{
    if (getLhs().getType() != getRhs().getType())
      return emitError("type mismatch");
  }];
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Yet another language (C++) embedded as string
}
```

Three nested DSLs: TableGen → assembly format → C++. No composition, no type checking across boundaries.

#### 3. Lack of Introspection

```tablegen
// Cannot query dialect definition at "compile time"
def MyDialect : Dialect {
  let name = "foo";
}

// Cannot write:
//   if (MyDialect.name == "foo") { generate_special_code(); }
// Because TableGen has no programmatic access to its own AST
```

TableGen is a **static declaration language**. Cannot:
- Query definitions programmatically
- Generate code conditionally based on metadata
- Read external data sources (JSON, protobuf)

#### 4. Extension Requires C++

Want a new constraint type? Custom assembly format syntax?

1. Modify `mlir-tblgen` C++ source
2. Rebuild LLVM (30+ minutes)
3. Submit upstream patch
4. Wait months for review

**Users cannot extend TableGen.** Only LLVM developers can.

---

## Design Goals

### Primary Goals

1. **Semantic Model First**
   - Define "what is a dialect/operation/type" as pure data structures
   - Separate data definition from code generation
   - One source of truth for all outputs

2. **Homoiconic Code Generation**
   - C++ code as S-expressions (data) before text (string)
   - Transformable, inspectable, composable
   - Better than string templates

3. **User Extensibility**
   - Custom macros without modifying CREST
   - Project-specific DSL extensions
   - No rebuild required

4. **Opt-In Adoption**
   - Works alongside TableGen
   - Choose per-dialect which tool to use
   - Incremental migration path

### Non-Goals

1. **Not a TableGen replacement** - coexistence, not competition
2. **Not runtime code generation** - compile-time only (like TableGen)
3. **Not MLIR API changes** - generates standard C++ that MLIR expects

---

## Architecture

### Three-Layer Design

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: User DSL (Macros)                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (define-dialect :name "hip" ...)                 │  │
│  │ (define-mlir-op hip.conv ...)                    │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
              │
              ▼ (macro expansion)
┌─────────────────────────────────────────────────────────┐
│  Layer 2: Semantic Model (Data Structures)              │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (make-dialect "hip" "::mlir::hip" ...)           │  │
│  │ (make-operation "hip.conv" args results ...)     │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
              │
              ▼ (code generation)
┌─────────────────────────────────────────────────────────┐
│  Layer 1: C++ Representation (S-Expressions)             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (class HipDialect : public Dialect { ... })      │  │
│  │ (method public void foo () const { ... })        │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
              │
              ▼ (pretty-print)
┌─────────────────────────────────────────────────────────┐
│  Layer 0: C++ Text (String)                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │ class HipDialect : public ::mlir::Dialect {      │  │
│  │ public:                                          │  │
│  │   void foo() const { ... }                       │  │
│  │ };                                               │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Key insight:** Most tools jump from declaration (Layer 3) to text (Layer 0). CREST adds **two intermediate representations** that are manipulable data.

---

## Implementation Layers

### Layer 3: User DSL (dialect-dsl.sls)

**Purpose:** Ergonomic, keyword-based syntax for users

**Example:**
```scheme
(define hip-dialect
  (define-dialect
    :name "hip"
    :cpp-namespace "::mlir::hip"
    :description "HIP dialect for AMD GPU operations"
    :depends-on ("::mlir::arith::ArithDialect"
                 "::mlir::tensor::TensorDialect")))
```

**Implementation:** Scheme macros (`define-syntax`)

**Design principles:**
- Keywords (`:name`, `:depends-on`) for clarity
- Optional parameters with sensible defaults
- Compile-time validation

### Layer 2: Semantic Model (semantic-model.sls)

**Purpose:** Pure data structures representing MLIR concepts

**Example:**
```scheme
(define-record-type dialect
  (fields
    (immutable name)              ; string
    (immutable cpp-namespace)     ; string
    (immutable description)       ; string
    (immutable dependent-dialects) ; list of strings
    ...))
```

**Design principles:**
- Immutable records (functional style)
- No code generation logic here
- Introspectable via field accessors

**Operations:**
```scheme
(dialect-name hip-dialect)           ; → "hip"
(dialect-cpp-namespace hip-dialect)  ; → "::mlir::hip"
```

### Layer 1: C++ Representation (cpp-printer.sls)

**Purpose:** C++ structure as S-expressions

**Example:**
```scheme
;; C++ class as data
`(class HipDialect : public ::mlir::Dialect {
   (method public static constexpr ::llvm::StringLiteral
           getDialectNamespace
           ()
           const
           (return (::llvm::StringLiteral "hip")))
   })
```

**Design principles:**
- Homoiconic - code is data
- Transformable - can `map`/`filter`/`fold` over AST
- Type-agnostic - doesn't care about C++ semantics

**Supported constructs:**
- `(class Name : Base { ... })`
- `(namespace Name { ... })`
- `(function RetType name (params ...) body)`
- `(method access RetType name (params ...) qualifiers body)`
- `(comment "text")`

### Layer 0: C++ Text (cpp-printer.sls)

**Purpose:** Pretty-print S-expressions to valid C++

**Example:**
```scheme
(sexp->cpp '(class Foo {
              (method public void bar () const ;)
              }))
```

**Output:**
```cpp
class Foo {
public:
  void bar() const;
};
```

**Design principles:**
- Proper indentation (2 spaces)
- Idiomatic C++ formatting
- Handles edge cases (empty bodies, semicolons)

---

## Code Generation Pipeline

### Dialect Declaration (.h.inc)

```scheme
;; Input: semantic model
(define hip-dialect (make-dialect "hip" ...))

;; Step 1: Generate C++ AST
(define cpp-ast (generate-dialect-decl hip-dialect))
;; Result: (class HipDialect : public ::mlir::Dialect { ... })

;; Step 2: Pretty-print to text
(define cpp-text (sexp->cpp cpp-ast))
;; Result: "class HipDialect : public ::mlir::Dialect {\n..."

;; Step 3: Write to file
(write-string cpp-text "HipDialect.h.inc")
```

### Dialect Definition (.cpp.inc)

```scheme
(define cpp-def-ast (generate-dialect-def hip-dialect))
(write-string (sexp->cpp cpp-def-ast) "HipDialect.cpp.inc")
```

### Key Advantages

#### 1. Transform Before Printing

```scheme
;; Add debug instrumentation to all methods
(define (add-debug-logging cpp-ast)
  (map-ast
    (lambda (node)
      (if (method? node)
          (prepend-to-body node '(debug-log "enter" method-name))
          node))
    cpp-ast))

(sexp->cpp (add-debug-logging (generate-dialect-decl hip-dialect)))
```

Can't do this with string templates.

#### 2. Validate Before Emission

```scheme
;; Check all methods have return statements
(define (validate-methods cpp-ast)
  (for-each
    (lambda (method)
      (unless (has-return? method)
        (error "Missing return" method)))
    (find-all-methods cpp-ast)))
```

#### 3. Multiple Outputs from Same Model

```scheme
(define hip-dialect (make-dialect ...))

;; C++ header
(write-file "HipDialect.h.inc"
  (sexp->cpp (generate-dialect-decl hip-dialect)))

;; C++ implementation
(write-file "HipDialect.cpp.inc"
  (sexp->cpp (generate-dialect-def hip-dialect)))

;; Markdown docs
(write-file "HipDialect.md"
  (generate-dialect-docs hip-dialect))

;; Python bindings
(write-file "hip_dialect.py"
  (generate-python-bindings hip-dialect))
```

All stay in sync - derived from one semantic model.

---

## Comparison with TableGen

### TableGen Architecture

```
.td file → Parser → Record Set → Backend (C++ program) → String output
                                       ↑
                                   Hard-coded logic
                                   No introspection
                                   No composition
```

**Problems:**
- Backend is opaque C++ program
- Multiple backends duplicate logic
- Users cannot extend

### CREST Architecture

```
.sls file → Macro Expansion → Semantic Model → Generator Functions → S-expr → Text
                                      ↑                    ↑             ↑
                                  Introspectable      User-defined   Transformable
                                  Data structures     Scheme code    Before printing
```

**Advantages:**
- Generators are Scheme functions (users can write their own)
- Semantic model is data (can query/transform)
- S-expressions are composable

### Feature Comparison

| Feature | TableGen | CREST |
|---------|----------|-------|
| **Dialect definition** | ✓ | ✓ |
| **Operation definition** | ✓ | Planned |
| **Type definition** | ✓ | Planned |
| **Multiple outputs from same source** | ✗ (separate backends) | ✓ (semantic model) |
| **Introspection** | ✗ | ✓ |
| **User extensibility** | ✗ (C++ only) | ✓ (Scheme macros) |
| **External data sources** | ✗ | ✓ (JSON/protobuf) |
| **Conditional generation** | Limited (`!if`) | Full Scheme |
| **Compile-time validation** | Limited | Full Scheme |

---

## Extension Points

### 1. Custom Macros

Users can define project-specific DSL extensions:

```scheme
;; Define custom dialect template for AMD projects
(define-syntax define-amd-dialect
  (syntax-rules ()
    [(_ name desc)
     (define-dialect
       :name name
       :cpp-namespace (string-append "::mlir::amd::" name)
       :description desc
       :depends-on ("::mlir::arith::ArithDialect"
                    "::mlir::tensor::TensorDialect"
                    "::mlir::func::FuncDialect"))]))

;; Use it
(define-amd-dialect "hip" "HIP GPU operations")
(define-amd-dialect "vaip" "VAIP NPU operations")
```

### 2. Custom Generators

Users can write their own code generators:

```scheme
;; Generate GraphViz visualization
(define (generate-dialect-viz dialect)
  (string-append
    "digraph " (dialect-name dialect) " {\n"
    (generate-dep-edges (dialect-dependent-dialects dialect))
    "}\n"))

(write-file "hip-deps.dot" (generate-dialect-viz hip-dialect))
```

### 3. External Data Integration

```scheme
;; Read ONNX operator spec (JSON)
(define onnx-spec (read-json "onnx-operators.json"))

;; Generate MLIR dialect from spec
(define onnx-dialect
  (define-dialect
    :name "onnx"
    :cpp-namespace "::mlir::onnx"
    :description (json-ref onnx-spec "description")
    :depends-on (json-ref onnx-spec "dependencies")))

;; Generate operations from spec
(for-each
  (lambda (op-spec)
    (define-mlir-op
      (string->symbol (json-ref op-spec "name"))
      :arguments (spec->arguments op-spec)
      :results (spec->results op-spec)))
  (json-ref onnx-spec "operators"))
```

**150+ ONNX ops generated automatically from spec.**

---

## Future Work

### Phase 2: Operation Definitions

```scheme
(define-mlir-op hip.conv
  :arguments [(Hip_ContextType $ctx)
              (Hip_Tensor $input)
              (Hip_Tensor $weights)
              (Optional Hip_Tensor $bias)
              (Hip_Tensor $output)]
  :results [(Hip_Tensor $result)]
  :assembly-format (seq $ctx "," $input "," $weights
                        (optional-group "," $bias)
                        (attr-dict)
                        ":" (type-of $result))
  :verify (lambda (op)
            (check-conv-shapes op)))
```

**Challenges:**
- `dag` type representation in Scheme
- Assembly format DSL (composable, not string)
- Verifier code generation

### Phase 3: Type/Attribute Definitions

```scheme
(define-mlir-type Hip_QuantizedTensor
  :parameters [(IntegerType $element-type)
               (FloatAttr $scale)
               (IntegerAttr $zero-point)]
  :assembly-format "<" $element-type "," $scale "," $zero-point ">")
```

### Phase 4: CMake Integration

```cmake
function(add_crest_dialect name scheme_file)
  add_custom_command(
    OUTPUT ${name}Ops.h.inc ${name}Ops.cpp.inc
    COMMAND crest-tblgen --gen-decls ${scheme_file} > ${name}Ops.h.inc
    COMMAND crest-tblgen --gen-defs ${scheme_file} > ${name}Ops.cpp.inc
    DEPENDS ${scheme_file} crest-tblgen)
endfunction()

# Usage
add_crest_dialect(HIP hip-ops.sls)
```

### Phase 5: Tooling

- **crest-tblgen**: Standalone code generator (like `mlir-tblgen`)
- **IDE support**: Syntax highlighting, completion for DSL
- **Debugger**: Step through code generation pipeline
- **Formatter**: Pretty-print `.sls` dialect definitions

---

## Conclusion

CREST's code generation extends its runtime pattern DSL with compile-time capabilities, providing an **opt-in alternative** to TableGen that addresses fundamental architectural limitations:

1. **Unified semantic model** eliminates backend fragmentation
2. **Homoiconic representation** enables transformation and validation
3. **Macro extensibility** empowers users to define custom DSLs
4. **Opt-in adoption** provides incremental migration path

**Status:** Dialect generation implemented, operation generation next.

**Availability:** Experimental, feedback welcome.
