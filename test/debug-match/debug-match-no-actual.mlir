// CREST_DEBUG_MATCH=1 — :set-current-op is pure setup, :check-op is the gate.
//
// Pattern expects test.sub's operand to come from test.add.
// The IR passes a block argument (%x has no defining op).
// :set-current-op writes 0 to the slot and continues (#t).
// :check-op then fails with (string=? "" "test.add") → FAILED: logged.
// No actual: because the op slot is 0 (no op to print).

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-no-actual" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: {{\[%%chain-no-actual\]}} :check-op FAILED: (and (string=? (mlir::Operation::getName (vector-ref all-operations 0)) "test.add") (= (mlir::Operation::getNumResults (vector-ref all-operations 0)) 1))
// CHECK-NOT: actual:

func.func @no_chain(%x: i32) -> i32 {
  %0 = "test.sub"(%x) : (i32) -> i32
  return %0 : i32
}
