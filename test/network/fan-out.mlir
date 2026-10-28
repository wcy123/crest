// Fan-out topology: one value (%shared) used by both operands of test.add.
//
//               ┌──► test.add(_, _) ──► %out
//   test.mul ──►┤
//               └──► (same value)
//
// :check-eq verifies both operands of test.add are the same SSA value.
// Pattern rewrites to test.square(%shared).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/network-fan-out" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @fan_out
// CHECK:       %[[SHARED:.*]] = "test.mul"(%arg0)
// CHECK:       "test.square"(%[[SHARED]]) : (i32) -> i32
// CHECK-NOT:   test.add

func.func @fan_out(%a: i32) -> i32 {
  %shared = "test.mul"(%a)          : (i32) -> i32
  %out    = "test.add"(%shared, %shared) : (i32, i32) -> i32
  return %out : i32
}
