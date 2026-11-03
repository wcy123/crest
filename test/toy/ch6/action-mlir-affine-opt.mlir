// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=mlir-affine --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK:         func.func @main() {
// CHECK-DAG:       {{%.*}} = arith.constant 1.000000e+00 : f64
// CHECK-DAG:       {{%.*}} = arith.constant 6.000000e+00 : f64
// CHECK:           {{%.*}} = memref.alloc() : memref<{{.*}}xf64>
// CHECK:           affine.store {{%.*}}, {{%.*}}[{{.*}}] : memref<{{.*}}xf64>
// CHECK:           affine.for {{%.*}} = 0 to {{[0-9]+}} {
// CHECK-NEXT:        affine.for {{%.*}} = 0 to {{[0-9]+}} {
// CHECK:           arith.mulf
// CHECK:           memref.dealloc {{%.*}} : memref<{{.*}}xf64>
// CHECK:           return
