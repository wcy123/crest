// begin-mlir-code creates ops with the ambient current-OpBuilder, or with an explicit
// builder written (:builder expr), where :builder is a literal keyword.
//
//   test.one:   a helper with no builder parameter emits two ops from inside a
//               :rewrite :with body, where the pattern's builder is installed
//   test.two:   outside any DSL body, (with-current-OpBuilder b (begin-mlir-code ...))
//   test.three: begin-mlir-code with no builder installed raises an error; the pass
//               catches it and only then rewrites the op
//   test.four:  (begin-mlir-code (:builder b) ...) uses b, and installs it as the ambient
//               builder, so a helper called in the body emits with it too
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/ambient-builder" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[A:.*]] = "test.step_a"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[B:.*]] = "test.step_b"(%[[A]]) : (i32) -> i32
// CHECK-NEXT:    %[[C:.*]] = "test.two_out"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[D:.*]] = "test.three_ok"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[E:.*]] = "test.four_out"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[F:.*]] = "test.step_a"(%[[E]]) : (i32) -> i32
// CHECK-NEXT:    %[[G:.*]] = "test.step_b"(%[[F]]) : (i32) -> i32
// CHECK-NEXT:    return %[[B]], %[[C]], %[[D]], %[[G]] : i32, i32, i32, i32
// CHECK-NOT:     test.one
// CHECK-NOT:     test.two"
// CHECK-NOT:     test.three"
// CHECK-NOT:     test.four"

func.func @f(%a: i32) -> (i32, i32, i32, i32) {
  %0 = "test.one"(%a) : (i32) -> i32
  %1 = "test.two"(%a) : (i32) -> i32
  %2 = "test.three"(%a) : (i32) -> i32
  %3 = "test.four"(%a) : (i32) -> i32
  return %0, %1, %2, %3 : i32, i32, i32, i32
}
