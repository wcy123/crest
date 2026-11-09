// An op of a Scheme dialect can be created without `-> type` when it implements
// mlir::InferTypeOpInterface: bld.add takes the type of its left operand, bld.zero answers i64 with
// no operands at all, and an explicit `-> i32` is used as written.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=bld=passes/bld-dialect passes=passes/use-builder" \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[SUM:.*]] = "bld.add"(%arg0, %arg1) : (i32, i32) -> i32
// CHECK-NEXT:    %[[ZERO:.*]] = "bld.zero"() : () -> i64
// CHECK-NEXT:    %[[SAME:.*]] = "bld.add"(%arg0, %arg1) : (i32, i32) -> i32
// CHECK-NEXT:    "test.use"(%[[SUM]], %[[ZERO]], %[[SAME]])

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
