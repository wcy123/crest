// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/example.toy --emit=mlir-affine --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   func.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 6.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 5.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 4.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 3.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 2.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 1.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<3x2xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<6xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[2] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[5] : memref<6xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.for %arg0 = 0 to 2 {
// CHECK-NEXT:       affine.for %arg1 = 0 to 3 {
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[%arg1, %arg0] : memref<3x2xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = arith.mulf %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:         affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = arith.mulf %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = arith.mulf %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:         affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:       }
// CHECK-NEXT:     }
// CHECK-NEXT:     affine.for %arg0 = 0 to 3 {
// CHECK-NEXT:       affine.for %arg1 = 0 to 2 {
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<3x2xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = arith.mulf %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:         affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<3x2xf64>
// CHECK-NEXT:       }
// CHECK-NEXT:     }
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<6xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<3x2xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<3x2xf64>
// CHECK-NEXT:     return
// CHECK-NEXT:   }
// CHECK-NEXT: }
