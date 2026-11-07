// C++ Toy rejects this IR (Dialect.cpp); so must ours: return type must match the one of the attached value attribute: 1 != 2
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: return type must match the one of the attached value attribute: 1 != 2

%0 = "toy.constant"() {value = dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>} : () -> tensor<2x1xf64>
