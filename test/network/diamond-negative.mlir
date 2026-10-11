// Diamond topology — NEGATIVE: two separate test.mul ops, not shared.
//
//   %s1 ──► test.add ──► %left ──┐
//                                ├──► test.combine ──► %out
//   %s2 ──► test.sub ──► %right ─┘
//
// %s1 and %s2 are distinct SSA values — the eqv? check inside :bind-operands
// for %shared (already bound to %s1) fails when test.sub's operand 0 is %s2.
// Pattern does NOT fire: test.combine remains in the output.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/network-diamond" %s 2>&1 \
// RUN:   | %FileCheck %s

// :bind-operands failure — %s2 (operand of test.sub) != %s1 (%shared from test.add)
// CHECK: network-diamond.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%diamond\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.sub"
// Pattern did not fire — test.combine still present
// CHECK: "test.combine"

func.func @diamond_no_match(%a: i32, %b: i32, %x: i32, %y: i32) -> i32 {
  %s1   = "test.mul"(%a, %b)  : (i32, i32) -> i32
  %s2   = "test.mul"(%a, %b)  : (i32, i32) -> i32
  %left  = "test.add"(%s1, %x) : (i32, i32) -> i32
  %right = "test.sub"(%s2, %y) : (i32, i32) -> i32
  %out   = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
