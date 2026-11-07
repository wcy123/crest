// :assembly-format (plans/16): the text form of an op is one ODS string. Each op of passes/af.sls
// parses its format and prints the same text back; the generic form parses back to the same custom
// text (the printer and the parser agree). The spacing is that of OpFormatGen.cpp.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/af \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=af=passes/af | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/af \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=af=passes/af --mlir-print-op-generic \
// RUN:   | env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/af \
// RUN:     %crest-opt --mlir-disable-threading --crest-scheme-dialect=af=passes/af | %FileCheck %s

// CHECK-LABEL: func.func @all_ops
// CHECK:      %[[U:.*]] = af.unary %arg0 : i32 to f32
// CHECK-NEXT: %{{.*}} = af.unary %arg0 {tag = "t"} : i32 to f32
// CHECK-NEXT: %{{.*}} = af.wrap(%arg0 : i32) to f64
// CHECK-NEXT: %{{.*}} = af.plus %arg0, %arg0 : i32, i32 -> i64
// CHECK-NEXT: %{{.*}} = af.call @f(%arg0, %arg0) : (i32, i32) -> f32
// CHECK-NEXT: %{{.*}} = af.call @g() : () -> i1
// CHECK-NEXT: %{{.*}} = af.all(%arg0, %arg0) : (i32, i32) -> f32
// CHECK-NEXT: af.ret %arg0 : i32
// CHECK-NEXT: af.ret
// CHECK-NEXT: af.ret {note = 1 : i32}
// CHECK-NEXT: %{{.*}} = af.index %arg0[1 : i64] : i32 -> f32
// CHECK-NEXT: af.two_attrs 1 : i64, 2 : i64
// CHECK-NEXT: af.two_attrs 1 : i64, 2 : i64 {extra = 3 : i32}
// CHECK-NEXT: af.box<%arg0 : i32>
// CHECK-NEXT: af.with with %arg0 : i32
func.func @all_ops(%a: i32) {
  %0 = af.unary %a : i32 to f32
  %1 = af.unary %a {tag = "t"} : i32 to f32
  %2 = af.wrap(%a : i32) to f64
  %3 = af.plus %a, %a : i32, i32 -> i64
  %4 = af.call @f(%a, %a) : (i32, i32) -> f32
  %5 = af.call @g() : () -> i1
  %6 = af.all(%a, %a) : (i32, i32) -> f32
  af.ret %a : i32
  af.ret
  af.ret {note = 1 : i32}
  %7 = af.index %a[1] : i32 -> f32
  af.two_attrs 1, 2
  af.two_attrs 1, 2 {extra = 3 : i32}
  af.box<%a : i32>
  af.with with %a : i32
  return
}
