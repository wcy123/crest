// Diamond topology — NEGATIVE: producer has two results; each path takes a different one.
//
//   test.mul → result 0 ──► test.add ──► %left ──┐
//                                                 ├──► test.combine ──► %out
//   test.mul → result 1 ──► test.sub ──► %right ─┘
//
// The pattern expects %shared to be the SAME mlir::Value in both test.add and
// test.sub.  Result 0 and result 1 are distinct mlir::Value objects even though
// they come from the same op — eqv? correctly returns #f.
// Pattern does NOT fire: test.combine remains in the output.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/network-diamond" %s 2>&1 \
// RUN:   | %FileCheck %s

// eqv? fails: result 1 (operand of test.sub) != result 0 (%shared from test.add)
// CHECK: network-diamond.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%diamond\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.sub"
// Pattern did not fire — test.combine still present
// CHECK: "test.combine"
// CHECK-NOT: test.fused

func.func @two_result_diamond(%a: i32, %b: i32, %x: i32, %y: i32) -> i32 {
  %r0, %r1 = "test.mul"(%a, %b) : (i32, i32) -> (i32, i32)
  %left  = "test.add"(%r0, %x) : (i32, i32) -> i32
  %right = "test.sub"(%r1, %y) : (i32, i32) -> i32
  %out   = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
