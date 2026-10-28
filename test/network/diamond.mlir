// Diamond topology — %shared feeds two paths that converge on test.combine.
//
//   %shared ──► test.add ──► %left ──┐
//                                    ├──► test.combine ──► %out
//   %shared ──► test.sub ──► %right ─┘
//
// :check-eq verifies the same %shared SSA value appears in both chains.
// Pattern rewrites to test.fused(%shared, %x, %y).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/network-diamond" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @diamond
// CHECK:       %[[SHARED:.*]] = "test.mul"(%arg0, %arg1)
// CHECK:       "test.fused"(%[[SHARED]], %arg2, %arg3) : (i32, i32, i32) -> i32
// CHECK-NOT:   test.combine

func.func @diamond(%a: i32, %b: i32, %x: i32, %y: i32) -> i32 {
  %shared = "test.mul"(%a, %b)   : (i32, i32) -> i32
  %left   = "test.add"(%shared, %x) : (i32, i32) -> i32
  %right  = "test.sub"(%shared, %y) : (i32, i32) -> i32
  %out    = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
