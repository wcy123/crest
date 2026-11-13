// Moving an existing region into the op a pattern creates. Every region modifier of
// begin-mlir-code, (^bb ...), (^bb ,@types ...) and (:region ...), creates new blocks and fills
// them from op-forms, so a lowering that must keep the old body (a function-like op) cannot
// write the move declaratively and falls back to hand-written Scheme.
//
// test.src has one block with an argument and an op. Both RUN lines expect test.dst to hold
// that same block, with its argument and its op, and test.src to be gone.
//
//   adopt-by-hand  the control: the move written by hand (works today)
//   move-region    the DSL form (:move-region op)
//   move-ordered   (:move-region op 1) between two other region modifiers (second function)
//   move-conversion  (:move-region op) in a conversion pattern, third function: the moved ops are
//                    still legalized by the driver
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/adopt-by-hand" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme2 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/move-region" %s | %FileCheck %s

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme3 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/move-ordered" %s | %FileCheck %s --check-prefix=ORDER

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme5 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/move-nested" %s | %FileCheck %s --check-prefix=NEST
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme4 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/move-conversion" %s | %FileCheck %s --check-prefix=CONV

// CHECK-LABEL: func.func @f
// CHECK:         "test.dst"() ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.use"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : () -> ()
// CHECK-NOT:     test.src

// ORDER-LABEL: func.func @g
// ORDER:         "test.dst"() ({
// ORDER-NEXT:      "test.built"() : () -> ()
// ORDER-NEXT:    }, {
// ORDER-NEXT:    ^bb0(%[[B:.*]]: i32):
// ORDER-NEXT:      "test.second"(%[[B]]) : (i32) -> ()
// ORDER-NEXT:    }, {
// ORDER-NEXT:    }) : () -> ()
// ORDER-NOT:     test.two
// ORDER-NOT:     test.first

// CONV-LABEL: func.func @h
// CONV:         "test.dst"() ({
// CONV-NEXT:      "test.done"() : () -> ()
// CONV-NEXT:    }) : () -> ()
// CONV-NOT:     test.inner
// CONV-NOT:     test.src
// CONV-LABEL: func.func @n
// CONV:         "test.wrapper"() ({
// CONV-NEXT:      "test.dst"() ({
// CONV-NEXT:      ^bb0(%[[C:.*]]: i32):
// CONV-NEXT:        "test.use"(%[[C]]) : (i32) -> ()
// CONV-NEXT:      }) : () -> ()
// CONV-NEXT:    }) : () -> ()
// CONV-NEXT:    "test.after"() : () -> ()

// NEST-LABEL: func.func @n
// NEST:         "test.wrapper"() ({
// NEST-NEXT:      "test.dst"() ({
// NEST-NEXT:      ^bb0(%[[N:.*]]: i32):
// NEST-NEXT:        "test.use"(%[[N]]) : (i32) -> ()
// NEST-NEXT:      }) : () -> ()
// NEST-NEXT:    }) : () -> ()
// NEST-NEXT:    "test.after"() : () -> ()

func.func @f() {
  "test.src"() ({
  ^bb0(%a: i32):
    "test.use"(%a) : (i32) -> ()
  }) : () -> ()
  return
}

func.func @g() {
  "test.two"() ({
    "test.first"() : () -> ()
  }, {
  ^bb0(%b: i32):
    "test.second"(%b) : (i32) -> ()
  }) : () -> ()
  return
}

func.func @h() {
  "test.src"() ({
    "test.inner"() : () -> ()
  }) : () -> ()
  return
}

func.func @n() {
  "test.nested"() ({
  ^bb0(%n: i32):
    "test.use"(%n) : (i32) -> ()
  }) : () -> ()
  return
}
