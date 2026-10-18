#!/bin/bash
# Generate TableGen reference outputs from MLIR source
#
# This script extracts dialect definitions from MLIR source and generates
# reference outputs using mlir-tblgen for comparison with CREST.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MLIR_SRC="${MLIR_SRC:-/home/chunywan/w/llvm-project/mlir}"
REF_DIR="${SCRIPT_DIR}/reference"

# Find mlir-tblgen binary
find_tblgen() {
  # Check common locations
  local candidates=(
    "/home/chunywan/w/llvm-project/build/bin/mlir-tblgen"
    "/usr/local/bin/mlir-tblgen"
    "/usr/bin/mlir-tblgen"
    "$(which mlir-tblgen 2>/dev/null)"
  )

  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  echo "ERROR: mlir-tblgen not found!" >&2
  echo "Please set TBLGEN environment variable or build LLVM" >&2
  return 1
}

TBLGEN="${TBLGEN:-$(find_tblgen)}"

echo "Using mlir-tblgen: ${TBLGEN}"
echo "MLIR source: ${MLIR_SRC}"
echo "Output directory: ${REF_DIR}"
echo ""

# Helper function to generate reference
gen_ref() {
  local name=$1
  local td_file=$2

  if [ ! -f "${td_file}" ]; then
    echo "  [SKIP] ${name}: ${td_file} not found"
    return 1
  fi

  echo "  [GEN] ${name}..."

  # Generate declaration
  if ! "${TBLGEN}" -gen-dialect-decls \
       -I "${MLIR_SRC}/include" \
       "${td_file}" \
       > "${REF_DIR}/${name}Dialect.h.inc.expected" 2>&1; then
    echo "  [FAIL] ${name} declaration generation failed"
    return 1
  fi

  # Generate definition
  if ! "${TBLGEN}" -gen-dialect-defs \
       -I "${MLIR_SRC}/include" \
       "${td_file}" \
       > "${REF_DIR}/${name}Dialect.cpp.inc.expected" 2>&1; then
    echo "  [FAIL] ${name} definition generation failed"
    return 1
  fi

  echo "  [OK] ${name}"
}

mkdir -p "${REF_DIR}"

echo "Generating references from upstream MLIR dialects..."
echo "==============================================="

# Real MLIR dialects
gen_ref "Arith" "${MLIR_SRC}/include/mlir/Dialect/Arith/IR/ArithBase.td"
gen_ref "Tensor" "${MLIR_SRC}/include/mlir/Dialect/Tensor/IR/TensorBase.td"
gen_ref "Math" "${MLIR_SRC}/include/mlir/Dialect/Math/IR/MathBase.td"
gen_ref "Complex" "${MLIR_SRC}/include/mlir/Dialect/Complex/IR/ComplexBase.td"
gen_ref "Func" "${MLIR_SRC}/include/mlir/Dialect/Func/IR/FuncBase.td"

echo ""
echo "==============================================="
echo "Done! References generated in ${REF_DIR}/"
echo ""
echo "Next steps:"
echo "1. Run CREST to generate outputs:"
echo "   cd ${SCRIPT_DIR}"
echo "   ./run-all-tests.sh"
echo ""
echo "2. Compare outputs and fix discrepancies"
