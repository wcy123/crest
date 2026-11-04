// begin-mlir-code creates every op generically, through OperationState. That works for
// ops whose verifier is satisfied by the operands, result types and attributes the DSL
// supplies, and not for ops that need a typed C++ builder. See plans/06-g6 (G6).
//
// Facts from running each op through emit-op.sls with the dialects registered:
//   memref.load, memref.alloc, memref.dealloc   works
//   llvm.mlir.addressof                         works with (global_name : (FlatSymbolRefAttr::get ctx "g"))
//   llvm.call                                   works only with callee, operandSegmentSizes and
//                                               op_bundle_sizes given, all buildable with today's shorthands
//   affine.load, affine.store                   the op has no `map` attribute and nothing in the DSL
//                                               can build one (no AffineMapAttr binding): the process
//                                               crashes with "invalid memory reference" when the
//                                               verifier or canonicalizer reads the missing map
//
// The first RUN line is the control: memref.load works. The second shows affine.load.
// It is expected to emit `affine.load %arg0[%arg1]` and does not. Remove XFAIL when affine
// ops can be written as op-forms; which fix (D3) decides what the pass has to supply.
//
// XFAIL: *
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s memref.load \
// RUN:   | %FileCheck %s --check-prefix=CONTROL
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s affine.load \
// RUN:   | %FileCheck %s --check-prefix=AFFINE

// CONTROL: %{{.*}} = memref.load %arg0[%arg1] : memref<4xf32>
// AFFINE:  %{{.*}} = affine.load %arg0[%arg1] : memref<4xf32>

func.func @f(%m: memref<4xf32>, %i: index) -> f32 {
  %0 = "test.k"(%m, %i) : (memref<4xf32>, index) -> f32
  return %0 : f32
}
