# CREST Dialect Codegen - Validation Plan

**Created:** 2026-10-17  
**Status:** Test infrastructure complete, ready for validation  
**Goal:** Prove CREST generates byte-for-byte identical output to TableGen

---

## Current Status

### ✅ Complete

**Test Infrastructure:**
- [x] Test runner (`run-all-tests.sh`)
- [x] Reference generator (`generate-references.sh`)
- [x] 12 comprehensive test cases
- [x] Feature matrix documentation
- [x] CI/CD integration guide

**Implementation:**
- [x] Semantic model with ALL 14 fields
- [x] Basic DSL macro
- [x] Example test cases (test-01 through test-12)
- [x] Arith dialect test case

**Documentation:**
- [x] TEST-MATRIX.md (feature catalog)
- [x] README.md (testing guide)
- [x] Test case descriptions

### ⏳ Pending

**Requires `mlir-tblgen` binary:**
- [ ] Generate TableGen references
- [ ] Run comparison tests
- [ ] Identify discrepancies
- [ ] Fix CREST code generator
- [ ] Verify byte-for-byte match

---

## Validation Steps

### Step 1: Find mlir-tblgen (REQUIRED)

**Option A: Already built**
```bash
# Check if LLVM was already built
find /home/chunywan/w/llvm-project -name mlir-tblgen -type f

# Likely location
ls /home/chunywan/w/llvm-project/build/bin/mlir-tblgen
```

**Option B: Use remote machine** (if this machine too weak)
```bash
# On remote machine with LLVM built
cd crest/test/codegen
./generate-references.sh

# Copy back to this machine
scp -r reference/ local-machine:crest/test/codegen/
```

**Option C: Pre-built binaries**
```bash
# Download LLVM release with mlir-tblgen
# https://github.com/llvm/llvm-project/releases
```

**Option D: Build MLIR** (last resort, machine is weak)
```bash
# On stronger machine or use ccache/ninja
cd /home/chunywan/w/llvm-project
mkdir -p build && cd build
cmake -G Ninja ../llvm \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="host"
ninja mlir-tblgen  # Only build tblgen, not everything
```

---

### Step 2: Generate References

Once `mlir-tblgen` is found:

```bash
cd /home/chunywan/w/crest-repo/test/codegen

# Set path if not in standard location
export TBLGEN=/path/to/mlir-tblgen

# Generate all references
./generate-references.sh
```

**Expected output:**
```
Using mlir-tblgen: /path/to/mlir-tblgen
MLIR source: /home/chunywan/w/llvm-project/mlir

Generating references from upstream MLIR dialects...
===============================================
  [GEN] Arith...
  [OK] Arith
  [GEN] Tensor...
  [OK] Tensor
  [GEN] Math...
  [OK] Math
...

Done! References generated in reference/
```

**Generated files:**
```
reference/
├── ArithDialect.h.inc.expected      # From Arith dialect
├── ArithDialect.cpp.inc.expected
├── TensorDialect.h.inc.expected     # From Tensor dialect
├── TensorDialect.cpp.inc.expected
├── MathDialect.h.inc.expected       # From Math dialect
├── MathDialect.cpp.inc.expected
└── README.md
```

---

### Step 3: Run Tests

```bash
cd /home/chunywan/w/crest-repo/test/codegen

# Run all tests
./run-all-tests.sh
```

**Possible outcomes:**

#### Outcome A: All tests pass (unlikely first try)
```
========================================
Summary
========================================
Total:  10
Passed: 10
Failed: 0

All tests passed!
```
**Action:** Celebrate! Document success. Move to Phase 2 (operations).

#### Outcome B: Some tests fail (expected)
```
Testing test-01-basic-decls... [FAIL] - Output differs from TableGen
  Diff saved to: diffs/test-01-basic-decls.diff
  First 20 lines of diff:
    --- reference/Test01Dialect.h.inc.expected
    +++ actual/Test01Dialect.h.inc
    @@ -12,7 +12,7 @@
     class Test01Dialect : public ::mlir::Dialect {
     public:
    -  explicit Test01Dialect(::mlir::MLIRContext *context);
    +  Test01Dialect(::mlir::MLIRContext *context);  // <-- Missing "explicit"
```
**Action:** Proceed to Step 4.

#### Outcome C: CREST generation fails
```
Testing test-01-basic-decls... [FAIL] - CREST generation failed
exception in sexp->cpp: invalid cpp construct
```
**Action:** Debug CREST code, fix bugs, retry.

---

### Step 4: Analyze Failures

For each failed test:

#### 4.1 Check the Diff

```bash
# View specific diff
cat diffs/test-01-basic-decls.diff

# Or use diff tool
diff -u reference/Test01Dialect.h.inc.expected \
        actual/Test01Dialect.h.inc | less
```

#### 4.2 Categorize Difference

