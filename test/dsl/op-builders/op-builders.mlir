// An op of a Scheme dialect can be created without `-> type` when it implements
// mlir::InferTypeOpInterface: bld.add takes the type of its left operand, bld.zero answers i64 with
// no operands at all, and an explicit `-> i64` still wins over the interface.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=bld=passes/bld-dialect passes=passes/use-builder" \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[SUM:.*]] = "bld.add"(%arg0, %arg1) : (i32, i32) -> i32
// CHECK-NEXT:    %[[ZERO:.*]] = "bld.zero"() : () -> i64
// CHECK-NEXT:    %[[WIDE:.*]] = "bld.add"(%arg0, %arg1) : (i32, i32) -> i64
// CHECK-NEXT:    "test.use"(%[[SUM]], %[[ZERO]], %[[WIDE]])

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
