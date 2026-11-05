// Moving an existing region into the op a pattern creates. Every region modifier of
// begin-mlir-code, (^bb ...), (^bb ,@types ...) and (:region ...), creates new blocks and fills
// them from op-forms, so a lowering that must keep the old body (a function-like op) cannot
// write the move declaratively and falls back to hand-written Scheme. See plans/07-g7.
//
// test.src has one block with an argument and an op. Both RUN lines expect test.dst to hold
// that same block, with its argument and its op, and test.src to be gone.
//
//   adopt-by-hand  the control: the move written by hand (works today)
//   take-region    the DSL form (:take-region op 0), which does not exist yet
//
// Remove XFAIL when G7 is implemented. The syntax is the one proposed in the plan; if another
// is chosen, change take-region.sls.
//
// XFAIL: *
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/adopt-by-hand" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme2 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/take-region" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.dst"() ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.use"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : () -> ()
// CHECK-NOT:     test.src

func.func @f() {
  "test.src"() ({
  ^bb0(%a: i32):
    "test.use"(%a) : (i32) -> ()
  }) : () -> ()
  return
}
