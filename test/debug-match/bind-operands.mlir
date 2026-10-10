// Tests that CREST_DEBUG_MATCH=1 reports :bind-operands/:check-where failures.
// Pattern expects test.sub with an optional second operand present (:where guard),
// but test.sub here has only one operand — :where fails.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-bind-operands" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [%%pattern] exception:

func.func @bind_operands(%a: i32, %b: i32) -> i32 {
  %0 = "test.sub"(%a) : (i32) -> i32
  %1 = "test.add"(%0, %0) : (i32, i32) -> i32
  return %1 : i32
}
