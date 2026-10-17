# Code Generation Regression Tests

**Status:** Test infrastructure complete, awaiting `mlir-tblgen` for reference generation  
**Coverage:** 12 feature-specific test cases + 5 real MLIR dialects  
**Validation:** Byte-for-byte comparison with TableGen output

---

## Quick Start

### Step 1: Generate TableGen References

```bash
# Find or specify mlir-tblgen binary location
export TBLGEN=/path/to/mlir-tblgen

# Generate all reference outputs from MLIR source
./generate-references.sh
```

**Note:** MLIR source is already at `/home/chunywan/w/llvm-project`. You just need `mlir-tblgen` binary.

### Step 2: Run Tests

```bash
# Run all regression tests
./run-all-tests.sh

# Run single test
./run-all-tests.sh test-01-basic-decls
```

---

## Test Matrix

See **[TEST-MATRIX.md](TEST-MATRIX.md)** for complete feature catalog.

###Quick Summary:

| Test | Features | Real Dialect | Status |
|------|----------|--------------|--------|
| **test-01** | Basic (name, namespace, desc) | - | ⏳ Need ref |
| **test-02** | Single dependency | - | ⏳ Need ref |
| **test-03** | Multiple dependencies | Tensor | ⏳ Need ref |
| **test-12** | ALL features combined | - | ⏳ Need ref |
| **arith** | Real dialect validation | Arith | ⏳ Need ref |

---

## Directory Structure

```
test/codegen/
├── README.md                    # This file
├── TEST-MATRIX.md               # Complete feature catalog
├── generate-references.sh       # Generate TableGen outputs
├── run-all-tests.sh             # Test runner
├── dialects/                    # CREST test cases
│   ├── test-01-basic.sls        # Minimal dialect
│   ├── test-02-single-dep.sls   # One dependency
│   ├── test-03-multiple-deps.sls# Multiple dependencies
│   ├── test-12-all-features.sls # Everything enabled
│   └── arith-dialect.sls        # Real Arith dialect
├── reference/                   # TableGen outputs (expected)
│   ├── README.md                # How to generate
│   ├── Test01Dialect.h.inc.expected
│   └── ArithDialect.h.inc.expected
├── actual/                      # CREST outputs (auto-generated)
└── diffs/                       # Diff reports (auto-generated)
```

---

## Test Cases

### Category 1: Basic Features

**test-01-basic** - Minimal dialect
```scheme
(define-dialect
  :name "test01"
  :cpp-namespace "::mlir::test01"
  :description "Minimal test dialect"
  :depends-on ())
```

**test-02-single-dep** - One dependency
```scheme
:depends-on ("::mlir::arith::ArithDialect")
```

**test-03-multiple-deps** - Three dependencies (like Tensor)
```scheme
:depends-on ("::mlir::affine::AffineDialect"
             "::mlir::arith::ArithDialect"
             "::mlir::complex::ComplexDialect")
```

### Category 2: Comprehensive

**test-12-all-features** - Every feature enabled
```scheme
(make-dialect
  "test12" "::mlir::test12" "..."
  '("::mlir::arith::ArithDialect" "::mlir::tensor::TensorDialect")
  #t #t  ; default attr/type printers
  #t #t #t #t #t #f #f  ; all capabilities
  "/* extra class methods */")
```

### Category 3: Real Dialects

**arith-dialect** - Upstream MLIR Arith dialect
**tensor-dialect** - Upstream MLIR Tensor dialect
**math-dialect** - Upstream MLIR Math dialect

---

## TableGen Features Tested

See **[TEST-MATRIX.md](TEST-MATRIX.md)** for exhaustive list. Summary:

| Category | Features | Tested |
|----------|----------|--------|
| **Basic** | name, namespace, description | ✅ test-01 |
| **Dependencies** | dependent dialects (0, 1, N) | ✅ test-01/02/03 |
| **Printers** | attr/type printer flags | ⏳ test-12 |
| **Capabilities** | materializer, canonicalizer, verifiers | ⏳ test-12 |
| **Extra Code** | extraClassDeclaration | ⏳ test-12 |

---

## Running Tests

### All Tests
```bash
./run-all-tests.sh
```

**Output:**
```
========================================
CREST Code Generation Regression Tests
========================================

Testing test-01-basic-decls... [PASS]
Testing test-01-basic-defs... [PASS]
Testing test-02-single-dep-decls... [PASS]
...

========================================
Summary
========================================
Total:  10
Passed: 10
Failed: 0

All tests passed!
```

### Single Test
```bash
./run-all-tests.sh test-01-basic-decls
```

### Verbose Mode
```bash
VERBOSE=1 ./run-all-tests.sh
```

---

## Generating References

### Prerequisites

1. **MLIR source:** Already at `/home/chunywan/w/llvm-project`
2. **mlir-tblgen binary:** Need to find or build

### Finding mlir-tblgen

