// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/example.toy --emit=mlir-affine \
// RUN:   | %FileCheck %s

// CHECK: func.func @main
// CHECK: arith.constant {{.*}} : f64
// CHECK: memref.alloc() : memref<{{.*}}xf64>
// CHECK: affine.store
// CHECK: affine.for
// CHECK: arith.mulf
// CHECK: memref.dealloc
// CHECK: return
