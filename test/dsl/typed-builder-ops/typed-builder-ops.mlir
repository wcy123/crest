// begin-mlir-code creates every op generically, through OperationState, so an op that
// needs a dialect-defined attribute needs that attribute supplied. A raw mlir::Attribute
// can be written `(name : value)`. Attributes are built with typed bindings that mirror the
// MLIR C++ API, for example the AffineMapAttr of an affine.load. See plans/06-g6.
//
// Facts from running each op through emit-op.sls with the dialects registered:
//   memref.load, memref.alloc, memref.dealloc   work
//   llvm.mlir.addressof                         works with (global_name : (FlatSymbolRefAttr::get ctx "g"))
//   llvm.call                                   works with callee, operandSegmentSizes and
//                                               op_bundle_sizes given
//   affine.load                                 works with (map : (mlir::AffineMapAttr::get
//                                               (mlir::AffineMap::getMultiDimIdentityMap 1))).
//                                               Without a map the op is created malformed and the
//                                               process crashes with "invalid memory reference"
//                                               when the verifier or canonicalizer reads it.
//
// The first RUN line is the control, memref.load. The second emits affine.load with its map.
// The third builds the other AffineMap and AffineMapAttr bindings as attributes of an
// unregistered op and prints them.
//
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s memref.load \
// RUN:   | %FileCheck %s --check-prefix=CONTROL
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s affine.load \
// RUN:   | %FileCheck %s --check-prefix=AFFINE
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s maps \
// RUN:   | %FileCheck %s --check-prefix=MAPS

// CONTROL: %{{.*}} = memref.load %arg0[%arg1] : memref<4xf32>
// AFFINE:  %{{.*}} = affine.load %arg0[{{.*}}%arg1{{.*}}] : memref<4xf32>
// MAPS-DAG: [[C:#map[0-9]*]] = affine_map<() -> (7)>
// MAPS-DAG: [[E:#map[0-9]*]] = affine_map<() -> ()>
// MAPS-DAG: [[RT:#map[0-9]*]] = affine_map<(d0, d1) -> (d0, d1)>
// MAPS:     "test.maps"(%arg0, %arg1) {c = [[C]], e = [[E]], rt = [[RT]]}

func.func @f(%m: memref<4xf32>, %i: index) -> f32 {
  %0 = "test.k"(%m, %i) : (memref<4xf32>, index) -> f32
  return %0 : f32
}
