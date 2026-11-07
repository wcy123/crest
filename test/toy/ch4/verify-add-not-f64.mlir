// C++ Toy rejects this IR (Dialect.cpp); so must ours: must be #t
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: must be #t

%0 = "toy.constant"() {value = dense<[1, 2]> : tensor<2xi64>} : () -> tensor<2xi64>
%1 = toy.add %0, %0 : tensor<2xi64>
