// (:variadic %inputs %weights) — two variadic groups bound to separate lists.
// operandSegmentSizes=[2,3]: %inputs gets 2 values, %weights gets 3 values.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/wildcard-variadic-multi" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @multi_variadic
// CHECK:       "test.fused"(%arg0, %arg2) : (i32, i32) -> i32
// CHECK-NOT:   test.multi_variadic

func.func @multi_variadic(%i0: i32, %i1: i32, %w0: i32, %w1: i32, %w2: i32) -> i32 {
  %out = "test.multi_variadic"(%i0, %i1, %w0, %w1, %w2)
           {operandSegmentSizes = array<i32: 2, 3>}
           : (i32, i32, i32, i32, i32) -> i32
  return %out : i32
}
