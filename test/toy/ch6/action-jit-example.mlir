// --emit=jit runs the whole pipeline on the example and executes @main: the 2x3 array e, one row for
// each line. The result is the same with and without --opt.
//
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=jit \
// RUN:   | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=jit --opt \
// RUN:   | FileCheck %s

// CHECK:      1.000000 16.000000 81.000000{{ *$}}
// CHECK-NEXT: 256.000000 625.000000 1296.000000{{ *$}}
