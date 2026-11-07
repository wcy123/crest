// toy.add, toy.mul, toy.transpose and toy.generic_call accept any tensor: the front end emits
// tensor<*xf64> results before shape inference. The input is in generic form and prints in the custom
// form of the C++ assemblyFormat. The verifier, which the pass manager runs first, must accept it.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch2/toy %s verify | FileCheck %s

// CHECK: toy.transpose(%{{.*}} : tensor<2x3xf64>) to tensor<*xf64>
// CHECK: toy.add %{{.*}}, %{{.*}} : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK: toy.mul %{{.*}}, %{{.*}} : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK: toy.generic_call @f(%{{.*}}) : (tensor<2x3xf64>) -> tensor<*xf64>

%0 = "toy.constant"() {value = dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>} : () -> tensor<2x3xf64>
%1 = "toy.transpose"(%0) : (tensor<2x3xf64>) -> tensor<*xf64>
"toy.print"(%1) : (tensor<*xf64>) -> ()
%2 = "toy.add"(%0, %0) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
"toy.print"(%2) : (tensor<*xf64>) -> ()
%3 = "toy.mul"(%0, %0) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
"toy.print"(%3) : (tensor<*xf64>) -> ()
%4 = "toy.generic_call"(%0) {callee = @f} : (tensor<2x3xf64>) -> tensor<*xf64>
"toy.print"(%4) : (tensor<*xf64>) -> ()
