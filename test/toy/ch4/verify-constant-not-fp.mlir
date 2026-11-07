// C++ Toy rejects an integer constant (the F64ElementsAttr constraint of ConstantOp); so must ours.
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: type mismatch: (%%f64-elements-attr? value) must be #t

%0 = "toy.constant"() {value = dense<[1, 2]> : tensor<2xi64>} : () -> tensor<2xf64>
