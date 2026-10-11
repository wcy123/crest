// Positive: optional operand present — op carries operandSegmentSizes.
// Pattern matches with :where (not (unbound-value? %b)).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/optional-present" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0, %arg1) : (i32, i32) -> i32

func.func @opt_present(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) {operandSegmentSizes = array<i32: 1, 1>}
       : (i32, i32) -> i32
  return %0 : i32
}
