// toy.add and toy.mul accept any tensor result, as transpose and the calls do: the front end emits
// tensor<*xf64> results before shape inference, and the verifier (which MLIR's passes run) must accept
// them, as it does in Ch5 to Ch7. The ranked-only predicate rejected the front end's own IR.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify | FileCheck %s

// CHECK: toy.add %{{.*}}, %{{.*}} : (tensor<2xf64>, tensor<2xf64>) -> tensor<*xf64>
// CHECK: toy.mul %{{.*}}, %{{.*}} : (tensor<2xf64>, tensor<2xf64>) -> tensor<*xf64>

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = toy.add %0, %0 : (tensor<2xf64>, tensor<2xf64>) -> tensor<*xf64>
%2 = toy.mul %0, %0 : (tensor<2xf64>, tensor<2xf64>) -> tensor<*xf64>
toy.print %1 : tensor<*xf64>
toy.print %2 : tensor<*xf64>
