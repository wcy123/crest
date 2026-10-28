// Negative: optional pattern on op without operandSegmentSizes attribute.
//
// BUG (before fix): throws "op must have operandSegmentSizes" (exception).
// Expected (after fix): :bind-operands FAILED: — clean structural failure.
//
// CREST_DEBUG_MATCH=1 shows FAILED: with source location and actual op.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/optional-present" %s 2>&1 \
// RUN:   | %FileCheck %s

// After fix: clean FAILED: not exception
// CHECK: optional-present.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1)
// Pattern did not fire
// CHECK: "test.add"(%arg0, %arg1)

func.func @no_seg_attr(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
