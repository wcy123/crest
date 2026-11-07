// toy.struct_access rejects an index outside the struct type (C++ StructAccessOp::verify).
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch7/toy %s verify 2>&1 | FileCheck %s

// CHECK: index should be within the range of the input struct type

toy.func @f(%arg0: tuple<tensor<*xf64>, tensor<*xf64>>) {
  %0 = toy.struct_access %arg0[2 : i64] : tuple<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
  toy.return
}
