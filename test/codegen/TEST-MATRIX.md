# TableGen Dialect Feature Test Matrix

This document catalogs ALL TableGen features used in MLIR dialect definitions and maps them to test cases.

---

## Feature Categories

### Category 1: Basic Dialect Properties

| Feature | TableGen Syntax | Example Dialect | Test Case | Status |
|---------|-----------------|-----------------|-----------|--------|
| **Name** | `let name = "arith"` | Arith | `test-01-basic` | ⏳ TODO |
| **C++ Namespace** | `let cppNamespace = "::mlir::arith"` | Arith | `test-01-basic` | ⏳ TODO |
| **Description** | `let description = [{ ... }]` | Arith | `test-01-basic` | ⏳ TODO |

### Category 2: Dependent Dialects

| Feature | TableGen Syntax | Example | Test Case | Status |
|---------|-----------------|---------|-----------|--------|
| **No dependencies** | (omit field) | Arith | `test-01-basic` | ⏳ TODO |
| **Single dependency** | `let dependentDialects = ["arith::ArithDialect"]` | Many | `test-02-deps-single` | ⏳ TODO |
| **Multiple dependencies** | `let dependentDialects = ["A", "B", "C"]` | Tensor | `test-03-deps-multiple` | ⏳ TODO |

### Category 3: Attribute/Type Printer/Parser

| Feature | TableGen Syntax | Example | Test Case | Status |
|---------|-----------------|---------|-----------|--------|
| **Default attr printer** | `let useDefaultAttributePrinterParser = 1` | Arith | `test-04-default-attr-printer` | ⏳ TODO |
| **Custom attr printer** | (omit field or = 0) | | `test-05-custom-attr-printer` | ⏳ TODO |
| **Default type printer** | `let useDefaultTypePrinterParser = 1` | | `test-06-default-type-printer` | ⏳ TODO |
| **Custom type printer** | (omit field or = 0) | | `test-07-custom-type-printer` | ⏳ TODO |

### Category 4: Dialect Capabilities

| Feature | TableGen Syntax | Example | Test Case | Status |
|---------|-----------------|---------|-----------|--------|
| **Constant materializer** | `let hasConstantMaterializer = 1` | Arith, Tensor | `test-08-const-materializer` | ⏳ TODO |
| **Canonicalizer** | `let hasCanonicalizer = 1` | Tensor | `test-09-canonicalizer` | ⏳ TODO |
| **Operation attr verify** | `let hasOperationAttrVerify = 1` | | `test-10-op-attr-verify` | ⏳ TODO |
| **Region arg attr verify** | `let hasRegionArgAttrVerify = 1` | | `test-11-region-attr-verify` | ⏳ TODO |
| **Region result attr verify** | `let hasRegionResultAttrVerify = 1` | | `test-12-region-result-verify` | ⏳ TODO |
| **Non-default destructors** | `let hasNonDefaultDestructor = 1` | | `test-13-non-default-dtor` | ⏳ TODO |

### Category 5: Extra Class Declaration

| Feature | TableGen Syntax | Example | Test Case | Status |
|---------|-----------------|---------|-----------|--------|
| **No extra code** | (omit field) | Arith | `test-01-basic` | ⏳ TODO |
| **Extra methods** | `let extraClassDeclaration = [{ code }]` | | `test-14-extra-methods` | ⏳ TODO |
| **Extra includes** | Include C++ code block | | `test-15-extra-includes` | ⏳ TODO |

### Category 6: Fallback Operations

| Feature | TableGen Syntax | Example | Test Case | Status |
|---------|-----------------|---------|-----------|--------|
| **Fallback for verifier** | `let hasOperationInterfaceFallback = 1` | | `test-16-interface-fallback` | ⏳ TODO |

---

## Test Case Catalog

### Test 01: Basic Minimal Dialect
**File:** `test-01-basic-dialect.sls`  
**Features:** name, cppNamespace, description only  
**Reference:** Arith (simplified)

```scheme
(define test-01-dialect
  (define-dialect
    :name "test01"
    :cpp-namespace "::mlir::test01"
    :description "Minimal test dialect with only basic fields"
    :depends-on ()))
```

**Expected output:**
```cpp
class Test01Dialect : public ::mlir::Dialect {
  // ...standard methods only
};
```

---

### Test 02: Single Dependency
**File:** `test-02-single-dep.sls`  
**Features:** One dependent dialect  
**Reference:** Many dialects depend on Arith

```scheme
(define test-02-dialect
  (define-dialect
    :name "test02"
    :cpp-namespace "::mlir::test02"
    :description "Dialect with single dependency"
    :depends-on ("::mlir::arith::ArithDialect")))
```

