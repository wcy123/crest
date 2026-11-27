// The elements of a struct type are tensors or struct types (the verifier of StructType in C++).
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch7/toy %s verify 2>&1 | FileCheck %s

// CHECK: element type for a struct must either be a TensorType or a StructType

toy.func @f(%arg0: !toy.struct<f64>) {
  toy.return
}
