// A callback that raises must not let the error cross the C++ frames above it. The callable catches it and
// answers (who . why); the C++ code that called it reads the answer:
//   - a binding that calls the callable itself (walk) stops and answers the error, and Scheme raises it there,
//     with the text of the original;
//   - MLIR code that calls the callable (the legality check, a conversion pattern, a type conversion, a rewrite
//     pattern) gets a diagnostic and a failure: the error does not come out as a Scheme error.
// Nothing is left behind, so the C++ heap does not grow however many errors there are.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>&1 >/dev/null | %FileCheck %s --check-prefix=DIAG

// CHECK: walk: Exception in callback: boom
// CHECK-NEXT: legality: no error
// CHECK-NEXT: pattern: no error
// CHECK-NEXT: conversion: no error
// CHECK-NEXT: modify: no error
// CHECK-NEXT: callback-errors: ok

// The diagnostics of the first round: the callbacks of the legality check, the conversion pattern, the type
// conversion and the rewrite pattern.
// DIAG-DAG: callback-errors.mlir":{{[0-9]+}}:3): error: callback: boom
// DIAG-DAG: error: failed to legalize operation 'test.a' that was explicitly marked illegal

func.func @f() {
  "test.a"() : () -> ()
  "test.rw"() : () -> ()
  return
}
