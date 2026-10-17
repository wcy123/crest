#!/bin/bash
# Run the HIP dialect code generation example

set -e

CREST_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEME="${CREST_ROOT}/venv/bin/scheme"

echo "Running HIP dialect codegen example..."
echo "========================================"
echo ""

# Run the example
CHEZSCHEMELIBDIRS="${CREST_ROOT}/scheme" \
  "${SCHEME}" --program hip-dialect.sls

echo ""
echo "========================================"
echo "Example completed successfully!"
echo ""
echo "Next steps:"
echo "1. Review generated C++ code above"
echo "2. Compare with TableGen output from mlir-tblgen"
echo "3. Test compilation in MLIR build system"