**Acceptable (document, don't fix):**
- Comment style differences (`//` vs `/* */`)
- Whitespace (extra blank lines)
- Include order (if semantically equivalent)
- Code formatting (if functionally identical)

**Unacceptable (must fix):**
- Missing methods
- Wrong method signatures
- Wrong types
- Wrong logic
- Missing keywords (`explicit`, `override`, `const`)

#### 4.3 Document Finding

```bash
# Add to known differences (if acceptable)
echo "test-01: Comment style differs (// vs /* */)" >> KNOWN-DIFFERENCES.md

# Or file bug (if unacceptable)
echo "BUG: Missing 'explicit' keyword in constructor" >> BUGS-TO-FIX.md
```

---

### Step 5: Fix CREST

For each unacceptable difference:

#### 5.1 Locate Bug

```bash
# The bug is in code generator
vim /home/chunywan/w/crest-repo/scheme/mlir/codegen/dialect-gen.sls
```

#### 5.2 Example Fix

**Problem:** Missing `explicit` keyword

**Current code:**
```scheme
(define (generate-dialect-decl dialect)
  `(class ,(cpp-class-name dialect) : public ::mlir::Dialect {
     (method public ,(cpp-class-name dialect)
             ((::mlir::MLIRContext *context))
             ;)))
```

**Fixed code:**
```scheme
(define (generate-dialect-decl dialect)
  `(class ,(cpp-class-name dialect) : public ::mlir::Dialect {
     (method public explicit ,(cpp-class-name dialect)  ; ← Add "explicit"
             ((::mlir::MLIRContext *context))
             ;)))
```

#### 5.3 Test Fix

```bash
cd /home/chunywan/w/crest-repo/test/codegen
./run-all-tests.sh test-01-basic-decls
```

#### 5.4 Commit Fix

```bash
cd /home/chunywan/w/crest-repo
git add scheme/mlir/codegen/dialect-gen.sls
git commit -m "Fix: Add 'explicit' keyword to dialect constructor"
git push
```

---

### Step 6: Iterate Until All Pass

```bash
while [ $(./run-all-tests.sh | grep "Failed: 0" | wc -l) -eq 0 ]; do
  # Analyze failures
  ls diffs/*.diff
  
  # Fix bugs
  vim scheme/mlir/codegen/dialect-gen.sls
  
  # Re-test
  ./run-all-tests.sh
done

echo "All tests passed!"
```

---

## Expected Issues and Solutions

### Issue 1: Method Signature Differences

**Symptom:**
```diff
- explicit ArithDialect(::mlir::MLIRContext *context);
+ ArithDialect(MLIRContext *context);  // Missing :: prefix
```

**Fix:**
```scheme
;; Ensure full namespace in types
(string-append "::mlir::MLIRContext *context")
```

---

### Issue 2: Missing Methods

**Symptom:**
```diff
TableGen generates:
  void printAttribute(...) override;
  void printType(...) override;

CREST generates:
  (nothing)
```

**Fix:**
```scheme
;; Check dialect flags and generate conditionally
(when (dialect-use-default-attr-printer dialect)
  (generate-attr-printer-method))
```

---

### Issue 3: Namespace Wrapping

**Symptom:**
```diff
TableGen:
  namespace mlir {
  namespace arith {
  class ArithDialect { };
  }
  }

CREST:
  class ArithDialect { };  // Missing namespaces
```

**Fix:**
```scheme
(define (generate-dialect-decl-with-namespace dialect)
  `(namespace ,(extract-namespace dialect) {
     ,(generate-dialect-decl dialect)
     }))
```

---

### Issue 4: Comment Format

**Symptom:**
```diff
- // MLIR Dialect: arith
+ /* MLIR Dialect: arith */
```

**Decision:** ACCEPTABLE - document as known difference, or normalize.

---

## Success Criteria

### Minimum (Phase 1A)

- ✅ 3+ basic tests pass (test-01, test-02, test-03)
- ✅ Arith dialect test passes
- ✅ No semantic bugs (only formatting differences)

### Target (Phase 1B)

- ✅ ALL 10 tests pass
- ✅ Byte-for-byte match OR documented acceptable differences only
- ✅ No crashes, no exceptions

### Stretch (Phase 1C)

- ✅ Zero acceptable differences (100% identical)
- ✅ Automated CI running tests
- ✅ Used in one real project

---

## Timeline Estimate

Assuming `mlir-tblgen` is available:

| Step | Time | Notes |
|------|------|-------|
| Find mlir-tblgen | 10 min - 4 hours | Depends on availability |
| Generate references | 5 min | Automated script |
| First test run | 2 min | Will likely fail |
| Analyze failures | 1-2 hours | Categorize ~10-20 differences |
| Fix CREST bugs | 4-8 hours | Update dialect-gen.sls |
| Iterate to passing | 2-4 hours | Fix remaining issues |
| **Total** | **1-2 days** | Assuming mlir-tblgen available |

If need to build MLIR:
- Add 2-4 hours (on fast machine)
- Add 8-24 hours (on this weak machine)

---

## Next Actions

**Immediate (You):**
1. Find `mlir-tblgen` binary
2. Run `./generate-references.sh`
3. Run `./run-all-tests.sh`
4. Report results

**Then (Me):**
1. Analyze failures from your run
2. Fix CREST bugs
3. Push fixes
4. You re-test
5. Iterate until passing

---

## Contact

**Questions?**
- Check README.md
- Check TEST-MATRIX.md
- Open GitHub issue

**Ready to validate?**
- Run `./generate-references.sh`
- Run `./run-all-tests.sh`
- Share results!
