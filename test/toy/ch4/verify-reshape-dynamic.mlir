// C++ Toy rejects this IR (Dialect.cpp); so must ours: must be #t
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: must be #t

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = toy.reshape(%0 : tensor<2xf64>) to tensor<?xf64>
