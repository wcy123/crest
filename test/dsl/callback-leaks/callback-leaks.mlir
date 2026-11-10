// The C functions that C++ makes for the callbacks of one run (conversion patterns, legality checks, type
// conversions, materializations, rewrite patterns, modifyOpInPlace) are released with whatever calls
// them. Running each API 100 times, each in a context of its own, leaves no code objects behind. This
// covers the ways to use them that the other leak tests do not: both materializations, a partial
// conversion, registrations that are never applied, a greedy rewrite, modifyOpInPlace, the body of a
// pass.
//
// RUN: rm -rf %t/callback-leaks-scheme && mkdir -p %t/callback-leaks-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callback-leaks-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: conversion-full: ok
// CHECK-NEXT: conversion-partial: ok
// CHECK-NEXT: unused-sets: ok
// CHECK-NEXT: rewrite-greedy: ok
// CHECK-NEXT: modify-in-place: ok
// CHECK-NEXT: pass-pipeline: ok

func.func @f() {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  "test.rw"() : () -> ()
  "test.mark"() : () -> ()
  return
}
