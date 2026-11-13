// An op that implements InferTypeOpInterface may leave every result type out of its :assembly-format.
// The parser asks the interface for them once the operands and attributes are in, and the
// printer prints no result type. inf.add takes the type of its left operand, inf.zero has i64 with
// nothing in the text, inf.pair has two results. The generic form shows the inferred types, and it
// parses back to the same custom text.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/inf \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=inf=passes/inf | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/inf \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=inf=passes/inf --mlir-print-op-generic \
// RUN:   | %FileCheck %s --check-prefix=GENERIC
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/inf \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=inf=passes/inf --mlir-print-op-generic \
// RUN:   | env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/inf \
// RUN:     %crest-opt --mlir-disable-threading --crest-scheme-dialect=inf=passes/inf | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:      %{{.*}} = inf.add %arg0, %arg1 : i32, i32
// CHECK-NEXT: %{{.*}} = inf.add %arg2, %arg2 {tag = "t"} : f32, f32
// CHECK-NEXT: %{{.*}} = inf.zero
// CHECK-NEXT: %{{.*}}:2 = inf.pair %arg0 : i32

// GENERIC: "inf.add"(%arg0, %arg1) : (i32, i32) -> i32
// GENERIC: "inf.add"(%arg2, %arg2) {tag = "t"} : (f32, f32) -> f32
// GENERIC: "inf.zero"() : () -> i64
// GENERIC: "inf.pair"(%arg0) : (i32) -> (i32, i32)

func.func @f(%a: i32, %b: i32, %x: f32) {
  %0 = inf.add %a, %b : i32, i32
  %1 = inf.add %x, %x {tag = "t"} : f32, f32
  %2 = inf.zero
  %3:2 = inf.pair %a : i32
  return
}
