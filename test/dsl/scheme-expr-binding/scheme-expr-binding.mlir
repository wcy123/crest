// A Scheme expression's value can be named inside begin-mlir-code, so that a later
// op-form can use it:
//
//   elem    = test.load (v) -> ty
//   stepped = (%%step elem ty)        <- `var = (expr)`
//   next    = test.use (stepped) -> ty
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/scheme-expr-binding" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[L:.*]] = "test.load"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[S:.*]] = "test.step"(%[[L]]) : (i32) -> i32
// CHECK-NEXT:    %[[U:.*]] = "test.use"(%[[S]]) : (i32) -> i32
// CHECK-NEXT:    return %[[U]] : i32
// CHECK-NOT:     test.in

func.func @f(%a: i32) -> i32 {
  %0 = "test.in"(%a) : (i32) -> i32
  return %0 : i32
}
