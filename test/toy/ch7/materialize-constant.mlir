// A Scheme dialect's :materialize-constant callback is called with the builder MLIR is using,
// and the builder bindings accept it, so the callback can create an op. The callback used to get a
// raw OpBuilder* address, which no builder binding accepts, and failed with "expected a builder".
//
// RUN: %scheme-mlir %S/../materialize.sls toy/ch7/toy constant | FileCheck %s

// CHECK: toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
