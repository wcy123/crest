// Positive: optional operand absent — :where (unbound-value? %b) matches.
//
// BUG (before fix): operation-get-operands has-flex detection is broken —
//   it checks 'optional (no colon) but spec uses :optional (with colon).
//   So it always takes the all-required path, throwing "operand count mismatch"
//   (n-spec=2 but n-ops=1).
// Expected (after fix): has-flex detects :optional correctly, reads
//   operandSegmentSizes, binds %b to unbound-value, :where (unbound-value? %b) = #t,
//   pattern matches and rewrites to test.fused(%a).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/optional-absent" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0) : (i32) -> i32

func.func @opt_absent(%a: i32) -> i32 {
  %0 = "test.add"(%a) {operandSegmentSizes = array<i32: 1, 0>}
       : (i32) -> i32
  return %0 : i32
}
