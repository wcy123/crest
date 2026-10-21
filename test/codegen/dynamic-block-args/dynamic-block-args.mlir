// Tests ,@pairs-expr dynamic block args and (:arg N) shorthand in begin-mlir-code.
//
// The pattern rewrites test.copy(%v) → test.with_block(%v) where the block arg
// type is computed at runtime from %v's type, and (:arg 0) accesses it inside
// the block body.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/dynamic-block-args" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @copy_i32
// CHECK:         "test.with_block"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.yield"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : (i32) -> i32
// CHECK-NOT:     test.copy

func.func @copy_i32(%arg0: i32) -> i32 {
  %0 = "test.copy"(%arg0) : (i32) -> i32
  return %0 : i32
}

// CHECK-LABEL: func.func @copy_f32
// CHECK:         "test.with_block"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[B:.*]]: f32):
// CHECK-NEXT:      "test.yield"(%[[B]]) : (f32) -> ()
// CHECK-NEXT:    }) : (f32) -> f32
// CHECK-NOT:     test.copy

func.func @copy_f32(%arg0: f32) -> f32 {
  %0 = "test.copy"(%arg0) : (f32) -> f32
  return %0 : f32
}
