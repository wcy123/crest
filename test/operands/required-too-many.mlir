// Negative: pattern expects 2 required operands, op has 3.
//
// With :bind-operands, operation-get-operands enforces n-spec == n-ops for
// all-required specs.  The pattern does NOT fire — strict arity.
//
// CREST_DEBUG_MATCH=1 shows FAILED: with source location and actual op.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/required-too-many" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: required-too-many.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1, %arg2)
// Pattern did not fire — test.add unchanged
// CHECK: "test.add"(%arg0, %arg1, %arg2)

func.func @too_many(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %b, %c) : (i32, i32, i32) -> i32
  return %0 : i32
}
