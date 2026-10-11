// Negative: variadic pattern on op without operandSegmentSizes attribute.
//
// The flex path (triggered by :variadic in the spec) tries to read
// operandSegmentSizes.  If the attribute is absent, operation-get-operands
// returns #f → :bind-operands FAILED: clean structural failure.
//
// CREST_DEBUG_MATCH=1 shows FAILED: with source location and actual op.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/variadic-present" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: variadic-present.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1)
// Pattern did not fire — op is unchanged
// CHECK: "test.add"(%arg0, %arg1)

func.func @var_no_seg_attr(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
