# Complete TableGen Dialect Features

**Source:** Analyzed from `/home/chunywan/w/llvm-project/mlir/include/mlir/IR/DialectBase.td`  
**Date:** 2026-10-17

---

## ALL Dialect Fields in TableGen

From `DialectBase.td`, class `Dialect` has these fields:

### Basic Properties

| Field | Type | Default | Description | Example |
|-------|------|---------|-------------|---------|
| `name` | string | **required** | Dialect identifier | `"arith"` |
| `summary` | string | `?` | Short one-line description | `"Arithmetic ops"` |
| `description` | string | `?` | Multi-line documentation | `[{ ... }]` |
| `cppNamespace` | string | `name` | C++ namespace | `"::mlir::arith"` |

### Dependencies

| Field | Type | Default | Description | Example |
|-------|------|---------|-------------|---------|
| `dependentDialects` | list\<string\> | `[]` | Dialects to load on construction | `["arith::ArithDialect"]` |

### Discardable Attributes (IMPORTANT - I missed this!)

| Field | Type | Default | Description | Example |
|-------|------|---------|-------------|---------|
| `discardableAttrs` | dag | `(ins)` | Type-safe discardable attribute helpers | `(ins "WorkgroupAttributionAttr":$workgroup)` |

### Printer/Parser Hooks

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `useDefaultAttributePrinterParser` | bit | `0` | Generate default attr parser/printer |
| `useDefaultTypePrinterParser` | bit | `0` | Generate default type parser/printer |

### Dialect Capabilities

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `hasConstantMaterializer` | bit | `0` | Override `materializeConstant` hook |
| `hasCanonicalizer` | bit | `0` | Override `getCanonicalizationPatterns` hook |
| `hasOperationAttrVerify` | bit | `0` | Override `verifyOperationAttribute` hook |
| `hasRegionArgAttrVerify` | bit | `0` | Override `verifyRegionArgAttribute` hook |
| `hasRegionResultAttrVerify` | bit | `0` | Override `verifyRegionResultAttribute` hook |
| `hasOperationInterfaceFallback` | bit | `0` | Override `getRegisteredInterfaceForOp` hook |

### Lifecycle

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `hasNonDefaultDestructor` | bit | `0` | User provides custom destructor |

### Extensibility

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `isExtensible` | bit | `0` | Can add ops/types at runtime |

### Extra Code

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `extraClassDeclaration` | code | `""` | C++ code to insert in class body |

---

## Total: 17 Fields

### Required Fields (2)
- `name`
- (technically `summary` and `description` are required but have defaults)

### Optional Fields (15)
- All others

---

## Test Cases Needed

### Test 01: Minimal (2 fields)
```tablegen
def Test01_Dialect : Dialect {
  let name = "test01";
  let cppNamespace = "::mlir::test01";
}
```

### Test 02: With Summary and Description
```tablegen
def Test02_Dialect : Dialect {
  let name = "test02";
  let summary = "Short summary";
  let description = [{ Multi-line description }];
  let cppNamespace = "::mlir::test02";
}
```

### Test 03: Dependencies
- No dependencies (empty list)
- Single dependency
- Multiple dependencies

### Test 04: Discardable Attributes (I MISSED THIS!)
```tablegen
def Test04_Dialect : Dialect {
  let name = "test04";
  let cppNamespace = "::mlir::test04";
  let discardableAttrs = (ins
    "WorkgroupAttr":$workgroup,
    "TargetAttr":$target
  );
}
```

### Test 05: Printers
- Default attr printer only
- Default type printer only
- Both
- Neither (custom)

### Test 06: Capabilities (Individual)
- hasConstantMaterializer = 1
- hasCanonicalizer = 1
- hasOperationAttrVerify = 1
- hasRegionArgAttrVerify = 1
- hasRegionResultAttrVerify = 1
- hasOperationInterfaceFallback = 1

### Test 07: Lifecycle
- hasNonDefaultDestructor = 1

### Test 08: Extensibility
- isExtensible = 1

### Test 09: Extra Class Declaration
```tablegen
let extraClassDeclaration = [{
  static bool customMethod();
}];
```

