#!/bin/bash
# Regression test runner for CREST code generation
# Compares CREST output with TableGen reference byte-for-byte

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREST_ROOT="${SCRIPT_DIR}/../.."
SCHEME="${CREST_ROOT}/venv/bin/scheme"
ACTUAL_DIR="${SCRIPT_DIR}/actual"
REFERENCE_DIR="${SCRIPT_DIR}/reference"
DIFFS_DIR="${SCRIPT_DIR}/diffs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create output directories
mkdir -p "${ACTUAL_DIR}" "${DIFFS_DIR}"

# Test results
TOTAL=0
PASSED=0
FAILED=0

# Test registry
# Format: test_name|scheme_file|generator_function|reference_file
TESTS=(
  # Real MLIR dialects (for validation)
  "arith-dialect-decls|dialects/arith-dialect.sls|decl|ArithDialect.h.inc.expected"
  "arith-dialect-defs|dialects/arith-dialect.sls|def|ArithDialect.cpp.inc.expected"

  # Feature tests
  "test-01-basic-decls|dialects/test-01-basic.sls|decl|Test01Dialect.h.inc.expected"
  "test-01-basic-defs|dialects/test-01-basic.sls|def|Test01Dialect.cpp.inc.expected"

  "test-02-single-dep-decls|dialects/test-02-single-dep.sls|decl|Test02Dialect.h.inc.expected"
  "test-02-single-dep-defs|dialects/test-02-single-dep.sls|def|Test02Dialect.cpp.inc.expected"

  "test-03-multiple-deps-decls|dialects/test-03-multiple-deps.sls|decl|Test03Dialect.h.inc.expected"
  "test-03-multiple-deps-defs|dialects/test-03-multiple-deps.sls|def|Test03Dialect.cpp.inc.expected"

  "test-12-all-features-decls|dialects/test-12-all-features.sls|decl|Test12Dialect.h.inc.expected"
  "test-12-all-features-defs|dialects/test-12-all-features.sls|def|Test12Dialect.cpp.inc.expected"
)

# Function to run a single test
run_test() {
  local test_name="$1"
  local scheme_file="$2"
  local generator="$3"
  local reference_file="$4"

  TOTAL=$((TOTAL + 1))

  echo -n "Testing ${test_name}... "

  local actual_file="${ACTUAL_DIR}/${test_name}.actual"
  local diff_file="${DIFFS_DIR}/${test_name}.diff"

  # Generate output with CREST
  if ! CHEZSCHEMELIBDIRS="${CREST_ROOT}/scheme" \
       "${SCHEME}" --program "${SCRIPT_DIR}/${scheme_file}" \
       "${generator}" \
       > "${actual_file}" 2>&1; then
    echo -e "${RED}[FAIL]${NC} - CREST generation failed"
    cat "${actual_file}"
    FAILED=$((FAILED + 1))
    return 1
  fi

  # Compare with reference
  if diff -u "${REFERENCE_DIR}/${reference_file}" "${actual_file}" > "${diff_file}" 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED=$((PASSED + 1))
    rm -f "${diff_file}"
    return 0
  else
    echo -e "${RED}[FAIL]${NC} - Output differs from TableGen"
    echo "  Diff saved to: ${diff_file}"
    echo "  First 20 lines of diff:"
    head -n 20 "${diff_file}" | sed 's/^/    /'
    FAILED=$((FAILED + 1))
    return 1
  fi
}

# Main test execution
main() {
  echo "========================================"
  echo "CREST Code Generation Regression Tests"
  echo "========================================"
  echo ""

  # Check if specific test requested
  if [ $# -gt 0 ]; then
    local requested_test="$1"
    local found=0

    for test_entry in "${TESTS[@]}"; do
      IFS='|' read -r test_name scheme_file generator reference_file <<< "$test_entry"
      if [ "$test_name" = "$requested_test" ]; then
        found=1
        run_test "$test_name" "$scheme_file" "$generator" "$reference_file"
        break
      fi
    done

    if [ $found -eq 0 ]; then
      echo -e "${RED}Error: Test '$requested_test' not found${NC}"
      echo ""
      echo "Available tests:"
      for test_entry in "${TESTS[@]}"; do
        IFS='|' read -r test_name _ _ _ <<< "$test_entry"
        echo "  - $test_name"
      done
      exit 1
    fi
  else
    # Run all tests
    for test_entry in "${TESTS[@]}"; do
      IFS='|' read -r test_name scheme_file generator reference_file <<< "$test_entry"
      run_test "$test_name" "$scheme_file" "$generator" "$reference_file" || true
    done
  fi

  # Print summary
  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo "Total:  ${TOTAL}"
  echo -e "Passed: ${GREEN}${PASSED}${NC}"
  if [ $FAILED -gt 0 ]; then
    echo -e "Failed: ${RED}${FAILED}${NC}"
  else
    echo -e "Failed: ${FAILED}"
  fi
  echo ""

  if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed. Check diffs/ for details.${NC}"
    exit 1
  fi
}

# Show usage
usage() {
  echo "Usage: $0 [test-name]"
  echo ""
  echo "Run all regression tests, or a specific test if name provided."
  echo ""
  echo "Examples:"
  echo "  $0                    # Run all tests"
  echo "  $0 arith-dialect-decls  # Run specific test"
  echo ""
  echo "Available tests:"
  for test_entry in "${TESTS[@]}"; do
    IFS='|' read -r test_name _ _ _ <<< "$test_entry"
    echo "  - $test_name"
  done
}

# Handle arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

main "$@"
