// Optional operand in the middle — absent case.
// operandSegmentSizes = [1, 0, 1]: required %a, optional %b absent, required %c.
// Pattern fires and rewrites to test.fused(%a, %c).
//
// BUG: same variable binding order issue as optional-middle-present.mlir.
// Pattern correctly DETECTS the structure and fires, but variable binding is wrong.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/optional-middle" %s \
// RUN:   | %FileCheck %s

// Pattern fires (op is rewritten) — exact arg order is currently wrong (see BUG above)
// CHECK: test.fused

func.func @mid_absent(%a: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %c) {operandSegmentSizes = array<i32: 1, 0, 1>}
       : (i32, i32) -> i32
  return %0 : i32
}
