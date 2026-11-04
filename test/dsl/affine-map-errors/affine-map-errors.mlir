// A mistake in an affine-map form is reported when the library compiles, at the name, with
// its line and column; a wrong operand is reported when the form runs.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/dup-name" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=DUP
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/operator-name" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=OPERATOR
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unbound-name" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNBOUND
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/runtime-errors.sls \
// RUN:   | %FileCheck %s --check-prefix=RUNTIME

// DUP:      Failed to import Scheme library: passes/dup-name: Exception in affine-map: a dimension or symbol name is repeated d0 in (affine-map (d0 d0) () d0) at line {{[0-9]+}}, char {{[0-9]+}}
// OPERATOR: Failed to import Scheme library: passes/operator-name: Exception in affine-map: a name cannot be an operator name mod in (affine-map (d0 mod) () d0) at line {{[0-9]+}}, char {{[0-9]+}}
// UNBOUND:  Failed to import Scheme library: passes/unbound-name: Exception: attempt to reference unbound identifier not-bound at line {{[0-9]+}}, char {{[0-9]+}}

// RUNTIME:      operand must be an integer or an AffineExpr
// RUNTIME-NEXT: incorrect number of arguments
// RUNTIME-NEXT: operands must be integers or AffineExprs
// RUNTIME-NEXT: (3 1)

module {}
