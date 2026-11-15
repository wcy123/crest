// The code of a :where guard is searched for (:attr "name"), (:has-attr? ...) and :current-op, which are
// replaced by what they stand for. The search must not go into a quote: '(:attr "k") is a list of data, and a
// guard that reads it gets the list that it wrote.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/where-quote-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --crest-pass="passes=passes/where-quote" %s | %FileCheck %s

// The guard of test.add is true, so it is fused. The guard of test.mul is false (the same quoted list, asked about
// :other), so it stays: a guard that was not evaluated at all would fuse both.
//
// CHECK-LABEL: func.func @f
// CHECK:       "test.fused"
// CHECK:       "test.mul"
// CHECK-NOT:   "test.fused"

func.func @f(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  %1 = "test.mul"(%0, %b) : (i32, i32) -> i32
  return %1 : i32
}
