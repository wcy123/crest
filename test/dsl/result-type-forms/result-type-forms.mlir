// A result type after -> is a variable holding an mlir::Type, and several results list their types
// in parentheses. A parenthesised form is always a list of types, so a call used as the type is
// bound first with var = (expr), as the manual says.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/result-type-forms" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[A:.*]] = "test.one"() : () -> i64
// CHECK-NEXT:    %[[B:.*]]:2 = "test.two"() : () -> (i64, index)
// CHECK-NEXT:    "test.use"(%[[A]], %[[B]]#0, %[[B]]#1) : (i64, i64, index) -> ()
// CHECK-NOT:     test.src

func.func @f() {
  "test.src"() : () -> ()
  return
}
