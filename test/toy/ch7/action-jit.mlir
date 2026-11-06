// --emit=jit runs @main, and the program's own print output goes to stdout. This checks the
// result of the toy.print lowering (an scf.for nest calling printf): one row per line, for a
// 2x3 array, its 3x2 transpose, and a 1x4 array.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/print-shapes.toy --emit=jit \
// RUN:   | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/print-shapes.toy --emit=jit --opt \
// RUN:   | FileCheck %s

// CHECK:      1.000000 2.000000 3.000000
// CHECK-NEXT: 4.000000 5.000000 6.000000
// CHECK-NEXT: 1.000000 4.000000
// CHECK-NEXT: 2.000000 5.000000
// CHECK-NEXT: 3.000000 6.000000
// CHECK-NEXT: 1.000000 2.000000 3.000000 4.000000

// The struct example: print(c) shows a struct-valued program running through the same lowering.
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=jit \
// RUN:   | FileCheck %s --check-prefix=STRUCT

// STRUCT:      1.000000 16.000000
// STRUCT-NEXT: 4.000000 25.000000
// STRUCT-NEXT: 9.000000 36.000000
