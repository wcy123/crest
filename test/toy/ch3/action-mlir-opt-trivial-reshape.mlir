// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/trivial_reshape.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<{{[[]}}[1.000000e+00], [2.000000e+00]{{[]]}}> : tensor<2x1xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<2x1xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
