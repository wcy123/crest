// (:optional %_) — the optional operand is matched but its value is irrelevant.
// Pattern fires for both the absent form (2 operands) and the present form
// (3 operands, regardless of the middle value).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/wildcard-optional" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @optional_absent
// CHECK:       "test.fused"(%arg0, %arg1) : (i32, i32) -> i32
// CHECK-NOT:   test.op
func.func @optional_absent(%x: i32, %y: i32) -> i32 {
  %out = "test.op"(%x, %y) {operandSegmentSizes = array<i32: 1, 0, 1>}
           : (i32, i32) -> i32
  return %out : i32
}

// -----

// CHECK-LABEL: func.func @optional_present
// CHECK:       "test.fused"(%arg0, %arg2) : (i32, i32) -> i32
// CHECK-NOT:   test.op
func.func @optional_present(%x: i32, %ignored: i32, %y: i32) -> i32 {
  %out = "test.op"(%x, %ignored, %y) {operandSegmentSizes = array<i32: 1, 1, 1>}
           : (i32, i32, i32) -> i32
  return %out : i32
}
