# CREST Code Generation Tutorial

**Goal:** Learn CREST code generation by building a complete custom dialect step-by-step  
**Time:** 30-45 minutes  
**Prerequisites:** Basic Scheme knowledge, MLIR concepts

---

## Table of Contents

1. [Setup](#setup)
2. [Lesson 1: Your First Dialect](#lesson-1-your-first-dialect)
3. [Lesson 2: Adding Dependencies](#lesson-2-adding-dependencies)
4. [Lesson 3: Custom Macros](#lesson-3-custom-macros)
5. [Lesson 4: Multiple Outputs](#lesson-4-multiple-outputs)
6. [Lesson 5: External Data](#lesson-5-external-data)
7. [Next Steps](#next-steps)

---

## Setup

### 1. Verify Installation

```bash
# Check Chez Scheme
scheme --version
# Should show: Chez Scheme Version 10.x

# Check CREST
ls /path/to/crest/scheme/mlir/codegen/
# Should show: semantic-model.sls, dialect-dsl.sls, ...
```

### 2. Create Working Directory

```bash
mkdir ~/crest-tutorial
cd ~/crest-tutorial
```

### 3. Set Library Path

```bash
export CHEZSCHEMELIBDIRS="/path/to/crest/scheme"
```

---

## Lesson 1: Your First Dialect

**Goal:** Define and generate a minimal dialect

### Step 1.1: Create Dialect Definition

Create `calc-dialect.sls`:

```scheme
#!/usr/bin/env scheme --program

;; Import required libraries
(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Define a simple calculator dialect
(define calc-dialect
  (define-dialect
    :name "calc"
    :cpp-namespace "::mlir::calc"
    :description "Simple calculator dialect for arithmetic operations"
    :depends-on ()))

;; Generate C++ declaration
(display "// CalcDialect.h.inc\n")
(display (sexp->cpp (generate-dialect-decl calc-dialect)))

(display "\n\n")

;; Generate C++ definition
(display "// CalcDialect.cpp.inc\n")
(display (sexp->cpp (generate-dialect-def calc-dialect)))
```

### Step 1.2: Make Executable and Run

```bash
chmod +x calc-dialect.sls
./calc-dialect.sls
```

**Expected output:**
```cpp
// CalcDialect.h.inc
class CalcDialect : public ::mlir::Dialect {
  // MLIR Dialect: calc

public:
  explicit CalcDialect(::mlir::MLIRContext *context);
  
  static constexpr ::llvm::StringLiteral getDialectNamespace() const {
    return ::llvm::StringLiteral("calc");
  }
  
  void printAttribute(::mlir::Attribute attr, ::mlir::DialectAsmPrinter &os) const override;
  void printType(::mlir::Type type, ::mlir::DialectAsmPrinter &os) const override;
};


// CalcDialect.cpp.inc
namespace ::mlir::calc {
  // Dialect: calc
  // Simple calculator dialect for arithmetic operations
  
  void CalcDialect(::mlir::MLIRContext *context) {
    initialize();
  }
  
  void initialize() {
    // Register operations
    // Register types
    // Register attributes
  }
}
```

### Step 1.3: Understand the Structure

**What just happened?**

1. `define-dialect` macro created a `dialect` record
2. `generate-dialect-decl` converted record → C++ AST (S-expression)
3. `sexp->cpp` converted AST → formatted C++ text

**The power:** Same dialect definition generates both header and implementation.

---

## Lesson 2: Adding Dependencies

**Goal:** Make dialect depend on standard MLIR dialects

### Step 2.1: Add Arith Dependency

Modify `calc-dialect.sls`:

```scheme
(define calc-dialect
  (define-dialect
    :name "calc"
    :cpp-namespace "::mlir::calc"
    :description "Calculator dialect built on arithmetic operations"
    :depends-on ("::mlir::arith::ArithDialect")))  ; ← Added dependency
```

### Step 2.2: Run and Inspect Output

```bash
./calc-dialect.sls
```

Look for this in the `.cpp.inc` section:
```cpp
void CalcDialect(::mlir::MLIRContext *context) {
  getContext()->getOrLoadDialect<::mlir::arith::ArithDialect>();  // ← New!
  initialize();
}
```

**What happened?** CREST automatically generated code to load dependent dialects.

### Step 2.3: Add Multiple Dependencies

```scheme
:depends-on ("::mlir::arith::ArithDialect"
             "::mlir::func::FuncDialect"
             "::mlir::tensor::TensorDialect")
```

**Exercise:** Add these dependencies and verify the output.

---

## Lesson 3: Custom Macros

**Goal:** Define reusable abstractions

### Step 3.1: Create a Macro Library

Create `my-macros.sls`:

```scheme
(library (my-macros)
  (export define-simple-dialect)
  (import (chezscheme)
          (mlir codegen dialect-dsl))

  ;; Custom macro for simple dialects
  (define-syntax define-simple-dialect
    (syntax-rules ()
      [(_ name description)
       (define-dialect
         :name name
         :cpp-namespace (string-append "::mlir::" name)
         :description description
         :depends-on ("::mlir::arith::ArithDialect"
                      "::mlir::func::FuncDialect"))])))
```

### Step 3.2: Use the Macro

Create `simple-dialect.sls`:

```scheme
#!/usr/bin/env scheme --program

(import (chezscheme)
        (my-macros)                    ; ← Import our macro
        (mlir codegen semantic-model)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Use custom macro
(define math-dialect
  (define-simple-dialect "math" "Mathematical operations"))

(define stats-dialect
  (define-simple-dialect "stats" "Statistical operations"))

(define ml-dialect
  (define-simple-dialect "ml" "Machine learning operations"))

;; Generate all three
(for-each
  (lambda (dialect)
    (display (string-append "\n=== " (dialect-name dialect) " ===\n"))
    (display (sexp->cpp (generate-dialect-decl dialect)))
    (display "\n"))
  (list math-dialect stats-dialect ml-dialect))
```

### Step 3.3: Run It

```bash
chmod +x simple-dialect.sls
./simple-dialect.sls
```

**Result:** Three dialects generated from three lines of code!

**Key insight:** Macros let you define custom DSLs. TableGen can't do this.

---

## Lesson 4: Multiple Outputs

**Goal:** Generate C++, Markdown, and Python from one definition

### Step 4.1: Add Documentation Generator

Create `multi-output.sls`:

```scheme
#!/usr/bin/env scheme --program

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

(define gpu-dialect
  (define-dialect
    :name "gpu"
    :cpp-namespace "::mlir::gpu"
    :description "GPU operations for parallel computing"
    :depends-on ("::mlir::arith::ArithDialect")))

;; Generate C++ header
(define (generate-cpp-header dialect)
  (sexp->cpp (generate-dialect-decl dialect)))

;; Generate Markdown documentation
(define (generate-markdown-doc dialect)
  (string-append
    "# " (string-upcase (dialect-name dialect)) " Dialect\n\n"
    "**Namespace:** `" (dialect-cpp-namespace dialect) "`\n\n"
    "## Description\n\n"
    (dialect-description dialect) "\n\n"
    "## Dependencies\n\n"
    (if (null? (dialect-dependent-dialects dialect))
        "None\n"
        (string-append
          (apply string-append
                 (map (lambda (dep)
                        (string-append "- `" dep "`\n"))
                      (dialect-dependent-dialects dialect)))))))

;; Generate Python stub
(define (generate-python-stub dialect)
  (string-append
    "# " (dialect-name dialect) "_dialect.py\n"
    "\"\"\"" (dialect-description dialect) "\"\"\"\n\n"
    "class " (string-titlecase (dialect-name dialect)) "Dialect:\n"
    "    name = \"" (dialect-name dialect) "\"\n"
    "    namespace = \"" (dialect-cpp-namespace dialect) "\"\n"))

;; Helper: titlecase first letter
(define (string-titlecase s)
  (string-append (string-upcase (substring s 0 1))
                 (substring s 1 (string-length s))))

;; Generate all outputs
(display "=== C++ Header ===\n")
(display (generate-cpp-header gpu-dialect))

(display "\n\n=== Markdown Docs ===\n")
(display (generate-markdown-doc gpu-dialect))

(display "\n=== Python Stub ===\n")
(display (generate-python-stub gpu-dialect))
```

### Step 4.2: Run and Observe

```bash
chmod +x multi-output.sls
./multi-output.sls
```

**You'll see:**
1. C++ class declaration
2. Markdown documentation
3. Python class stub

**All from one semantic model!**

### Step 4.3: Write to Separate Files

Modify the script:

```scheme
;; Write to files instead of stdout
(call-with-output-file "GpuDialect.h.inc"
  (lambda (port)
    (display (generate-cpp-header gpu-dialect) port)))

(call-with-output-file "GpuDialect.md"
  (lambda (port)
    (display (generate-markdown-doc gpu-dialect) port)))

(call-with-output-file "gpu_dialect.py"
  (lambda (port)
    (display (generate-python-stub gpu-dialect) port)))

(display "Generated 3 files:\n")
(display "  - GpuDialect.h.inc\n")
(display "  - GpuDialect.md\n")
(display "  - gpu_dialect.py\n")
```

**Key insight:** One source of truth → multiple synchronized outputs.

---

## Lesson 5: External Data

**Goal:** Generate dialect from JSON specification

### Step 5.1: Create JSON Spec

Create `accelerator-spec.json`:

```json
{
  "name": "accel",
  "description": "Hardware accelerator operations",
  "namespace": "::mlir::accel",
  "dependencies": [
    "::mlir::arith::ArithDialect",
    "::mlir::memref::MemRefDialect"
  ],
  "metadata": {
    "version": "1.0",
    "author": "Accel Team"
  }
}
```

### Step 5.2: JSON Parser

Create `json-to-dialect.sls`:

```scheme
#!/usr/bin/env scheme --program

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Simple JSON parser (simplified - use real parser in production)
(define (read-json-file filename)
  ;; In real code, use a JSON library
  ;; For tutorial, we'll use Scheme data
  '((name . "accel")
    (description . "Hardware accelerator operations")
    (namespace . "::mlir::accel")
    (dependencies . ("::mlir::arith::ArithDialect"
                     "::mlir::memref::MemRefDialect"))))

;; Convert JSON to dialect
(define (json->dialect json)
  (let ([name (cdr (assoc 'name json))]
        [desc (cdr (assoc 'description json))]
        [ns (cdr (assoc 'namespace json))]
        [deps (cdr (assoc 'dependencies json))])
    (make-dialect name ns desc deps #f #t #t)))

;; Read and generate
(define spec (read-json-file "accelerator-spec.json"))
(define accel-dialect (json->dialect spec))

;; Generate code
(display (sexp->cpp (generate-dialect-decl accel-dialect)))
```

### Step 5.3: Run It

```bash
chmod +x json-to-dialect.sls
./json-to-dialect.sls
```

**Result:** MLIR dialect generated from JSON specification!

### Step 5.4: Scaling Up

**Real-world scenario:**

```scheme
;; Read ONNX operator specification (150+ ops)
(define onnx-spec (read-json "onnx-operators.json"))

;; Generate dialect
(define onnx-dialect
  (make-dialect
    "onnx"
    "::mlir::onnx"
    (json-ref onnx-spec "description")
    (json-ref onnx-spec "dependencies")
    #f #t #t))

;; Generate operations (150+ ops)
(for-each
  (lambda (op-spec)
    (generate-onnx-op op-spec))  ; Future: define-mlir-op
  (json-ref onnx-spec "operators"))
```

**Key insight:** Generate entire dialects from external specs. Impossible with TableGen.

---

## Next Steps

### Practice Exercises

1. **Custom Namespace Pattern**
   - Create macro that enforces `::company::project::dialect` pattern
   - Add validation for namespace format

2. **Dependency Graph**
   - Write function that visualizes dialect dependencies as GraphViz
   - Generate `dialect-deps.dot` from dialect definitions

3. **Version Control**
   - Add `:version "1.0"` field to dialect
   - Generate version constants in C++

4. **Multi-Dialect Project**
   - Define 3+ related dialects
   - Generate combined documentation
   - Create dependency graph

### Read Next

- **User Guide:** [codegen-user-guide.md](codegen-user-guide.md) - Complete API reference
- **Design Doc:** [codegen-design.md](codegen-design.md) - Architecture details
- **Examples:** `examples/dialect-codegen/` - Real-world usage

### Advanced Topics (Future)

1. **Operation Definitions**
   - `define-mlir-op` macro
   - Arguments and results
   - Assembly format DSL

2. **Type Definitions**
   - `define-mlir-type` macro
   - Parameterized types
   - Type constraints

3. **CMake Integration**
   - `add_crest_dialect()` function
   - Build system integration
   - Incremental compilation

---

## Summary

**You learned:**
- ✓ Define dialects with `define-dialect`
- ✓ Generate C++ code with `generate-dialect-decl/def`
- ✓ Create custom macros for reusable patterns
- ✓ Generate multiple outputs from one definition
- ✓ Integrate external data sources (JSON)

**Key advantages over TableGen:**
- **Unified model** - one definition, many outputs
- **Macro extensibility** - define custom DSLs
- **Introspection** - query metadata programmatically
- **External data** - generate from specs

**Next phase:** Operation definitions with `define-mlir-op` (coming soon)

---

## Getting Help

- **Issues:** https://github.com/wcy123/crest/issues
- **Discussions:** https://github.com/wcy123/crest/discussions
- **Examples:** Browse `examples/dialect-codegen/`

Happy code generating!
