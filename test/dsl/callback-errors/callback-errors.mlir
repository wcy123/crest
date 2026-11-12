// A callback that raises must not let the error cross the C++ frames above it (plans/04-errors-are-values.md):
// the callable catches it, C++ goes on with the zero value, and the Scheme binding that ran the callback
// raises the error when it returns, with the text of the original. Nothing is left behind, so the C++ heap
// does not grow however many errors there are.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s

// CHECK: walk: Exception in callback: boom
// CHECK-NEXT: legality: Exception in callback: boom
// CHECK-NEXT: pattern: Exception in callback: boom
// CHECK-NEXT: conversion: Exception in callback: boom
// CHECK-NEXT: modify: Exception in callback: boom
// CHECK-NEXT: callback-errors: ok

func.func @f() {
  "test.a"() : () -> ()
  "test.rw"() : () -> ()
  return
}
