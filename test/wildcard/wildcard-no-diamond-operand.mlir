// Two ops each have a %_ operand coming from DIFFERENT SSA values.
// The two wildcards are independent — no diamond check between them.
// Pattern must fire even though the two "ignored" operands differ.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/wildcard-no-diamond-operand" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @no_diamond_operand
// CHECK:       %[[X:.*]] = "test.x"
// CHECK:       %[[Y:.*]] = "test.y"
// CHECK:       "test.fused"(%[[X]], %[[Y]]) : (i32, i32) -> i32
// CHECK-NOT:   test.combine

func.func @no_diamond_operand() -> i32 {
  %x        = "test.x"()            : () -> i32
  %y        = "test.y"()            : () -> i32
  %ignore_a = "test.noise_a"()      : () -> i32   // different from %ignore_b
  %ignore_b = "test.noise_b"()      : () -> i32
  %left     = "test.add"(%x, %ignore_a)     : (i32, i32) -> i32
  %right    = "test.sub"(%y, %ignore_b)     : (i32, i32) -> i32
  %out      = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
