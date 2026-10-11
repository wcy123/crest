// Negative: pattern expects 3 required operands, op has only 2.
// operation-get-operands returns #f (n-spec=3 != n-ops=2) → :bind-operands FAILED:
//
// CREST_DEBUG_MATCH=1 shows FAILED: with source location and actual op.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/required-too-few" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: required-too-few.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1)
// Pattern did not fire — test.add unchanged
// CHECK: "test.add"(%arg0, %arg1)

func.func @too_few(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
