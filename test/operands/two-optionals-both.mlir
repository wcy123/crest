// Two optional operands — both present.
// operandSegmentSizes = [1, 1]: both optionals provided.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/two-optionals-both-present" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0, %arg1) : (i32, i32) -> i32

func.func @both_present(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) {operandSegmentSizes = array<i32: 1, 1>}
       : (i32, i32) -> i32
  return %0 : i32
}
