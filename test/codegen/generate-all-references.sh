#!/bin/bash
# Generate TableGen reference outputs for ALL test cases
# This creates the baseline that CREST must match

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MLIR_SRC="${MLIR_SRC:-/home/chunywan/w/llvm-project/mlir}"
TABLEGEN_DIR="${SCRIPT_DIR}/tablegen"
REF_DIR="${SCRIPT_DIR}/reference"

# Find mlir-tblgen
find_tblgen() {
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
  echo "Please build LLVM or set TBLGEN environment variable" >&2
  return 1
}

TBLGEN="${TBLGEN:-$(find_tblgen)}"

echo "=========================================="
echo "TableGen Reference Generation"
echo "=========================================="
echo "mlir-tblgen: ${TBLGEN}"
echo "MLIR source: ${MLIR_SRC}"
echo "TableGen inputs: ${TABLEGEN_DIR}"
echo "Output directory: ${REF_DIR}"
echo ""

mkdir -p "${REF_DIR}"

# Helper to generate reference for one .td file
gen_ref_from_td() {
  local td_file=$1
  local base_name=$(basename "${td_file}" .td)

  echo "Generating ${base_name}..."

  # Extract def names (used for output filenames) and let names (used for -dialect flag)
  local def_names=($(grep "^def.*Dialect : Dialect" "${td_file}" | sed 's/def \(.*\)_Dialect.*/\1/'))
  local let_names=($(grep 'let name = ' "${td_file}" | sed 's/.*let name = "\(.*\)".*/\1/'))
  local count=${#def_names[@]}

  for i in "${!def_names[@]}"; do
    local dialect_name="${def_names[$i]}"
    local dialect_ns="${let_names[$i]}"

    echo "  [GEN] ${dialect_name}Dialect..."

    # Pass -dialect only when file contains multiple dialects
    local dialect_flag=()
    if [ "$count" -gt 1 ]; then
      dialect_flag=(-dialect "${dialect_ns}")
    fi

    # Generate declaration
    if ! "${TBLGEN}" -gen-dialect-decls \
         "${dialect_flag[@]}" \
         -I "${MLIR_SRC}/include" \
         "${td_file}" \
         > "${REF_DIR}/${dialect_name}Dialect.h.inc.expected" 2>&1; then
      echo "  [FAIL] ${dialect_name} declaration generation failed"
      return 1
    fi

    # Generate definition
    if ! "${TBLGEN}" -gen-dialect-defs \
         "${dialect_flag[@]}" \
         -I "${MLIR_SRC}/include" \
         "${td_file}" \
         > "${REF_DIR}/${dialect_name}Dialect.cpp.inc.expected" 2>&1; then
      echo "  [FAIL] ${dialect_name} definition generation failed"
      return 1
    fi

    echo "  [OK] ${dialect_name}Dialect"
  done
}

# Generate references for all .td files
echo "Processing TableGen test files..."
echo "=========================================="

for td_file in "${TABLEGEN_DIR}"/test-*.td; do
  if [ ! -f "${td_file}" ]; then
    continue
  fi

  gen_ref_from_td "${td_file}" || {
    echo "Failed to process ${td_file}"
    exit 1
  }
done

# Also generate from real MLIR dialects for validation
echo ""
echo "Generating from upstream MLIR dialects..."
echo "=========================================="

gen_real_dialect() {
  local name=$1
  local td_path=$2

  if [ ! -f "${td_path}" ]; then
    echo "  [SKIP] ${name}: ${td_path} not found"
    return 0
  fi

  echo "  [GEN] ${name}..."

  "${TBLGEN}" -gen-dialect-decls \
    -I "${MLIR_SRC}/include" \
    "${td_path}" \
    > "${REF_DIR}/${name}Dialect.h.inc.expected" 2>&1 && \
  "${TBLGEN}" -gen-dialect-defs \
    -I "${MLIR_SRC}/include" \
    "${td_path}" \
    > "${REF_DIR}/${name}Dialect.cpp.inc.expected" 2>&1 && \
  echo "  [OK] ${name}" || \
  echo "  [FAIL] ${name}"
}

gen_real_dialect "Arith" "${MLIR_SRC}/include/mlir/Dialect/Arith/IR/ArithOps.td"
gen_real_dialect "Tensor" "${MLIR_SRC}/include/mlir/Dialect/Tensor/IR/TensorOps.td"
gen_real_dialect "Math" "${MLIR_SRC}/include/mlir/Dialect/Math/IR/MathOps.td"

echo ""
echo "=========================================="
echo "Reference generation complete!"
echo "=========================================="
echo ""
echo "Generated files in: ${REF_DIR}/"
ls -lh "${REF_DIR}" | tail -n +2 | wc -l | xargs echo "Total files:"
echo ""
echo "Next steps:"
echo "1. Verify references look correct"
echo "2. Implement CREST to generate matching output"
echo "3. Run: ./run-all-tests.sh"
