// toy.add lowers to a loop nest that loads the left operand, then the right one, and stores their sum (arith.addf).
// With --opt the output is the same: there is one loop nest, and nothing to fuse or to forward.
//
// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/add.toy --emit=mlir-affine | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/add.toy --emit=mlir-affine --opt | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   func.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 6.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 5.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 4.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 3.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 2.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = arith.constant 1.000000e+00 : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = memref.alloc() : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 0] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 1] : memref<2x3xf64>
// CHECK-NEXT:     affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1, 2] : memref<2x3xf64>
// CHECK-NEXT:     affine.for %arg0 = 0 to 2 {
// CHECK-NEXT:       affine.for %arg1 = 0 to 3 {
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = affine.load %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:         %{{[a-zA-Z0-9_]+}} = arith.addf %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:         affine.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[%arg0, %arg1] : memref<2x3xf64>
// CHECK-NEXT:       }
// CHECK-NEXT:     }
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     memref.dealloc %{{[a-zA-Z0-9_]+}} : memref<2x3xf64>
// CHECK-NEXT:     return
// CHECK-NEXT:   }
// CHECK-NEXT: }
