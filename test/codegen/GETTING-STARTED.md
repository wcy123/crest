# Getting Started - CREST Dialect Code Generation Testing

**For:** Developers validating CREST against TableGen  
**Time:** 10-30 minutes to generate baseline  
**Goal:** Prove CREST generates identical output to TableGen

---

## Quick Overview

```
TableGen (.td files)  →  mlir-tblgen  →  .h.inc/.cpp.inc  ←  CREST must match
     ↓                                        ↓
  Baseline                                 Our implementation
 (ground truth)                          (what we're testing)
```

**This directory contains:**
- `.td` files (TableGen input) - covers ALL 17 dialect features
- Script to generate baseline from TableGen
- Test runner to compare CREST vs TableGen output

---

## Prerequisites

You need:
1. ✅ LLVM source at `~/w/llvm-project`
2. ⏳ `mlir-tblgen` binary (will build if needed)
3. ✅ Chez Scheme (for running CREST)

---

## Step 1: Check What You Have

```bash
cd ~/w/crest-repo/test/codegen

# Quick diagnostic
echo "Test files:"; ls tablegen/test-*.td | wc -l  # Should be 7
echo "MLIR source:"; ls ~/w/llvm-project/mlir >/dev/null && echo "✓ Found" || echo "✗ Missing"
echo "mlir-tblgen:"; find ~/w/llvm-project -name mlir-tblgen -type f || echo "✗ Need to build"
```

---

## Step 2: Build mlir-tblgen (if needed)

### Check if already built:
```bash
ls ~/w/llvm-project/build/bin/mlir-tblgen
```

### If NOT found, build it:

**Option A: Quick build (RECOMMENDED - only builds tblgen, ~5-10 min)**
```bash
cd ~/w/llvm-project
mkdir -p build && cd build

# Configure (if first time)
cmake -G Ninja ../llvm \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DCMAKE_BUILD_TYPE=Release

# Build ONLY mlir-tblgen (not all of LLVM)
ninja mlir-tblgen

# Verify
./bin/mlir-tblgen --version
```

**Option B: System-wide install**
```bash
which mlir-tblgen  # If found, use this path
```

**Option C: Use remote build server**
```bash
# On fast remote machine with LLVM built:
scp remote:~/llvm-project/build/bin/mlir-tblgen ~/bin/
```

---

## Step 3: Generate TableGen Baseline

```bash
cd ~/w/crest-repo/test/codegen

# Set mlir-tblgen path
export TBLGEN=~/w/llvm-project/build/bin/mlir-tblgen
# Or: export TBLGEN=/path/to/your/mlir-tblgen

# Generate references from all .td files
./generate-all-references.sh
```

**Expected output:**
```
==========================================
TableGen Reference Generation
==========================================
mlir-tblgen: /home/user/w/llvm-project/build/bin/mlir-tblgen
MLIR source: /home/user/w/llvm-project/mlir

Processing TableGen test files...
==========================================
Generating test-01-minimal...
  [GEN] Test01...
  [OK] Test01Dialect
Generating test-02-dependencies...
  [GEN] Test02Single...
  [OK] Test02SingleDialect
  [GEN] Test02Multiple...
  [OK] Test02MultipleDialect
...

==========================================
Reference generation complete!
==========================================

Generated files in: reference/
Total files: 40
```

---

## Step 4: Verify References Generated

```bash
# List generated files
ls reference/*.expected

# Count them
ls reference/*.expected | wc -l  # Should be 30-40 files

# Inspect one
head -30 reference/Test01_Dialect.h.inc.expected
```

**You should see C++ code like:**
```cpp
class Test01Dialect : public ::mlir::Dialect {
public:
  explicit Test01Dialect(::mlir::MLIRContext *context);
  
  static constexpr ::llvm::StringLiteral getDialectNamespace() {
    return ::llvm::StringLiteral("test01");
  }
  
  void initialize();
};
```

---

## Step 5: Run Tests (After CREST Implementation)

```bash
# This will fail initially (CREST not implemented yet)
./run-all-tests.sh

# Expected output (initially):
# Testing test-01-minimal-decls... [FAIL] - CREST generation failed
# (Because CREST doesn't support all features yet)
```

**Once CREST is implemented, you should see:**
```
Testing test-01-minimal-decls... [PASS]
Testing test-01-minimal-defs... [PASS]
...
All tests passed!
```

---

## What the Test Files Cover

See `tablegen/COMPLETE-FEATURE-LIST.md` for details.

### Quick summary:
- **test-01-minimal.td** - Baseline (name, namespace, description)
- **test-02-dependencies.td** - Dependent dialects
- **test-03-printers.td** - Attribute/type printer flags
- **test-04-discardable-attrs.td** - DAG type (generates helpers)
- **test-04-capabilities.td** - All has* flags
- **test-05-extra-features.td** - Advanced features
- **test-06-comprehensive.td** - **ALL 17 fields in one dialect**

