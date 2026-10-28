// %_ in operand position — the third operand is irrelevant and discarded.
// Pattern fires regardless of what the third operand is.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/wildcard-operand" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @operand_wildcard
// CHECK:       %[[A:.*]] = "test.val_a"
// CHECK:       %[[B:.*]] = "test.val_b"
// CHECK:       "test.fused"(%[[A]], %[[B]]) : (i32, i32) -> i32
// CHECK-NOT:   test.add

func.func @operand_wildcard(%unused: i32) -> i32 {
  %a   = "test.val_a"() : () -> i32
  %b   = "test.val_b"() : () -> i32
  %out = "test.add"(%a, %b, %unused) : (i32, i32, i32) -> i32
  return %out : i32
}
