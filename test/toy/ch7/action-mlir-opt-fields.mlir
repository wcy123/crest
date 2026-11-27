// With --opt each toy.struct_access folds to the toy.constant of its field: %0 is the field first (the
// 3 element vector) and %1 is the field second (the 2x2 array), and print(b) comes before print(a).
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/fields.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00]> : tensor<3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<{{[[]}}[4.000000e+00, 5.000000e+00], [6.000000e+00, 7.000000e+00]{{[]]}}> : tensor<2x2xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<2x2xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<3xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
