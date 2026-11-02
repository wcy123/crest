// Ch7 after affine lowering: struct types are folded and erased;
// tensor ops are lowered to affine loops on memref; toy.print remains.
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir-affine \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK-NEXT:   func.func @main() {
// CHECK:          arith.constant 6.000000e+00 : f64
// CHECK:          memref.alloc() : memref<3x2xf64>
// CHECK:          affine.store
// CHECK:          affine.for
// CHECK:          toy.print
// CHECK:          memref.dealloc
// CHECK:          return
