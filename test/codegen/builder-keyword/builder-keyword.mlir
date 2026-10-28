// Tests :builder and (:arg N) as proper macros usable in Scheme context.
// Pattern: test.copy(%v) → test.with_block(%v) {^bb0(%arg): test.yield %arg}
// :builder passed to Scheme helper inside block; (:arg 0) accesses block arg.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/builder-keyword" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @test_i32
// CHECK:         "test.with_block"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.yield"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : (i32) -> i32
// CHECK-NOT:     test.copy

func.func @test_i32(%arg0: i32) -> i32 {
  %0 = "test.copy"(%arg0) : (i32) -> i32
  return %0 : i32
}
