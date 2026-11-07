// C++ Toy rejects this IR (Dialect.cpp); so must ours: return type shape mismatches its attribute at dimension 0: 2 != 3
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: return type shape mismatches its attribute at dimension 0: 2 != 3

%0 = "toy.constant"() {value = dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>} : () -> tensor<3xf64>
