// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/transpose_transpose.toy --emit=mlir \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:     toy.return %{{[a-zA-Z0-9_]+}} : tensor<*xf64>
// CHECK-NEXT:   }
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.reshape(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.generic_call @transpose_transpose(%{{[a-zA-Z0-9_]+}}) : (tensor<2x3xf64>) -> tensor<*xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<*xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