**Expected in constructor:**
```cpp
Test02Dialect::Test02Dialect(MLIRContext *context) {
  getContext()->getOrLoadDialect<::mlir::arith::ArithDialect>();
  initialize();
}
```

---

### Test 03: Multiple Dependencies
**File:** `test-03-multiple-deps.sls`  
**Features:** Three dependent dialects  
**Reference:** Tensor dialect

```scheme
(define test-03-dialect
  (define-dialect
    :name "test03"
    :cpp-namespace "::mlir::test03"
    :description "Dialect with multiple dependencies"
    :depends-on ("::mlir::affine::AffineDialect"
                 "::mlir::arith::ArithDialect"
                 "::mlir::complex::ComplexDialect")))
```

**Expected:**
```cpp
Test03Dialect::Test03Dialect(MLIRContext *context) {
  getContext()->getOrLoadDialect<::mlir::affine::AffineDialect>();
  getContext()->getOrLoadDialect<::mlir::arith::ArithDialect>();
  getContext()->getOrLoadDialect<::mlir::complex::ComplexDialect>();
  initialize();
}
```

---

### Test 04: Default Attribute Printer
**File:** `test-04-default-attr-printer.sls`  
**Features:** useDefaultAttributePrinterParser = 1

```scheme
(define test-04-dialect
  (define-dialect
    :name "test04"
    :cpp-namespace "::mlir::test04"
    :description "Uses default attribute printer/parser"
    :depends-on ()
    :use-default-attr-printer #t))
```

**Expected methods:**
```cpp
// Declaration
::mlir::Attribute parseAttribute(::mlir::DialectAsmParser &parser,
                                  ::mlir::Type type) const override;
void printAttribute(::mlir::Attribute attr,
                   ::mlir::DialectAsmPrinter &os) const override;
```

---

### Test 05: Custom Attribute Printer
**File:** `test-05-custom-attr-printer.sls`  
**Features:** useDefaultAttributePrinterParser = 0 (or omitted)

```scheme
(define test-05-dialect
  (define-dialect
    :name "test05"
    :cpp-namespace "::mlir::test05"
    :description "Uses custom attribute printer/parser"
    :depends-on ()
    :use-default-attr-printer #f))
```

**Expected:** NO parseAttribute/printAttribute methods generated

---

### Test 06: Default Type Printer
**File:** `test-06-default-type-printer.sls`  
**Features:** useDefaultTypePrinterParser = 1

```scheme
(define test-06-dialect
  (define-dialect
    :name "test06"
    :cpp-namespace "::mlir::test06"
    :description "Uses default type printer/parser"
    :depends-on ()
    :use-default-type-printer #t))
```

**Expected methods:**
```cpp
::mlir::Type parseType(::mlir::DialectAsmParser &parser) const override;
void printType(::mlir::Type type,
              ::mlir::DialectAsmPrinter &os) const override;
```

---

### Test 07: Custom Type Printer
**File:** `test-07-custom-type-printer.sls`  
**Features:** useDefaultTypePrinterParser = 0

```scheme
(define test-07-dialect
  (define-dialect
    :name "test07"
    :cpp-namespace "::mlir::test07"
    :description "Uses custom type printer/parser"
    :depends-on ()
    :use-default-type-printer #f))
```

**Expected:** NO parseType/printType methods

---

### Test 08: Constant Materializer
**File:** `test-08-const-materializer.sls`  
**Features:** hasConstantMaterializer = 1

```scheme
(define test-08-dialect
  (define-dialect
    :name "test08"
    :cpp-namespace "::mlir::test08"
    :description "Has constant materializer"
    :depends-on ()
    :has-constant-materializer #t))
```

**Expected method:**
```cpp
::mlir::Operation *materializeConstant(::mlir::OpBuilder &builder,
                                        ::mlir::Attribute value,
                                        ::mlir::Type type,
                                        ::mlir::Location loc) override;
```

---

### Test 09: Canonicalizer
**File:** `test-09-canonicalizer.sls`  
**Features:** hasCanonicalizer = 1

```scheme
(define test-09-dialect
  (define-dialect
    :name "test09"
    :cpp-namespace "::mlir::test09"
    :description "Has canonicalizer patterns"
    :depends-on ()
    :has-canonicalizer #t))
```

**Expected:**
```cpp
void getCanonicalizationPatterns(::mlir::RewritePatternSet &results) const override;
```

---

### Test 10: Operation Attribute Verify
**File:** `test-10-op-attr-verify.sls`  
**Features:** hasOperationAttrVerify = 1

