// Positive baseline: diamond with optional operands — same %shared value.
// Pattern should match and rewrite to test.fused(%shared).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/flex-diamond" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%[[SHARED:.*]]) : (i32) -> i32

func.func @same_shared(%a: i32, %b: i32, %c: i32, %d: i32) -> i32 {
  %shared = "test.mul"(%a, %b) : (i32, i32) -> i32
  %left   = "test.add"(%shared) {operandSegmentSizes = array<i32: 1, 0>} : (i32) -> i32
  %right  = "test.sub"(%shared) {operandSegmentSizes = array<i32: 1, 0>} : (i32) -> i32
  %out    = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
