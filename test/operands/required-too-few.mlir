// Negative: pattern expects 3 required operands, op has only 2.
//
// BUG (before fix): :bind-operand at index 2 calls mlir::OpOperand::get
//   out-of-bounds → exception "index out of range" (caught by per-check guard).
// Expected (after fix): :bind-operands FAILED: with source location — clean
//   structural match failure, no exception.
//
// CREST_DEBUG_MATCH=1 shows FAILED: with the actual op text.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/required-too-few" %s 2>&1 \
// RUN:   | %FileCheck %s

// After fix: clean FAILED: not exception
// CHECK: required-too-few.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%match\]}} :bind-operands FAILED:
// CHECK: actual: {{.*}}"test.add"(%arg0, %arg1)
// Pattern did not fire — test.add unchanged
// CHECK: "test.add"(%arg0, %arg1)

func.func @too_few(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
