# Code Generation Regression Tests

This directory contains regression tests that verify CREST's code generation produces **byte-for-byte identical output** to TableGen for all supported features.

## Test Strategy

### 1. Reference Outputs from TableGen

Extract reference outputs from existing MLIR dialects:

```bash
# Generate reference from upstream MLIR
mlir-tblgen -gen-dialect-decls mlir/include/mlir/Dialect/Arith/IR/ArithOps.td \
  > test/codegen/reference/ArithDialect.h.inc.expected

mlir-tblgen -gen-dialect-defs mlir/include/mlir/Dialect/Arith/IR/ArithOps.td \
  > test/codegen/reference/ArithDialect.cpp.inc.expected
```

### 2. CREST Implementation

Define equivalent dialect in Scheme:

```scheme
;; test/codegen/dialects/arith-dialect.sls
(define arith-dialect
  (define-dialect
    :name "arith"
    :cpp-namespace "::mlir::arith"
    :description "..."
    :depends-on (...)))
```

### 3. Compare Outputs

```bash
# Generate with CREST
scheme --program arith-dialect.sls > ArithDialect.h.inc.actual

# Compare byte-for-byte
diff -u ArithDialect.h.inc.expected ArithDialect.h.inc.actual
```

### 4. Automated Test Suite

```bash
# Run all regression tests
./test/codegen/run-all-tests.sh

# Output:
# [PASS] arith-dialect-decls: outputs match
# [PASS] arith-dialect-defs: outputs match
# [FAIL] tensor-dialect-decls: difference at line 42
```

## Test Coverage

### Phase 1: Dialect Features (Current)

- [ ] Basic dialect declaration
- [ ] Dependent dialects
- [ ] Custom namespace
- [ ] Extra class declarations
- [ ] Attribute printer override
- [ ] Type printer override

### Phase 2: Operation Features (Future)

- [ ] Basic operation definition
- [ ] Arguments (ins dag)
- [ ] Results (outs dag)
- [ ] Optional operands
- [ ] Variadic operands
- [ ] Traits
- [ ] Interfaces
- [ ] Assembly format
- [ ] Verifiers
- [ ] Builders

### Phase 3: Type/Attribute Features (Future)

- [ ] Type definitions
- [ ] Attribute definitions
- [ ] Parameterized types
- [ ] Type constraints

## Directory Structure

```
test/codegen/
├── README.md                    # This file
├── run-all-tests.sh             # Main test runner
├── compare-outputs.sh           # Diff helper
├── dialects/                    # CREST dialect definitions
│   ├── arith-dialect.sls
│   ├── tensor-dialect.sls
│   └── func-dialect.sls
├── reference/                   # TableGen outputs (expected)
│   ├── ArithDialect.h.inc.expected
│   ├── ArithDialect.cpp.inc.expected
│   ├── TensorDialect.h.inc.expected
│   └── TensorDialect.cpp.inc.expected
├── actual/                      # CREST outputs (generated)
│   ├── ArithDialect.h.inc
│   └── ArithDialect.cpp.inc
└── diffs/                       # Diff reports
    └── arith-dialect-decls.diff
```

## Running Tests

### Full Test Suite
```bash
cd test/codegen
./run-all-tests.sh
```

### Single Test
```bash
./run-all-tests.sh arith-dialect-decls
```

### Update Reference Outputs
```bash
# When TableGen output changes (MLIR updates)
./update-reference.sh arith-dialect
```

### Accept CREST Output as New Reference
```bash
# When we fix a CREST bug and output improves
./accept-actual.sh arith-dialect-decls
```

## Test Failure Analysis

When a test fails:

1. **Check the diff**
   ```bash
   cat diffs/arith-dialect-decls.diff
   ```

2. **Identify the difference**
   - Whitespace? (formatting bug)
   - Comment text? (acceptable difference)
   - Code structure? (semantic bug - must fix)

3. **Categories of acceptable differences**
   - Comment formatting (e.g., `//` vs `/* */`)
   - Blank line counts
   - Include order (if semantically equivalent)

4. **Categories of unacceptable differences**
   - Missing methods
   - Wrong types
   - Wrong namespace
   - Wrong class hierarchy

## Integration with CI

```yaml
# .github/workflows/codegen-tests.yml
name: Code Generation Tests

on: [push, pull_request]

jobs:
  regression-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Chez Scheme
        run: sudo apt-get install chezscheme
      - name: Run regression tests
        run: cd test/codegen && ./run-all-tests.sh
      - name: Upload diff reports
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: codegen-diffs
          path: test/codegen/diffs/
```

## Writing New Tests

### 1. Find TableGen Source
```bash
# Example: Arith dialect
find llvm-project -name "ArithOps.td"
# → mlir/include/mlir/Dialect/Arith/IR/ArithOps.td
```

### 2. Extract Dialect Definition
```tablegen
def Arith_Dialect : Dialect {
  let name = "arith";
  let cppNamespace = "::mlir::arith";
  let description = [{
    The arith dialect is intended to hold basic integer and floating point
    mathematical operations.
  }];
  let dependentDialects = [];
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
}
```

### 3. Generate Reference Output
```bash
mlir-tblgen -gen-dialect-decls ArithOps.td > reference/ArithDialect.h.inc.expected
```

### 4. Write CREST Equivalent
```scheme
(define arith-dialect
  (define-dialect
    :name "arith"
    :cpp-namespace "::mlir::arith"
    :description "The arith dialect is intended to hold basic integer and floating point mathematical operations."
    :depends-on ()))
```

### 5. Add to Test Suite
```bash
# Edit run-all-tests.sh
register_test "arith-dialect-decls" \
  "dialects/arith-dialect.sls" \
  "generate-dialect-decl" \
  "reference/ArithDialect.h.inc.expected"
```

## Known Limitations

### What We DON'T Test

1. **Runtime behavior** - only compile-time code generation
2. **MLIR compilation** - don't build generated C++ (yet)
3. **Semantic equivalence** - only byte-for-byte match

### Future Testing

- **Compilation tests**: Does generated C++ compile?
- **Integration tests**: Does MLIR load the dialect?
- **Functional tests**: Do operations work correctly?

## Maintenance

### When TableGen Output Changes

MLIR updates may change TableGen code generation. When this happens:

1. Update reference outputs: `./update-reference.sh <dialect>`
2. Verify CREST matches new format
3. Document the change in `CHANGELOG.md`

### When Adding New Features

1. Find TableGen example that uses the feature
2. Extract reference output
3. Implement in CREST
4. Add regression test
5. Verify byte-for-byte match