**Total: 17 dialect fields, 100% coverage**

---

## Troubleshooting

### Problem: mlir-tblgen not found

**Solution:**
```bash
cd ~/w/llvm-project/build
ninja mlir-tblgen
```

### Problem: generate-all-references.sh fails

**Check:**
```bash
# Is TBLGEN set?
echo $TBLGEN

# Is it executable?
$TBLGEN --version

# Is MLIR source accessible?
ls ~/w/llvm-project/mlir/include/mlir/IR/DialectBase.td
```

### Problem: Permission denied

```bash
chmod +x generate-all-references.sh
chmod +x run-all-tests.sh
```

### Problem: Slow build

- Build only `mlir-tblgen` (not full LLVM): `ninja mlir-tblgen`
- Use remote build server
- Use pre-built LLVM binary release

---

## Understanding the Test Flow

### 1. TableGen Input (.td file)
```tablegen
def MyDialect : Dialect {
  let name = "my";
  let cppNamespace = "::mlir::my";
}
```

### 2. TableGen Output (.h.inc - baseline)
```cpp
class MyDialect : public ::mlir::Dialect {
  explicit MyDialect(::mlir::MLIRContext *context);
  // ... methods
};
```

### 3. CREST Input (.sls file)
```scheme
(define my-dialect
  (define-dialect
    :name "my"
    :cpp-namespace "::mlir::my"))
```

### 4. CREST Output (.h.inc - must match #2)
```cpp
class MyDialect : public ::mlir::Dialect {
  explicit MyDialect(::mlir::MLIRContext *context);
  // ... SAME methods as TableGen
};
```

### 5. Validation
```bash
diff -u baseline.h.inc crest-output.h.inc
# Exit code 0 = identical = SUCCESS
```

---

## Directory Structure

```
test/codegen/
├── GETTING-STARTED.md           # ← You are here
├── README.md                     # Detailed documentation
├── VALIDATION-PLAN.md            # Step-by-step validation
│
├── tablegen/                     # TableGen baseline inputs
│   ├── README.md                 # What each .td tests
│   ├── COMPLETE-FEATURE-LIST.md  # All 17 fields explained
│   ├── test-01-minimal.td        # 7 test files
│   └── ...
│
├── generate-all-references.sh    # Generate baseline
├── run-all-tests.sh              # Run validation
│
├── reference/                    # TableGen output (generated)
│   ├── *.h.inc.expected
│   └── *.cpp.inc.expected
│
└── actual/                       # CREST output (generated)
    ├── *.h.inc
    └── *.cpp.inc
```

---

## Quick Start Commands

```bash
# 1. Clone and navigate
cd ~/w/crest-repo/test/codegen

# 2. Build mlir-tblgen (if needed)
cd ~/w/llvm-project/build && ninja mlir-tblgen

# 3. Generate baseline
cd ~/w/crest-repo/test/codegen
export TBLGEN=~/w/llvm-project/build/bin/mlir-tblgen
./generate-all-references.sh

# 4. Verify
ls reference/*.expected | wc -l  # Should be 30-40

# 5. Inspect
cat reference/Test06Comprehensive_Dialect.h.inc.expected
```

---

## Next Steps for Development

1. ✅ **Generate baseline** (this guide)
2. ⏳ **Inspect TableGen output** - understand what to generate
3. ⏳ **Extend CREST semantic model** - support all 17 fields
4. ⏳ **Implement code generation** - match TableGen output
5. ⏳ **Run tests** - verify byte-for-byte match
6. ⏳ **Fix discrepancies** - iterate until all pass

---

## Key Files to Read

1. **This file** - Get started
2. `tablegen/README.md` - Understand test coverage
3. `tablegen/COMPLETE-FEATURE-LIST.md` - All 17 fields explained
4. `VALIDATION-PLAN.md` - Detailed validation steps
5. `../../../docs/codegen-design.md` - Architecture

---

## Success Criteria

**You've succeeded when:**
- ✅ `./generate-all-references.sh` completes without errors
- ✅ 30-40 `.expected` files in `reference/` directory
- ✅ Each file contains valid C++ code
- ✅ Test files cover all 17 TableGen features

**Then CREST implementation can begin!**

---

## Getting Help

**Questions?**
- Check `README.md` for detailed docs
- Check `tablegen/COMPLETE-FEATURE-LIST.md` for feature explanations
- Open GitHub issue

**Found a bug?**
- Check if .td file is valid: `$TBLGEN -gen-dialect-decls file.td`
- Check MLIR source is accessible
- Report with full error message
