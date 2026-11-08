// LowerToAffineLoops.cpp creates arith::AddFOp and arith::MulFOp from their two operands, which infer
// their result type, so it names none. lower-to-affine.sls (ch5 to ch7) does the same: arith.addf and
// arith.mulf implement InferTypeOpInterface, as test/dsl/op-builders/cxx-ops.mlir shows. The other ops
// it creates (affine.load, arith.constant, memref.alloc and so on) take a type in C++ as well.
//
// XFAIL: *
// RUN: python3 %S/check-infer-result-types.py %S/../../samples/toy lowering

module {}
