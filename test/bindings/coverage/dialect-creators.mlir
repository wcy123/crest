// The bindings that make ops of the arith, memref and scf dialects, and the blocks around them, are used to
// build the body of the function below (dialect-creators.sls). Each of them was named by no other test.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/coverage-scheme \
// RUN:   %scheme-mlir %S/dialect-creators.sls %s | %FileCheck %s

// CHECK: induction variable: yes
// CHECK: func.func private @kernel(%[[X:.*]]: f64) {
// CHECK:   %[[C0:.*]] = arith.constant 0 : index
// CHECK:   %[[C4:.*]] = arith.constant 4 : index
// CHECK:   %[[C1:.*]] = arith.constant 1 : index
// CHECK:   %[[TWO:.*]] = arith.constant 2.500000e+00 : f64
// CHECK:   %[[SUM:.*]] = arith.addf %[[X]], %[[TWO]] : f64
// CHECK:   arith.mulf %[[SUM]], %[[X]] : f64
// CHECK:   %[[BUFFER:.*]] = memref.alloc() : memref<4xf64>
// CHECK:   memref.load %[[BUFFER]][%[[C0]]] : memref<4xf64>
// CHECK:   scf.for %{{.*}} = %[[C0]] to %[[C4]] step %[[C1]] {
// CHECK:     scf.yield
// CHECK:   }
// CHECK:   memref.dealloc %[[BUFFER]] : memref<4xf64>
// CHECK:   return

func.func private @kernel(f64)
