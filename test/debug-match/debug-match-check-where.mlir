// CREST_DEBUG_MATCH=1 — :check-where guard failure
//
// Pattern matches test.add but :where (eqv? (getNumResults (getDefiningOp %a)) 99)
// always fails because %a is a block argument with no defining op.
// The exception from getDefiningOp(block-arg)=null is caught and logged.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-where" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [warning] unknown: [%%check-where-always-false] exception:
// CHECK-SAME: mlir::Operation::getNumResults

func.func @check_where(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
