# TableGen Baseline Test Files

**Purpose:** Define the ground truth - what CREST must match  
**Source:** TableGen (.td files) → `mlir-tblgen` → .h.inc/.cpp.inc (baseline)

---

## Test Strategy

```
Step 1: Write .td files                (THIS DIRECTORY)
        ↓
Step 2: mlir-tblgen -gen-dialect-decls (generate-all-references.sh)
        ↓
Step 3: Reference .h.inc/.cpp.inc      (../reference/)
        ↓
Step 4: Implement CREST to match       (../../../scheme/mlir/codegen/)
        ↓
Step 5: Byte-for-byte comparison       (../run-all-tests.sh)
```

---

## Complete Feature Coverage

See **[COMPLETE-FEATURE-LIST.md](COMPLETE-FEATURE-LIST.md)** for exhaustive analysis.

### All 17 TableGen Dialect Fields

| # | Field | Test File | Status |
|---|-------|-----------|--------|
| 1 | `name` | test-01 | ✅ |
| 2 | `summary` | test-02 | ✅ |
| 3 | `description` | test-01 | ✅ |
| 4 | `cppNamespace` | test-01 | ✅ |
| 5 | `dependentDialects` | test-02 | ✅ |
| 6 | **`discardableAttrs`** | test-04 | ✅ |
| 7 | `useDefaultAttributePrinterParser` | test-03 | ✅ |
| 8 | `useDefaultTypePrinterParser` | test-03 | ✅ |
| 9 | `hasConstantMaterializer` | test-04 (capabilities) | ✅ |
| 10 | `hasCanonicalizer` | test-04 (capabilities) | ✅ |
| 11 | `hasOperationAttrVerify` | test-04 (capabilities) | ✅ |
| 12 | `hasRegionArgAttrVerify` | test-04 (capabilities) | ✅ |
| 13 | `hasRegionResultAttrVerify` | test-04 (capabilities) | ✅ |
| 14 | `hasOperationInterfaceFallback` | test-05 | ✅ |
| 15 | `hasNonDefaultDestructor` | test-05 | ✅ |
| 16 | `isExtensible` | test-05 | ✅ |
| 17 | `extraClassDeclaration` | test-05 | ✅ |

---

## Test Files

### test-01-minimal.td
**Features:** Minimal dialect (name, cppNamespace, description)  
**Dialects:** 1  
**Purpose:** Baseline - fewest possible fields

### test-02-dependencies.td
**Features:** dependentDialects (single and multiple)  
**Dialects:** 2  
**Purpose:** Dependency loading

### test-03-printers.td
**Features:** useDefaultAttributePrinterParser, useDefaultTypePrinterParser  
**Dialects:** 3  
**Purpose:** Printer/parser generation (attr only, type only, both)

### test-04-discardable-attrs.td (NEW!)
**Features:** discardableAttrs (DAG type)  
**Dialects:** 3  
**Purpose:** Type-safe discardable attribute helpers  
**Critical:** This field was initially missed!

### test-04-capabilities.td
**Features:** has* flags (materializer, canonicalizer, verifiers)  
**Dialects:** 5  
**Purpose:** Individual capability hooks

### test-05-extra-features.td
**Features:** extraClassDeclaration, hasNonDefaultDestructor, isExtensible  
**Dialects:** 4  
**Purpose:** Advanced features

### test-06-comprehensive.td
**Features:** ALL 17 fields enabled  
**Dialects:** 1  
**Purpose:** Complete coverage in single dialect

---

## Generating References

### Prerequisite: mlir-tblgen

```bash
# Find mlir-tblgen
find /home/chunywan/w/llvm-project -name mlir-tblgen -type f

# Or build LLVM (on stronger machine)
cd /home/chunywan/w/llvm-project
mkdir -p build && cd build
cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir
ninja mlir-tblgen
```

### Run Generator

```bash
cd /home/chunywan/w/crest-repo/test/codegen

# Set TBLGEN if not in PATH
export TBLGEN=/path/to/mlir-tblgen

# Generate all references
./generate-all-references.sh
```

**Output:**
```
reference/
├── Test01_Dialect.h.inc.expected
├── Test01_Dialect.cpp.inc.expected
├── Test02Single_Dialect.h.inc.expected
├── Test02Multiple_Dialect.h.inc.expected
├── Test04NoDiscardable_Dialect.h.inc.expected
├── Test04SingleDiscardable_Dialect.h.inc.expected
├── Test04MultipleDiscardable_Dialect.h.inc.expected
├── Test06Comprehensive_Dialect.h.inc.expected
└── ... (30+ files total)
```