### Test 10: Comprehensive - ALL Fields
```tablegen
def Test10_Dialect : Dialect {
  let name = "test10";
  let summary = "Comprehensive test";
  let description = [{ All features enabled }];
  let cppNamespace = "::mlir::test10";
  let dependentDialects = ["arith::ArithDialect"];
  let discardableAttrs = (ins "CustomAttr":$custom);
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
  let hasConstantMaterializer = 1;
  let hasCanonicalizer = 1;
  let hasOperationAttrVerify = 1;
  let hasRegionArgAttrVerify = 1;
  let hasRegionResultAttrVerify = 1;
  let hasOperationInterfaceFallback = 1;
  let hasNonDefaultDestructor = 1;
  let isExtensible = 1;
  let extraClassDeclaration = [{
    static bool isCustomType(Type type);
  }];
}
```

---

## Fields I Initially Missed

### 1. `summary` (separate from description)
- Short one-line summary
- Different from multi-line `description`
- Both can be present

### 2. `discardableAttrs`
- DAG type: `(ins "AttrType":$name, ...)`
- Generates type-safe helpers for discardable attributes
- Example in LLVM dialect: `workgroup_attribution`
- **CRITICAL for complete coverage**

### 3. `isExtensible`
- Newer feature for dynamic dialects
- Allows runtime registration of ops/types

---

## Updated Test Matrix

| Test | Features Covered | Fields Count |
|------|------------------|--------------|
| test-01 | Minimal | 2 (name, cppNamespace) |
| test-02 | Summary + Description | 4 |
| test-03 | Dependencies | 3 variations |
| test-04 | **Discardable Attrs** | 3 (NEW!) |
| test-05 | Printers | 4 variations |
| test-06 | Capabilities | 6 variations |
| test-07 | Lifecycle | 1 |
| test-08 | Extensibility | 1 |
| test-09 | Extra Code | 1 |
| test-10 | **ALL 17 fields** | 17 |

**Total unique .td files needed:** ~15-20 (covering all combinations)

---

## Real-World Examples

### Arith Dialect
```tablegen
def Arith_Dialect : Dialect {
  let name = "arith";
  let cppNamespace = "::mlir::arith";
  let description = [{ ... }];
  let hasConstantMaterializer = 1;
  let useDefaultAttributePrinterParser = 1;
}
```
**Uses:** 5 fields

### LLVM Dialect
```tablegen
def LLVM_Dialect : Dialect {
  let name = "llvm";
  let cppNamespace = "::mlir::LLVM";
  let hasConstantMaterializer = 1;
  let useDefaultAttributePrinterParser = 1;
  let hasRegionArgAttrVerify = 1;
  let hasRegionResultAttrVerify = 1;
  let hasOperationAttrVerify = 1;
  let discardableAttrs = (ins "WorkgroupAttributionAttr":$workgroup_attribution);
  let extraClassDeclaration = [{ ... }];
}
```
**Uses:** 9 fields (including discardableAttrs!)

### Transform Dialect
```tablegen
def Transform_Dialect : Dialect {
  let summary = "Fine-grain transformation control dialect";
  let name = "transform";
  let cppNamespace = "::mlir::transform";
  let hasOperationAttrVerify = 1;
  let extraClassDeclaration = [{ ... }];
}
```
**Uses:** 5 fields

---

## Action Items

1. ✅ **Add `summary` field to semantic model**
2. ✅ **Add `discardableAttrs` field to semantic model**
3. ✅ **Add `isExtensible` field to semantic model**
4. ⏳ **Create test-04-discardable-attrs.td**
5. ⏳ **Update test-06-comprehensive.td to include ALL 17 fields**
6. ⏳ **Generate references with mlir-tblgen**
7. ⏳ **Implement CREST generation for ALL fields**

---

## Code Generation Implications

### For `discardableAttrs`
TableGen generates helper methods:
```cpp
// For: let discardableAttrs = (ins "WorkgroupAttr":$workgroup);
class LLVMDialect : public ::mlir::Dialect {
  // Generated methods for type-safe discardable attribute access
  WorkgroupAttributionAttr getWorkgroupAttributionAttr(Operation *op) const;
  void setWorkgroupAttributionAttr(Operation *op, WorkgroupAttributionAttr attr);
};
```

CREST needs to:
1. Parse dag type in semantic model
2. Extract attribute type/name pairs
3. Generate getter/setter methods

---

## Validation Strategy

1. **Generate .td files** for each feature (test-01 through test-10)
2. **Run mlir-tblgen** to get reference .h.inc and .cpp.inc
3. **Inspect output** to understand what code is generated for each field
4. **Implement CREST** to generate identical output
5. **Byte-for-byte comparison** to prove correctness
