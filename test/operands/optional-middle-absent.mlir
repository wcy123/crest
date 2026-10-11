// Optional operand in the middle — absent case.
// operandSegmentSizes = [1, 0, 1]: required %a, optional %b absent, required %c.
// Pattern fires and rewrites to test.fused(%a, %c).
// With %b absent: starts = [0, 1, 1], so %c reads operand 1 (the second actual operand).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/optional-middle" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0, %arg1) : (i32, i32) -> i32

func.func @mid_absent(%a: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %c) {operandSegmentSizes = array<i32: 1, 0, 1>}
       : (i32, i32) -> i32
  return %0 : i32
}