```scheme
(define test-10-dialect
  (define-dialect
    :name "test10"
    :cpp-namespace "::mlir::test10"
    :description "Verifies operation attributes"
    :depends-on ()
    :has-op-attr-verify #t))
```

**Expected:**
```cpp
::mlir::LogicalResult verifyOperationAttribute(::mlir::Operation *op,
                                                ::mlir::NamedAttribute attr) override;
```

---

### Test 11: Extra Class Declaration
**File:** `test-11-extra-class-decl.sls`  
**Features:** extraClassDeclaration = [{ code }]

```scheme
(define test-11-dialect
  (define-dialect
    :name "test11"
    :cpp-namespace "::mlir::test11"
    :description "Dialect with extra class declarations"
    :depends-on ()
    :extra-class-decl "
  // Custom helper methods
  static bool isValidType(::mlir::Type type);
  void registerPasses();
"))
```

**Expected in class:**
```cpp
class Test11Dialect : public ::mlir::Dialect {
public:
  // ... standard methods ...
  
  // Custom helper methods
  static bool isValidType(::mlir::Type type);
  void registerPasses();
};
```

---

### Test 12: All Features Combined
**File:** `test-12-all-features.sls`  
**Features:** Everything enabled

```scheme
(define test-12-dialect
  (define-dialect
    :name "test12"
    :cpp-namespace "::mlir::test12"
    :description "Dialect with all features enabled for comprehensive testing"
    :depends-on ("::mlir::arith::ArithDialect"
                 "::mlir::tensor::TensorDialect")
    :use-default-attr-printer #t
    :use-default-type-printer #t
    :has-constant-materializer #t
    :has-canonicalizer #t
    :has-op-attr-verify #t
    :extra-class-decl "
  // Project-specific helpers
  static bool isQuantizedType(::mlir::Type type);
"))
```

**Expected:** All methods present

---

## Reference Generation Script

```bash
#!/bin/bash
# Generate all TableGen references from MLIR source

MLIR_SRC="/home/chunywan/w/llvm-project/mlir"
TBLGEN="/path/to/mlir-tblgen"  # TODO: Find this
REF_DIR="./reference"

# Helper function
gen_ref() {
  local name=$1
  local td_file=$2
  
  echo "Generating ${name}..."
  $TBLGEN -gen-dialect-decls -I ${MLIR_SRC}/include ${td_file} \
    > ${REF_DIR}/${name}Dialect.h.inc.expected
  
  $TBLGEN -gen-dialect-defs -I ${MLIR_SRC}/include ${td_file} \
    > ${REF_DIR}/${name}Dialect.cpp.inc.expected
}

# Real dialects for comparison
gen_ref "Arith" "${MLIR_SRC}/include/mlir/Dialect/Arith/IR/ArithBase.td"
gen_ref "Tensor" "${MLIR_SRC}/include/mlir/Dialect/Tensor/IR/TensorBase.td"
gen_ref "Math" "${MLIR_SRC}/include/mlir/Dialect/Math/IR/MathBase.td"

echo "References generated in ${REF_DIR}/"
```

---

## Validation Checklist

For each test case:
- [ ] CREST dialect definition created
- [ ] TableGen reference generated
- [ ] CREST output generated
- [ ] Byte-for-byte comparison performed
- [ ] Differences documented (if any)
- [ ] Test added to `run-all-tests.sh`

---

## Known Limitations (Current CREST)

Features NOT yet implemented:
- ❌ `hasConstantMaterializer`
- ❌ `hasCanonicalizer`
- ❌ `hasOperationAttrVerify`
- ❌ `hasRegionArgAttrVerify`
- ❌ `hasRegionResultAttrVerify`
- ❌ `hasNonDefaultDestructor`
- ❌ Custom attribute/type printers (control)
- ❌ Extra class declaration

**Current CREST only supports:**
- ✅ name
- ✅ cppNamespace
- ✅ description
- ✅ dependentDialects
- ⚠️ Hardcoded: useDefaultAttributePrinterParser = 1
- ⚠️ Hardcoded: useDefaultTypePrinterParser = 1

---

## Implementation Priority

**Phase 1A (Immediate):**
1. Fix semantic model to support all fields
2. Implement all boolean flags
3. Implement extraClassDeclaration
4. Generate references for Tests 01-03

**Phase 1B (This Week):**
5. Generate references for Tests 04-12
6. Fix CREST to pass all tests
7. Document acceptable differences

**Phase 2 (Next):**
- Operation definitions
- Assembly format
- Verifiers
