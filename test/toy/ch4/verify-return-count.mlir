// C++ Toy rejects this IR (Dialect.cpp); so must ours: does not return the same number of values (1) as the enclosing function (0)
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: does not return the same number of values (1) as the enclosing function (0)

toy.func @f() {
  %0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
  toy.return %0 : tensor<2xf64>
}
