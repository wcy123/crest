// Negative: flex pattern has 2 optional slots but op has 3-segment operandSegmentSizes.
// operation-get-operands returns #f when n != n-spec, giving a clean FAILED: message.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/two-optionals-both-present" %s 2>&1 \
// RUN:   | %FileCheck %s

// Structural mismatch: spec has 2 segments, op has 3.
// CHECK: two-optionals-both-present.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1, %arg2)
// Pattern did not fire — op unchanged
// CHECK: "test.add"(%arg0, %arg1, %arg2)

func.func @three_seg(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %b, %c) {operandSegmentSizes = array<i32: 1, 1, 1>}
       : (i32, i32, i32) -> i32
  return %0 : i32
}