---

## What mlir-tblgen Generates

For each dialect defined in .td files:

### Declaration (.h.inc)
```cpp
class MyDialect : public ::mlir::Dialect {
public:
  explicit MyDialect(::mlir::MLIRContext *context);
  
  static constexpr ::llvm::StringLiteral getDialectNamespace() {
    return ::llvm::StringLiteral("myname");
  }
  
  // If useDefaultAttributePrinterParser = 1
  ::mlir::Attribute parseAttribute(...) const override;
  void printAttribute(...) const override;
  
  // If useDefaultTypePrinterParser = 1
  ::mlir::Type parseType(...) const override;
  void printType(...) const override;
  
  // If hasConstantMaterializer = 1
  ::mlir::Operation *materializeConstant(...) override;
  
  // If has*Verify = 1
  ::mlir::LogicalResult verifyOperationAttribute(...) override;
  ::mlir::LogicalResult verifyRegionArgAttribute(...) override;
  
  // If discardableAttrs = (ins "AttrType":$name)
  AttrType getNameAttr(Operation *op) const;
  void setNameAttr(Operation *op, AttrType attr);
  
  // If extraClassDeclaration = [{ code }]
  // ... user code inserted here ...
};
```

### Definition (.cpp.inc)
```cpp
MyDialect::MyDialect(::mlir::MLIRContext *context)
    : ::mlir::Dialect(getDialectNamespace(), context,
                      ::mlir::TypeID::get<MyDialect>()) {
  // Load dependent dialects
  getContext()->getOrLoadDialect<DependentDialect>();
  
  initialize();
}

void MyDialect::initialize() {
  // Register operations, types, attributes
}
```

---

## Verifying Coverage

### Check All Fields Are Tested

```bash
# List all .td files
ls test-*.td

# For each field in COMPLETE-FEATURE-LIST.md,
# verify it appears in at least one .td file
grep -r "let hasConstantMaterializer" test-*.td
grep -r "let discardableAttrs" test-*.td
# etc.
```

### Count Dialects

```bash
# Should be 15-20 dialects total across all .td files
grep "^def.*Dialect : Dialect" test-*.td | wc -l
```

---

## Next Steps

1. ✅ **Created:** All .td test files
2. ⏳ **TODO:** Run `mlir-tblgen` to generate references
3. ⏳ **TODO:** Inspect generated code to understand output format
4. ⏳ **TODO:** Implement CREST to generate identical output
5. ⏳ **TODO:** Verify byte-for-byte match

---

## Critical Findings

### Fields Initially Missed

1. **`summary`** - Separate from description
2. **`discardableAttrs`** - DAG type, generates helpers (IMPORTANT!)
3. **`isExtensible`** - Runtime op/type registration

### Complex Field: discardableAttrs

**Type:** `dag` (directed acyclic graph)  
**Syntax:** `(ins "AttrType":$name, ...)`  
**Generates:** Type-safe getter/setter methods

**Example:**
```tablegen
let discardableAttrs = (ins
  "WorkgroupAttr":$workgroup,
  "TargetAttr":$target
);
```

**Generated methods:**
```cpp
WorkgroupAttr getWorkgroupAttr(Operation *op) const;
void setWorkgroupAttr(Operation *op, WorkgroupAttr attr);
TargetAttr getTargetAttr(Operation *op) const;
void setTargetAttr(Operation *op, TargetAttr attr);
```

**CREST must:**
- Parse DAG type in semantic model
- Extract attribute type/name pairs
- Generate getter/setter for each pair

---

## Files in This Directory

```
tablegen/
├── README.md                            # This file
├── COMPLETE-FEATURE-LIST.md             # Exhaustive analysis
├── test-01-minimal.td                   # Baseline
├── test-02-dependencies.td              # dependentDialects
├── test-03-printers.td                  # Printer/parser flags
├── test-04-discardable-attrs.td         # discardableAttrs (DAG)
├── test-04-capabilities.td              # has* flags
├── test-05-extra-features.td            # Advanced features
└── test-06-comprehensive.td             # ALL 17 fields
```

**Total:** 7 .td files, ~20 dialects, 17 features covered

---

## Validation Criteria

**CREST passes validation when:**
1. ✅ All 17 fields supported in semantic model
2. ✅ All .td files generate valid references
3. ✅ CREST generates byte-for-byte identical output
4. ✅ No semantic differences in generated C++
5. ✅ Compiles and links with MLIR successfully
