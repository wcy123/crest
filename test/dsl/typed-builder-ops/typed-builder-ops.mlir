// begin-mlir-code creates every op generically, through OperationState, so an op that
// needs a dialect-defined attribute needs that attribute supplied. A raw mlir::Attribute
// can be written `(name : value)`, and mlir::parseAttribute builds one from its textual
// form, so any attribute with a textual syntax in a loaded dialect is available. See
// plans/06-g6.
//
// Facts from running each op through emit-op.sls with the dialects registered:
//   memref.load, memref.alloc, memref.dealloc   work
//   llvm.mlir.addressof                         works with (global_name : (FlatSymbolRefAttr::get ctx "g"))
//   llvm.call                                   works with callee, operandSegmentSizes and
//                                               op_bundle_sizes given
//   affine.load                                 works with (map : (mlir::parseAttribute
//                                               "affine_map<(d0) -> (d0)>")). Without a map
//                                               the op is created malformed and the process
//                                               crashes with "invalid memory reference" when the
//                                               verifier or canonicalizer reads the missing map.
//
// The first RUN line is the control, memref.load. The second emits affine.load with its map.
//
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s memref.load \
// RUN:   | %FileCheck %s --check-prefix=CONTROL
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s affine.load \
// RUN:   | %FileCheck %s --check-prefix=AFFINE

// CONTROL: %{{.*}} = memref.load %arg0[%arg1] : memref<4xf32>
// AFFINE:  %{{.*}} = affine.load %arg0[{{.*}}%arg1{{.*}}] : memref<4xf32>

func.func @f(%m: memref<4xf32>, %i: index) -> f32 {
  %0 = "test.k"(%m, %i) : (memref<4xf32>, index) -> f32
  return %0 : f32
}
