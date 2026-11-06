// The inliner interface's materializeCallConversion callback is called with the builder MLIR is
// using, and the builder bindings accept it, so the callback can create the toy.cast that bridges
// a ranked operand to an unranked parameter. It used to get a raw OpBuilder* address, which no
// builder binding accepts, and failed with "expected a builder".
//
// RUN: %scheme-mlir %S/../materialize.sls toy/ch4/toy cast %s | FileCheck %s

// CHECK: toy.cast(%{{.*}} : tensor<2x3xf64>) to tensor<*xf64>

%0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
