// The lowering of a small program, with nothing else in the way: the constants become llvm constants,
// memref.alloc becomes malloc and a descriptor struct, the stores go through the descriptor's pointer,
// toy.print becomes the loop that calls printf (scf.for became llvm.br and llvm.cond_br), and
// memref.dealloc becomes free.
//
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/print.toy --emit=mlir-llvm \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   llvm.func @free(!llvm.ptr)
// CHECK-NEXT:   llvm.mlir.global internal constant @nl("\0A\00") {addr_space = 0 : i32}
// CHECK-NEXT:   llvm.mlir.global internal constant @frmt_spec("%{{[a-zA-Z0-9_]+}} \00") {addr_space = 0 : i32}
// CHECK-NEXT:   llvm.func @printf(!llvm.ptr, ...) -> i32
// CHECK-NEXT:   llvm.func @malloc(i64) -> !llvm.ptr
// CHECK-NEXT:   llvm.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.zero : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.ptrtoint %{{[a-zA-Z0-9_]+}} : !llvm.ptr to i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @malloc(%{{[a-zA-Z0-9_]+}}) : (i64) -> !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.addressof @frmt_spec : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : i64) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<4 x i8>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.addressof @nl : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : i64) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<2 x i8>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     llvm.br ^bb1(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb1(%{{[a-zA-Z0-9_]+}}: i64):  // 2 preds: ^bb0, ^bb2
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.icmp "slt" %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.cond_br %{{[a-zA-Z0-9_]+}}, ^bb2, ^bb3
// CHECK-NEXT:   ^bb2:  // pred: ^bb1
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.load %{{[a-zA-Z0-9_]+}} : !llvm.ptr -> f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @printf(%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}) vararg(!llvm.func<i32 (ptr, ...)>) : (!llvm.ptr, f64) -> i32
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.br ^bb1(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb3:  // pred: ^bb1
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
// CHECK-NEXT:     llvm.call @free(%{{[a-zA-Z0-9_]+}}) : (!llvm.ptr) -> ()
// CHECK-NEXT:     llvm.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
