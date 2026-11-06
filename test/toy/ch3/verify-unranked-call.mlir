// toy.generic_call returns an unranked tensor, as the front end emits it before shape inference:
// the verifier must accept it. The ranked-only result predicate made it reject the front end's own IR.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch3/toy %s verify | FileCheck %s

// CHECK: toy.generic_call @callee(%{{.*}}) : (tensor<2xf64>) -> tensor<*xf64>

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = toy.generic_call @callee(%0) : (tensor<2xf64>) -> tensor<*xf64>
