// Always-on exception logging — no CREST_DEBUG_MATCH needed.
//
// A :where clause that throws an unexpected exception (division by zero)
// triggers the per-check guard, which logs it regardless of CREST_DEBUG_MATCH.
// This tests the always-on exception path in make-check-form.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/debug-match-exception" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-exception.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%always-throws\]}} :check-where exception: Exception in /:
// CHECK: "test.add"(%arg0, %arg1) : (i32, i32) -> i32

func.func @always_throws(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
