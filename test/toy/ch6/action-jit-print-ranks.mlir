// toy.print lowers to an scf.for loop for each dimension: it prints a newline after each row of an
// inner dimension, and nothing after the elements of the last one. So a rank 3 array has a blank
// line between its planes, a rank 2 array has one row for each line, and a rank 1 array is on one
// line that has no newline at its end.
//
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/print-ranks.toy --emit=jit \
// RUN:   | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/print-ranks.toy --emit=jit --opt \
// RUN:   | FileCheck %s

// CHECK:      1.000000 2.000000{{ *$}}
// CHECK-NEXT: 3.000000 4.000000{{ *$}}
// CHECK-EMPTY:
// CHECK-NEXT: 5.000000 6.000000{{ *$}}
// CHECK-NEXT: 7.000000 8.000000{{ *$}}
// CHECK-EMPTY:
// CHECK-NEXT: 1.000000 2.000000 3.000000{{ *$}}
// CHECK-NEXT: 4.000000 5.000000 6.000000{{ *$}}
// CHECK-NEXT: 1.000000 2.000000 3.000000{{ *$}}
