// C++ Toy rejects this IR (Dialect.cpp); so must ours: type of return operand (tensor<2xf64>) doesn't match function result type (tensor<3xf64>)
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: type of return operand (tensor<2xf64>) doesn't match function result type (tensor<3xf64>)

toy.func @f(%arg0: tensor<2xf64>) -> tensor<3xf64> {
  toy.return %arg0 : tensor<2xf64>
}
