#!/bin/bash
# Compile-check all generated reference files by wrapping them as real dialect files.
# A clean compile confirms the .expected files are valid C++.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REF_DIR="${SCRIPT_DIR}/../reference"
BUILD_DIR="${SCRIPT_DIR}/build"
MLIR_INCLUDE="${MLIR_INCLUDE:-/usr/local/include}"

mkdir -p "${BUILD_DIR}"

pass=0
fail=0
skip=0

compile_dialect() {
  local name=$1       # e.g. Test01Dialect
  local ns=$2         # e.g. mlir::test01

  local h_inc="${REF_DIR}/${name}.h.inc.expected"
  local cpp_inc="${REF_DIR}/${name}.cpp.inc.expected"

  if [ ! -s "${h_inc}" ] || [ ! -s "${cpp_inc}" ]; then
    echo "  [SKIP] ${name} — reference file missing or empty"
    ((skip++)) || true
    return
  fi

  # Auto-detect extra includes needed by inspecting the .inc files
  local extra_h_includes=""
  local extra_attr_stubs=""

  # ExtensibleDialect base class
  if grep -q 'ExtensibleDialect' "${h_inc}"; then
    extra_h_includes+=$'#include "mlir/IR/ExtensibleDialect.h"\n'
  fi

  # Full Operation definition (needed when discardable attr helpers use op->getAttrOfType etc.)
  if grep -q 'mlir::Operation \*op' "${h_inc}"; then
    extra_h_includes+=$'#include "mlir/IR/Operation.h"\n'
    # Extract unqualified attr type names used in the generated helpers
    # Pattern: lines like "WorkgroupAttr getAttr(" or "WorkgroupAttr val)"
    local attr_types
    attr_types=$(grep -oE '[A-Z][A-Za-z]+Attr' "${h_inc}" | sort -u)
    for attr_type in ${attr_types}; do
      extra_attr_stubs+="using ${attr_type} = ::mlir::Attribute;"$'\n'
    done
  fi

  # Dependent dialect headers (needed when cpp.inc calls loadDialect<X>())
  local extra_cpp_includes=""
  if grep -q 'arith::ArithDialect'   "${cpp_inc}"; then
    extra_cpp_includes+=$'#include "mlir/Dialect/Arith/IR/Arith.h"\n'
  fi
  if grep -q 'affine::AffineDialect' "${cpp_inc}"; then
    extra_cpp_includes+=$'#include "mlir/Dialect/Affine/IR/AffineOps.h"\n'
  fi
  if grep -q 'complex::ComplexDialect' "${cpp_inc}"; then
    extra_cpp_includes+=$'#include "mlir/Dialect/Complex/IR/Complex.h"\n'
  fi
  if grep -q 'tensor::TensorDialect' "${cpp_inc}"; then
    extra_cpp_includes+=$'#include "mlir/Dialect/Tensor/IR/Tensor.h"\n'
  fi

  # Generate wrapper header
  cat > "${BUILD_DIR}/${name}.h" <<EOF
#pragma once
#include "mlir/IR/Dialect.h"
${extra_h_includes}${extra_attr_stubs}
#include "${h_inc}"
EOF

  # Generate wrapper source with stub initialize()
  cat > "${BUILD_DIR}/${name}.cpp" <<EOF
#include "${BUILD_DIR}/${name}.h"
#include "mlir/IR/DialectImplementation.h"
${extra_cpp_includes}
void ${ns}::${name}::initialize() {}

#include "${cpp_inc}"
EOF

  if clang++ -std=c++17 -I "${MLIR_INCLUDE}" \
      -c "${BUILD_DIR}/${name}.cpp" \
      -o "${BUILD_DIR}/${name}.o" 2>"${BUILD_DIR}/${name}.err"; then
    echo "  [OK]   ${name}"
    ((pass++)) || true
  else
    echo "  [FAIL] ${name}"
    cat "${BUILD_DIR}/${name}.err"
    ((fail++)) || true
  fi
}

echo "=========================================="
echo "Compile-check: reference dialect files"
echo "=========================================="
echo "MLIR headers: ${MLIR_INCLUDE}"
echo ""

# ArithDialect and TensorDialect are upstream dialects already shipped in installed MLIR headers.
# Compiling their .expected files alongside those headers causes redefinition — skip them.
compile_dialect Test01Dialect             mlir::test01
compile_dialect Test02SingleDialect       mlir::test02single
compile_dialect Test02MultipleDialect     mlir::test02multiple
compile_dialect Test03DefaultAttrDialect  mlir::test03defaultattr
compile_dialect Test03DefaultTypeDialect  mlir::test03defaulttype
compile_dialect Test03BothDialect         mlir::test03both
compile_dialect Test04ConstMatDialect     mlir::test04constmat
compile_dialect Test04CanonDialect        mlir::test04canon
compile_dialect Test04OpAttrVerifyDialect mlir::test04opattrverify
compile_dialect Test04RegionArgAttrVerifyDialect  mlir::test04regionargverify
compile_dialect Test04RegionResultAttrVerifyDialect mlir::test04regionresultverify
compile_dialect Test04NoDiscardableDialect   mlir::test04nodiscard
compile_dialect Test04SingleDiscardableDialect mlir::test04single
compile_dialect Test04MultipleDiscardableDialect mlir::test04multiple
compile_dialect Test05ExtraDeclDialect    mlir::test05extradecl
compile_dialect Test05NonDefaultDtorDialect mlir::test05nondtor
compile_dialect Test05OpInterfaceFallbackDialect mlir::test05fallback
compile_dialect Test05ExtensibleDialect   mlir::test05extensible
compile_dialect Test06ComprehensiveDialect mlir::test06
# MathDialect skipped — generation failed upstream

echo ""
echo "=========================================="
echo "Results: ${pass} passed, ${fail} failed, ${skip} skipped"
echo "=========================================="
