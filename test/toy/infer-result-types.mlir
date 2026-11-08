// C++ Toy builds AddOp, MulOp, TransposeOp, ConstantOp and StructAccessOp with builders that work out
// the result type, so its MLIRGen names none. Here those ops implement InferTypeOpInterface and
// mlir-gen leaves out `-> type` for them; check-infer-result-types.py lists the op-forms that still
// write one. Reshape, generic_call and struct_constant are built with an explicit type in C++ and
// keep it. The printed IR does not change: the action-mlir tests of each chapter cover that.
//
// XFAIL: *
// RUN: python3 %S/check-infer-result-types.py %S/../../samples/toy

module {}
