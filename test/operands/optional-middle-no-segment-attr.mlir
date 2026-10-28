// Negative: optional-in-middle pattern on op without operandSegmentSizes.
//
// The flex path is required whenever any operand is :optional or :variadic.
// If the attribute is absent, operation-get-operands returns #f immediately.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/optional-middle" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: optional-middle.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1, %arg2)
// Pattern did not fire
// CHECK: "test.add"(%arg0, %arg1, %arg2)

func.func @mid_no_seg_attr(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %b, %c) : (i32, i32, i32) -> i32
  return %0 : i32
}
