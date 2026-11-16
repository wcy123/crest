// A callback that raises must not let the error cross the C++ frames above it. The callable catches it, reports a
// diagnostic and answers the failure value of its C result type:
//   - a walk visitor has the C++ prototype WalkResult(Operation*): the error is a diagnostic at the Scheme source of
//     the visitor and the callable answers interrupt, which stops the walk; nothing is raised in Scheme;
//   - a callback whose C++ result is void (the thunk of modifyOpInPlace) has no place for an error and ends the
//     process: test/dsl/callback-diagnostics;
//   - MLIR code that calls the callable (the legality check, a conversion pattern, a type conversion, a rewrite
//     pattern) gets the failure value of the C result type (0): the error is a diagnostic at the Scheme source of the
//     callback and does not come out as a Scheme error.
// Nothing is left behind, so the C++ heap does not grow however many errors there are.
//
// REQUIRES: system-linux
// It measures the heap of its own process, which valgrind's allocator changes:
// UNSUPPORTED: valgrind
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>&1 >/dev/null | %FileCheck %s --check-prefix=DIAG

// CHECK: walk: no error
// CHECK-NEXT: legality: no error
// CHECK-NEXT: pattern: no error
// CHECK-NEXT: conversion: no error
// CHECK-NEXT: callback-errors: ok

// The diagnostics of the first round: the callbacks of the legality check, the conversion pattern, the type
// conversion and the rewrite pattern.
// DIAG-DAG: error: {{.*}}errors.sls:{{[0-9]+}}:{{[0-9]+}}: callback: boom
// DIAG-DAG: error: failed to legalize operation 'test.a' that was explicitly marked illegal

func.func @f() {
  "test.a"() : () -> ()
  "test.rw"() : () -> ()
  return
}
