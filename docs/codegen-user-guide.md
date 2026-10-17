# CREST Code Generation User Guide

**Version:** 0.1.0 (Experimental)  
**Last Updated:** 2026-10-17

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Dialect Definition](#dialect-definition)
5. [Code Generation](#code-generation)
6. [Integration with Build Systems](#integration-with-build-systems)
7. [API Reference](#api-reference)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Introduction

### What is CREST Code Generation?

CREST extends its runtime pattern DSL with **compile-time code generation** for MLIR dialects, types, and operations. It provides an alternative to TableGen with these advantages:

- **Unified model**: One definition → multiple outputs (C++, docs, bindings)
- **Composable DSL**: Define custom macros without modifying CREST
- **Introspection**: Query dialect metadata at compile time
- **External data**: Generate from JSON/protobuf specs

### When to Use CREST vs TableGen

**Use CREST when:**
- ✓ Building custom dialects (HIP, VAIP, project-specific)
- ✓ Need to generate from external specs (ONNX, TOSA)
- ✓ Want macro-based abstractions
- ✓ Experimenting with new features

**Use TableGen when:**
- ✓ Working with upstream MLIR dialects
- ✓ Stable, well-tested infrastructure needed
- ✓ Team familiar with TableGen

**Can use both:** Mix per-dialect in same project.

---

## Installation

### Prerequisites

- Chez Scheme 10.0+
- CREST runtime installed
- MLIR build environment (for compiling generated code)

### Setup

```bash
# Clone CREST
git clone https://github.com/wcy123/crest.git
cd crest

# Build CREST
mkdir build && cd build
cmake ..
make

# Verify installation
scheme --version
# Should show Chez Scheme 10.x
```

### Library Path

Set `CHEZSCHEMELIBDIRS` to include CREST's Scheme libraries:

```bash
export CHEZSCHEMELIBDIRS="/path/to/crest/scheme"
```

Add to `~/.bashrc` or `~/.zshrc` for persistence.

---

## Quick Start

### Step 1: Define a Dialect

Create `my-dialect.sls`:

```scheme
#!/usr/bin/env scheme --program

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Define dialect
(define my-dialect
  (define-dialect
    :name "my"
    :cpp-namespace "::mlir::my"
    :description "My custom MLIR dialect"
    :depends-on ("::mlir::arith::ArithDialect")))

;; Generate declaration
(display (sexp->cpp (generate-dialect-decl my-dialect)))
```

### Step 2: Generate Code

```bash
chmod +x my-dialect.sls
./my-dialect.sls > MyDialect.h.inc
```

### Step 3: Use in MLIR

```cpp
// MyDialect.h
#include "mlir/IR/Dialect.h"

namespace mlir {
namespace my {

#include "MyDialect.h.inc"

} // namespace my
} // namespace mlir
```

---

## Dialect Definition

### Basic Syntax

```scheme
(define-dialect
  :name <string>              ; Required: dialect name
  :cpp-namespace <string>     ; Required: C++ namespace
  :description <string>       ; Required: documentation
  :depends-on (<strings...>)) ; Required: dependent dialects
```

### Minimal Example

```scheme
(define my-dialect
  (define-dialect
    :name "my"
    :cpp-namespace "::mlir::my"
    :description "My dialect"
    :depends-on ()))
```

### Complete Example

```scheme
(define hip-dialect
  (define-dialect
    :name "hip"
    :cpp-namespace "::mlir::hip"
    :description "HIP dialect for AMD GPU operations targeting ROCm/HIP backends.

This dialect provides operations for:
- Tensor operations (conv, matmul, pooling)
- Quantization (qadd, qmul, qmatmul)
- Memory management (allocate, deallocate)
"
    :depends-on ("::mlir::arith::ArithDialect"
                 "::mlir::tensor::TensorDialect"
                 "::mlir::func::FuncDialect"
                 "::mlir::shape::ShapeDialect")))
```

### Field Reference

#### `:name`
- **Type:** String
- **Purpose:** Dialect identifier (lowercase, alphanumeric)
- **Example:** `"hip"`, `"onnx"`, `"my_dialect"`
- **Used for:** MLIR registration, namespace generation

#### `:cpp-namespace`
- **Type:** String
- **Purpose:** Fully-qualified C++ namespace
- **Example:** `"::mlir::hip"`, `"::mlir::amd::vaip"`
- **Convention:** Start with `::`, use lowercase

#### `:description`
- **Type:** String (can be multi-line)
- **Purpose:** Documentation for dialect
- **Example:**
  ```scheme
  :description "Arithmetic operations.

  Includes:
  - Integer arithmetic (add, sub, mul, div)
  - Floating-point arithmetic
  - Comparison operations
  "
  ```

#### `:depends-on`
- **Type:** List of strings
- **Purpose:** Other dialects required by this one
- **Example:** `("::mlir::arith::ArithDialect" "::mlir::tensor::TensorDialect")`
- **Format:** Full C++ class names with namespace

### Advanced Options

#### Extra Class Declarations

```scheme
(define-dialect
  :name "my"
  :cpp-namespace "::mlir::my"
  :description "..."
  :depends-on (...)
  :extra-class-decl "
    // Custom helper methods
    static bool isValidTensor(Type type);
    void registerCustomPasses();
  ")
```

---

## Code Generation

### Generating Declarations (.h.inc)

```scheme
;; In your .sls file
(define my-dialect (define-dialect ...))

;; Generate C++ declaration
(define decl-ast (generate-dialect-decl my-dialect))

;; Convert to text
(define decl-text (sexp->cpp decl-ast))

;; Write to file
(display decl-text)
```

**Command line:**
```bash
scheme --program my-dialect.sls > MyDialect.h.inc
```

### Generating Definitions (.cpp.inc)

```scheme
;; Generate C++ implementation
(define def-ast (generate-dialect-def my-dialect))
(display (sexp->cpp def-ast))
```

**To generate both in one file:**
```scheme
;; my-dialect.sls
(import ...)

(define my-dialect (define-dialect ...))

(cond
  [(equal? (command-line-arg 1) "decl")
   (display (sexp->cpp (generate-dialect-decl my-dialect)))]
  [(equal? (command-line-arg 1) "def")
   (display (sexp->cpp (generate-dialect-def my-dialect)))]
  [else
   (error "Usage: my-dialect.sls <decl|def>")])
```

**Usage:**
```bash
scheme --program my-dialect.sls decl > MyDialect.h.inc
scheme --program my-dialect.sls def  > MyDialect.cpp.inc
```

### Output Structure

#### Declaration (.h.inc)

```cpp
class MyDialect : public ::mlir::Dialect {
public:
  explicit MyDialect(::mlir::MLIRContext *context);
  
  static constexpr ::llvm::StringLiteral getDialectNamespace() {
    return ::llvm::StringLiteral("my");
  }
  
  void printAttribute(::mlir::Attribute attr,
                     ::mlir::DialectAsmPrinter &os) const override;
  void printType(::mlir::Type type,
                ::mlir::DialectAsmPrinter &os) const override;
};
```

#### Definition (.cpp.inc)

```cpp
namespace ::mlir::my {

MyDialect::MyDialect(::mlir::MLIRContext *context)
    : ::mlir::Dialect(getDialectNamespace(), context,
                      ::mlir::TypeID::get<MyDialect>()) {
  // Load dependent dialects
  getContext()->getOrLoadDialect<::mlir::arith::ArithDialect>();
  
  // Initialize dialect
  initialize();
}

void MyDialect::initialize() {
  // Register operations
  // Register types
  // Register attributes
}

} // namespace ::mlir::my
```

---

## Integration with Build Systems

### CMake (Manual)

```cmake
# Define custom command to run CREST
add_custom_command(
  OUTPUT MyDialect.h.inc MyDialect.cpp.inc
  COMMAND scheme --program ${CMAKE_CURRENT_SOURCE_DIR}/my-dialect.sls decl
          > MyDialect.h.inc
  COMMAND scheme --program ${CMAKE_CURRENT_SOURCE_DIR}/my-dialect.sls def
          > MyDialect.cpp.inc
  DEPENDS my-dialect.sls
  COMMENT "Generating My dialect with CREST")

# Add library
add_library(MLIRMyDialect
  MyDialect.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/MyDialect.h.inc
  ${CMAKE_CURRENT_BINARY_DIR}/MyDialect.cpp.inc)
```

### CMake (Helper Function)

```cmake
# In cmake/modules/AddCRESTDialect.cmake
function(add_crest_dialect name scheme_file)
  set(DECL_FILE ${CMAKE_CURRENT_BINARY_DIR}/${name}Dialect.h.inc)
  set(DEF_FILE ${CMAKE_CURRENT_BINARY_DIR}/${name}Dialect.cpp.inc)
  
  add_custom_command(
    OUTPUT ${DECL_FILE} ${DEF_FILE}
    COMMAND scheme --program ${CMAKE_CURRENT_SOURCE_DIR}/${scheme_file} decl > ${DECL_FILE}
    COMMAND scheme --program ${CMAKE_CURRENT_SOURCE_DIR}/${scheme_file} def > ${DEF_FILE}
    DEPENDS ${scheme_file}
    COMMENT "Generating ${name} dialect")
  
  set(${name}_GENERATED_FILES ${DECL_FILE} ${DEF_FILE} PARENT_SCOPE)
endfunction()

# Usage
add_crest_dialect(My my-dialect.sls)
add_library(MLIRMyDialect MyDialect.cpp ${My_GENERATED_FILES})
```

### Bazel

```python
# BUILD file
load("@crest//bazel:crest.bzl", "crest_dialect")

crest_dialect(
    name = "my_dialect",
    src = "my-dialect.sls",
    dialect_name = "My",
)

cc_library(
    name = "MLIRMyDialect",
    srcs = ["MyDialect.cpp"],
    hdrs = ["MyDialect.h"],
    deps = [
        ":my_dialect",  # Generated .inc files
        "@llvm-project//mlir:IR",
    ],
)
```

---

## API Reference

### Macros

#### `define-dialect`

```scheme
(define-dialect
  :name string
  :cpp-namespace string
  :description string
  :depends-on (string ...)
  [:extra-class-decl string])
```

**Returns:** `dialect` record

**Example:**
```scheme
(define my-dialect
  (define-dialect
    :name "my"
    :cpp-namespace "::mlir::my"
    :description "My dialect"
    :depends-on ()))
```

### Functions

#### `generate-dialect-decl`

```scheme
(generate-dialect-decl dialect) → sexp
```

**Parameters:**
- `dialect`: `dialect` record

**Returns:** S-expression representing C++ class declaration

**Example:**
```scheme
(generate-dialect-decl my-dialect)
;; → (class MyDialect : public ::mlir::Dialect { ... })
```

#### `generate-dialect-def`

```scheme
(generate-dialect-def dialect) → sexp
```

**Parameters:**
- `dialect`: `dialect` record

**Returns:** S-expression representing C++ implementation

#### `sexp->cpp`

```scheme
(sexp->cpp sexp) → string
```

**Parameters:**
- `sexp`: S-expression representing C++ code

**Returns:** Formatted C++ source code

**Example:**
```scheme
(sexp->cpp '(class Foo {
              (method public void bar () const ;)
              }))
;; → "class Foo {\npublic:\n  void bar() const;\n};\n"
```

### Record Accessors

#### `dialect` record

```scheme
(dialect-name dialect) → string
(dialect-cpp-namespace dialect) → string
(dialect-description dialect) → string
(dialect-dependent-dialects dialect) → (listof string)
(dialect-extra-class-decl dialect) → (or string #f)
(dialect-use-default-attr-printer dialect) → boolean
(dialect-use-default-type-printer dialect) → boolean
```

---

## Best Practices

### Organization

**One dialect per file:**
```
dialects/
├── hip-dialect.sls
├── vaip-dialect.sls
└── onnx-dialect.sls
```

**Shared utilities in separate module:**
```scheme
;; dialects/common.sls
(library (dialects common)
  (export define-amd-dialect)
  (import ...)
  
  (define-syntax define-amd-dialect ...))

;; dialects/hip-dialect.sls
(import (dialects common))
(define-amd-dialect "hip" "...")
```

### Naming Conventions

**Dialect names:** lowercase, alphanumeric
```scheme
:name "hip"      ; Good
:name "HIP"      ; Bad (use lowercase)
:name "my-dial"  ; Bad (no hyphens)
```

**Namespaces:** start with `::`
```scheme
:cpp-namespace "::mlir::hip"        ; Good
:cpp-namespace "mlir::hip"          ; Bad (missing ::)
```

**Dependencies:** full class names
```scheme
:depends-on ("::mlir::arith::ArithDialect")  ; Good
:depends-on ("arith")                         ; Bad (need full name)
```

### Documentation

**Write descriptive docs:**
```scheme
:description "HIP dialect for AMD GPU operations.

Operations:
- Convolution: hip.conv
- Matrix multiplication: hip.matmul
- Quantized operations: hip.qadd, hip.qmul

Memory model:
- Device memory: hip.mem<device>
- Host memory: hip.mem<host>
"
```

### Version Control

**Commit both `.sls` and `.inc` files:**
```
git add hip-dialect.sls
git add HipDialect.h.inc HipDialect.cpp.inc
```

**Why?** Generated files in version control allow diffing and code review.

---

## Troubleshooting

### Common Errors

#### Error: "undefined variable define-dialect"

**Cause:** Missing import

**Fix:**
```scheme
(import (mlir codegen dialect-dsl))  ; Add this
```

#### Error: "exception in sexp->cpp"

**Cause:** Malformed S-expression

**Debug:**
```scheme
;; Print AST before converting
(define ast (generate-dialect-decl my-dialect))
(pretty-print ast)  ; Inspect structure
```

#### Error: "C++ compilation failed"

**Cause:** Generated code has syntax errors

**Debug:**
1. Check generated `.inc` file
2. Compare with TableGen output
3. Report bug with `.sls` and error message

### Debugging

**Enable verbose output:**
```scheme
(define *debug* #t)

(when *debug*
  (display "Generating dialect: ")
  (display (dialect-name my-dialect))
  (newline))
```

**Inspect intermediate representations:**
```scheme
;; Step 1: Semantic model
(pretty-print my-dialect)

;; Step 2: C++ AST
(pretty-print (generate-dialect-decl my-dialect))

;; Step 3: C++ text
(display (sexp->cpp (generate-dialect-decl my-dialect)))
```

### Getting Help

- **Issues:** https://github.com/wcy123/crest/issues
- **Discussions:** https://github.com/wcy123/crest/discussions
- **Examples:** `examples/dialect-codegen/`

---

## Next Steps

- **Tutorial:** See [codegen-tutorial.md](codegen-tutorial.md) for step-by-step walkthrough
- **Design:** See [codegen-design.md](codegen-design.md) for architecture details
- **Testing:** See [test/codegen/README.md](../test/codegen/README.md) for regression tests
