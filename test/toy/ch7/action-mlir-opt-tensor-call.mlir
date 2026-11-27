// The inliner puts a toy.cast where a call passes a tensor to a parameter of another type, and shape
// inference gives the cast the type of its operand. A toy.cast to the type its operand already has folds
// to the operand (what CastOpInterface's folder does in C++), so no cast is left. The example of this
// chapter passes only structs, so it has no cast: this program is the one that reaches the folder.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/tensor-call.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : tensor<2xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<2xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
