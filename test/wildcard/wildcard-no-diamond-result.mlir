// Two ops each produce a %_ result (result 0) from DIFFERENT ops.
// The two wildcards are independent — no diamond check between them.
// Pattern must fire even though the two discarded results are distinct values.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/wildcard-no-diamond-result" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @no_diamond_result
// CHECK:       %[[X:.*]] = "test.x"
// CHECK:       %[[Y:.*]] = "test.y"
// CHECK:       "test.fused"(%[[X]], %[[Y]]) : (i32, i32) -> i32
// CHECK-NOT:   test.combine

func.func @no_diamond_result() -> i32 {
  %x          = "test.x"()              : () -> i32
  %y          = "test.y"()              : () -> i32
  %ra0, %a    = "test.split_a"(%x)     : (i32) -> (i32, i32)  // %ra0 discarded
  %rb0, %b    = "test.split_b"(%y)     : (i32) -> (i32, i32)  // %rb0 discarded (different value)
  %out        = "test.combine"(%a, %b) : (i32, i32) -> i32
  return %out : i32
}
