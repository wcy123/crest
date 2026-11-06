// begin-mlir-code creates every op generically, through OperationState, so an op that
// needs a dialect-defined attribute needs that attribute supplied. A raw mlir::Attribute
// can be written `(name : value)`. Attributes are built with typed bindings that mirror the
// MLIR C++ API; for an affine map, the affine-map-attr macro. See plans/06-g6 and
// docs/affine-map-dsl.md.
//
// Facts from running each op through emit-op.sls with the dialects registered:
//   memref.load, memref.alloc, memref.dealloc   work
//   llvm.mlir.addressof                         works with (global_name : (FlatSymbolRefAttr::get ctx "g"))
//   llvm.call                                   works with callee, operandSegmentSizes and
//                                               op_bundle_sizes given
//   affine.load                                 works with (map : (affine-map-attr (d0) () d0)).
//                                               Without a map the op is created malformed and the
//                                               process crashes with "invalid memory reference"
//                                               when the verifier or canonicalizer reads it.
//
// The first RUN line is the control, memref.load. The second emits affine.load with its map.
// The affine.load case also reads the map back from the op it created with getValue and
// checks that it is the map that was written. The third builds maps with the macro as
// attributes of an unregistered op and prints them. affine.load-map calls the AffineMap overloads
// of AffineLoadOp::create and AffineStoreOp::create, mlir::affine::AffineLoadOp::create<AffineMap>. The fourth calls the C++-mirroring factories directly. The
// fifth builds every operator of affine-map and prints the maps.
//
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s memref.load \
// RUN:   | %FileCheck %s --check-prefix=CONTROL
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s affine.load \
// RUN:   | %FileCheck %s --check-prefix=AFFINE
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s affine.load-map \
// RUN:   | %FileCheck %s --check-prefix=LOADMAP
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s maps \
// RUN:   | %FileCheck %s --check-prefix=MAPS
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s factories \
// RUN:   | %FileCheck %s --check-prefix=FACTORIES
// RUN: env CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/emit-op.sls %s exprs \
// RUN:   | %FileCheck %s --check-prefix=EXPRS

// CONTROL: %{{.*}} = memref.load %arg0[%arg1] : memref<4xf32>
// AFFINE:  (map-read-back-equals-written #t)
// AFFINE:  %{{.*}} = affine.load %arg0[{{.*}}%arg1{{.*}}] : memref<4xf32>
// LOADMAP: %[[V:.*]] = affine.load %arg0[{{.*}}%arg1{{.*}}] : memref<4xf32>
// LOADMAP: affine.store %[[V]], %arg0[{{.*}}%arg1{{.*}}] : memref<4xf32>
// MAPS-DAG: [[C:#map[0-9]*]] = affine_map<() -> (7)>
// MAPS-DAG: [[E:#map[0-9]*]] = affine_map<() -> ()>
// MAPS-DAG: [[ID:#map[0-9]*]] = affine_map<(d0, d1) -> (d0, d1)>
// MAPS:     "test.maps"(%arg0, %arg1) {c = [[C]], e = [[E]], id = [[ID]]}

// FACTORIES-DAG: [[I2:#map[0-9]*]] = affine_map<(d0, d1) -> (d0, d1)>
// FACTORIES-DAG: [[K:#map[0-9]*]] = affine_map<() -> (7)>
// FACTORIES-DAG: [[G:#map[0-9]*]] = affine_map<() -> ()>
// FACTORIES:     "test.factories"(%arg0, %arg1) {g = [[G]], i2 = [[I2]], k = [[K]]}

// EXPRS-DAG: [[A:#map[0-9]*]] = affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>
// EXPRS-DAG: [[B:#map[0-9]*]] = affine_map<(d0) -> (d0 floordiv 4, d0 mod 4)>
// EXPRS-DAG: [[C2:#map[0-9]*]] = affine_map<(d0, d1) -> (d0 - d1, d1 * 2)>
// EXPRS-DAG: [[CE:#map[0-9]*]] = affine_map<(d0) -> (d0 ceildiv 3)>
// EXPRS-DAG: [[N:#map[0-9]*]] = affine_map<() -> (6)>
// EXPRS-DAG: [[NEG:#map[0-9]*]] = affine_map<(d0) -> (-d0)>
// EXPRS-DAG: [[Z:#map[0-9]*]] = affine_map<(d0, d1)[s0] -> ()>
// EXPRS:     "test.exprs"(%arg0, %arg1) {a = [[A]], b = [[B]], c = [[C2]], ce = [[CE]], n = [[N]], neg = [[NEG]], z = [[Z]]}

func.func @f(%m: memref<4xf32>, %i: index) -> f32 {
  %0 = "test.k"(%m, %i) : (memref<4xf32>, index) -> f32
  return %0 : f32
}
