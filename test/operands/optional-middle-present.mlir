// Optional operand in the middle — present case.
// operandSegmentSizes = [1, 1, 1]: required %a, optional %b present, required %c.
// Pattern fires and rewrites to test.fused(%a, %c).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/optional-middle" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0, %arg2) : (i32, i32) -> i32

func.func @mid_present(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %b, %c) {operandSegmentSizes = array<i32: 1, 1, 1>}
       : (i32, i32, i32) -> i32
  return %0 : i32
}