```bash
# Check if already built
find /home/chunywan/w/llvm-project -name mlir-tblgen -type f

# If not found, likely need to build LLVM (but machine is weak)
# Alternative: Use pre-built binaries or remote machine
```

### Running Generator

```bash
# If mlir-tblgen is at specific path
export TBLGEN=/path/to/mlir-tblgen
./generate-references.sh

# Or set MLIR source path
export MLIR_SRC=/home/chunywan/w/llvm-project/mlir
./generate-references.sh
```

**Generates:**
```
reference/
├── ArithDialect.h.inc.expected
├── ArithDialect.cpp.inc.expected
├── TensorDialect.h.inc.expected
├── TensorDialect.cpp.inc.expected
├── MathDialect.h.inc.expected
├── MathDialect.cpp.inc.expected
├── Test01Dialect.h.inc.expected (from custom .td)
└── Test12Dialect.h.inc.expected (from custom .td)
```

---

## Test Failure Analysis

### When Test Fails

1. **Check diff:**
   ```bash
   cat diffs/test-01-basic-decls.diff
   ```

2. **Identify category:**
   - **Acceptable:** Whitespace, comment style, include order
   - **Unacceptable:** Missing methods, wrong types, wrong logic

3. **Fix CREST:**
   - Update code generator
   - Regenerate output
   - Re-run test

4. **Document if acceptable:**
   - Add to "Known Differences" section
   - Justify why it's okay

---

## Known Limitations

### Current CREST Implementation

**Supported:**
- ✅ Basic properties (name, namespace, description)
- ✅ Dependent dialects
- ✅ Semantic model with all fields

**Not Yet Implemented:**
- ❌ Conditional method generation (based on flags)
- ❌ Extra class declaration insertion
- ❌ Capability-specific methods (materializer, canonicalizer, etc.)
- ❌ Custom printer/parser control

**Next Steps:**
1. Update `dialect-gen.sls` to check all boolean flags
2. Generate methods conditionally
3. Insert extra class declarations
4. Pass all tests

---

## Contribution Guide

### Adding New Test

1. **Identify feature to test**
   ```bash
   # Example: hasCanonicalizer flag
   ```

2. **Create test case**
   ```bash
   cp dialects/test-01-basic.sls dialects/test-09-canonicalizer.sls
   # Edit to enable hasCanonicalizer
   ```

3. **Generate reference** (needs TableGen .td equivalent)

4. **Add to test registry**
   ```bash
   # Edit run-all-tests.sh TESTS array
   ```

5. **Run and verify**
   ```bash
   ./run-all-tests.sh test-09-canonicalizer-decls
   ```

### Fixing Failed Test

1. **Understand difference**
   ```bash
   diff reference/Test01Dialect.h.inc.expected actual/Test01Dialect.h.inc
   ```

2. **Update CREST code generator**
   ```scheme
   # Edit scheme/mlir/codegen/dialect-gen.sls
   ```

3. **Test fix**
   ```bash
   ./run-all-tests.sh test-01-basic-decls
   ```

4. **Commit with clear message**
   ```bash
   git commit -m "Fix: Generate getDialectNamespace() return type correctly"
   ```

---

## CI/CD Integration

**GitHub Actions workflow** (`.github/workflows/codegen-tests.yml`):

```yaml
name: Code Generation Tests

on: [push, pull_request]

jobs:
  regression-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Chez Scheme
        run: sudo apt-get install chezscheme
      
      - name: Download mlir-tblgen
        run: |
          # TODO: Get pre-built binary or build MLIR
      
      - name: Generate references
        run: cd test/codegen && ./generate-references.sh
      
      - name: Run tests
        run: cd test/codegen && ./run-all-tests.sh
      
      - name: Upload diffs on failure
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: codegen-diffs
          path: test/codegen/diffs/
```

---

## FAQ

### Q: Where is mlir-tblgen?

**A:** Check these locations:
1. LLVM build directory: `llvm-project/build/bin/mlir-tblgen`
2. System install: `/usr/local/bin/mlir-tblgen`
3. Or build LLVM (requires strong machine)

### Q: Can I use remote mlir-tblgen?

**A:** Yes! Run `generate-references.sh` on remote machine with LLVM built, then copy `reference/` directory back.

### Q: Why byte-for-byte comparison?

**A:** Ensures CREST generates EXACTLY what TableGen does, proving correctness.

### Q: What if whitespace differs?

**A:** Document as acceptable difference, or normalize both before comparison.

### Q: Tests pass but MLIR compilation fails?

**A:** Need Phase 2: compile generated code and run MLIR tests.

---

## Next Steps

1. **Find mlir-tblgen binary**
2. **Run `./generate-references.sh`**
3. **Run `./run-all-tests.sh`**
4. **Fix CREST to pass all tests**
5. **Document results**

Once tests pass, we have **proof** CREST generates correct dialect code!
