// crest-opt knows the dialects that the Scheme passes of this repository create ops of: arith, scf,
// memref, affine, cf and llvm, as toyc does. It knew only func, shape and tensor, so a text with an
// arith op was rejected ("Dialect `arith' not found") and a Scheme pass could not be tried on it.
//
// XFAIL: *
// RUN: %crest-opt %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         arith.addi
// CHECK:         scf.if
// CHECK:         memref.load
// CHECK:         affine.for
// CHECK:         affine.load
// CHECK:         llvm.add
// CHECK:         cf.br

func.func @f(%a: i32, %c: i1, %m: memref<4xf32>, %i: index) -> i32 {
  %0 = arith.addi %a, %a : i32
  %1 = scf.if %c -> (i32) {
    scf.yield %0 : i32
  } else {
    scf.yield %a : i32
  }
  %2 = memref.load %m[%i] : memref<4xf32>
  affine.for %j = 0 to 4 {
    %3 = affine.load %m[%j] : memref<4xf32>
  }
  %4 = llvm.add %a, %a : i32
  cf.br ^bb1
^bb1:
  return %1 : i32
}
