# Reference Outputs from TableGen

This directory contains **expected outputs** from `mlir-tblgen` for regression testing.

## Generating Reference Outputs

### Prerequisites

- LLVM/MLIR build with `mlir-tblgen` binary
- Access to MLIR source tree

### Extracting Arith Dialect

```bash
# From LLVM build directory
MLIR_SRC=/path/to/llvm-project/mlir
TBLGEN=./bin/mlir-tblgen

# Generate dialect declaration
$TBLGEN \
  -gen-dialect-decls \
  -I ${MLIR_SRC}/include \
  ${MLIR_SRC}/include/mlir/Dialect/Arith/IR/ArithOps.td \
  > ArithDialect.h.inc.expected

# Generate dialect definition
$TBLGEN \
  -gen-dialect-defs \
  -I ${MLIR_SRC}/include \
  ${MLIR_SRC}/include/mlir/Dialect/Arith/IR/ArithOps.td \
  > ArithDialect.cpp.inc.expected
```

### Extracting Other Dialects

```bash
# Tensor dialect
$TBLGEN -gen-dialect-decls \
  -I ${MLIR_SRC}/include \
  ${MLIR_SRC}/include/mlir/Dialect/Tensor/IR/TensorOps.td \
  > TensorDialect.h.inc.expected

# Func dialect
$TBLGEN -gen-dialect-decls \
  -I ${MLIR_SRC}/include \
  ${MLIR_SRC}/include/mlir/Dialect/Func/IR/FuncOps.td \
  > FuncDialect.h.inc.expected
```

## File Naming Convention

```
<DialectName>Dialect.h.inc.expected    # Declaration output
<DialectName>Dialect.cpp.inc.expected  # Definition output
```

## Updating References

When MLIR upstream changes TableGen output format:

```bash
# Re-generate all references
./update-all-references.sh
```

## Version Tracking

**Current MLIR version:** (to be filled when references are generated)  
**TableGen commit:** (to be filled)

When updating, document the MLIR commit hash to ensure reproducibility.
