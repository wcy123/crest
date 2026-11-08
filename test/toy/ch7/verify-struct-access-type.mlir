// toy.struct_access must have the type of the element it names (C++ StructAccessOp::verify).
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch7/toy %s verify 2>&1 | FileCheck %s

// CHECK: must have the same result type as the struct element referred to by the index

toy.func @f(%arg0: !toy.struct<tensor<*xf64>, tensor<2xf64>>) {
  %0 = toy.struct_access %arg0[1] : !toy.struct<tensor<*xf64>, tensor<2xf64>> -> tensor<3xf64>
  toy.return
}
