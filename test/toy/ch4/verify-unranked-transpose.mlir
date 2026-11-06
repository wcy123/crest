// toy.transpose accepts any tensor, as mul and add do: the front end emits tensor<*xf64> results
// before shape inference. The verifier, which the pass manager runs first, must accept it.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify | FileCheck %s

// CHECK: toy.transpose(%{{.*}} : tensor<2x3xf64>) to tensor<*xf64>

%0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
%1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<*xf64>
toy.print %1 : tensor<*xf64>
