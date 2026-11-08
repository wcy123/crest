// An attribute field with a :buildable-type prints without its type and parses without it, as the
// I64Attr of C++ Toy's StructAccessOp does (plans/27): `[1]`, not `[1 : i64]`. The generic form shows
// the type that the parser built the attribute with. As in C++, a text that still writes the type is not
// accepted: the generic form is how a typed attribute is written.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/ta \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ta=passes/ta | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/ta \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ta=passes/ta --mlir-print-op-generic \
// RUN:   | %FileCheck %s --check-prefix=GENERIC
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/ta \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ta=passes/ta --mlir-print-op-generic \
// RUN:   | env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/ta \
// RUN:     %crest-opt --mlir-disable-threading --crest-scheme-dialect=ta=passes/ta | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:      %{{.*}} = ta.index %arg0[1] : i32 -> f32
// CHECK-NEXT: %{{.*}} = ta.index %arg0[2] : i32 -> f32
// CHECK-NEXT: %{{.*}} = ta.scale %arg0 by 2.500000e+00 : i32 -> f32
// CHECK-NEXT: %{{.*}} = ta.at %arg0 at 3 : i32 -> i32

// GENERIC: "ta.index"(%arg0) {index = 1 : i64} : (i32) -> f32
// GENERIC: "ta.index"(%arg0) {index = 2 : i64} : (i32) -> f32
// GENERIC: "ta.scale"(%arg0) {factor = 2.500000e+00 : f32} : (i32) -> f32
// GENERIC: "ta.at"(%arg0) {position = 3 : index} : (i32) -> i32

func.func @f(%a: i32) {
  %0 = ta.index %a[1] : i32 -> f32
  %1 = ta.index %a[2] : i32 -> f32
  %2 = ta.scale %a by 2.5 : i32 -> f32
  %3 = ta.at %a at 3 : i32 -> i32
  return
}
