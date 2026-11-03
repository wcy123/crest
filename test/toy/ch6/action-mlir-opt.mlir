// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.transpose(%{{[a-zA-Z0-9_]+}} : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : (tensor<3x2xf64>, tensor<2x3xf64>) -> tensor<3x2xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
