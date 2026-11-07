// toy.cast bridges a ranked tensor to an unranked one at a call boundary, so its result is often
// unranked: the verifier must accept it. The ranked-only result predicate rejected the op the
// inliner interface itself creates.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify | FileCheck %s

// CHECK: toy.cast %{{.*}} : tensor<2xf64> to tensor<*xf64>

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = toy.cast %0 : tensor<2xf64> to tensor<*xf64>
