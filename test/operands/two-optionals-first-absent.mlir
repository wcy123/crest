// Two optional operands — first absent, second present.
// operandSegmentSizes = [0, 1]: first optional absent, second provided.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/two-optionals-first-absent" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0) : (i32) -> i32

func.func @first_absent(%b: i32) -> i32 {
  %0 = "test.add"(%b) {operandSegmentSizes = array<i32: 0, 1>}
       : (i32) -> i32
  return %0 : i32
}
