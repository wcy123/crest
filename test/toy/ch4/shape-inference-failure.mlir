// The shape inference pass fails, as the C++ ShapeInferencePass does, when an operation's result
// is still not a ranked tensor: a call to a function that is not there is not inlined, so its
// unranked result cannot be inferred.
//
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %s --emit=mlir --opt 2>&1 | FileCheck %s

// CHECK: error: Shape inference failed, 1 operations couldn't be inferred

toy.func @main() {
  %0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
  %1 = toy.generic_call @missing(%0) : (tensor<2xf64>) -> tensor<*xf64>
  toy.print %1 : tensor<*xf64>
  toy.return
}
