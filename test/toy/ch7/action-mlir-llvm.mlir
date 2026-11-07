// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir-llvm --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   llvm.func @free(!llvm.ptr)
// CHECK-NEXT:   llvm.mlir.global internal constant @nl("\0A\00") {addr_space = 0 : i32}
// CHECK-NEXT:   llvm.mlir.global internal constant @frmt_spec("%{{[a-zA-Z0-9_]+}} \00") {addr_space = 0 : i32}
// CHECK-NEXT:   llvm.func @printf(!llvm.ptr, ...) -> i32
// CHECK-NEXT:   llvm.func @malloc(i64) -> !llvm.ptr
// CHECK-NEXT:   llvm.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(6.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(5.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(4.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1.000000e+00 : f64) : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(6 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.zero : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.ptrtoint %{{[a-zA-Z0-9_]+}} : !llvm.ptr to i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @malloc(%{{[a-zA-Z0-9_]+}}) : (i64) -> !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(6 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.zero : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.ptrtoint %{{[a-zA-Z0-9_]+}} : !llvm.ptr to i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @malloc(%{{[a-zA-Z0-9_]+}}) : (i64) -> !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.insertvalue %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     llvm.br ^bb1(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb1(%{{[a-zA-Z0-9_]+}}: i64):  // 2 preds: ^bb0, ^bb5
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.icmp "slt" %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.cond_br %{{[a-zA-Z0-9_]+}}, ^bb2, ^bb6
// CHECK-NEXT:   ^bb2:  // pred: ^bb1
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     llvm.br ^bb3(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb3(%{{[a-zA-Z0-9_]+}}: i64):  // 2 preds: ^bb2, ^bb4
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.icmp "slt" %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.cond_br %{{[a-zA-Z0-9_]+}}, ^bb4, ^bb5
// CHECK-NEXT:   ^bb4:  // pred: ^bb3
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.load %{{[a-zA-Z0-9_]+}} : !llvm.ptr -> f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.fmul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     llvm.store %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : f64, !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.br ^bb3(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb5:  // pred: ^bb3
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.br ^bb1(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb6:  // pred: ^bb1
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.addressof @frmt_spec : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : i64) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<4 x i8>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.addressof @nl : !llvm.ptr
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : i64) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<2 x i8>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(3 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     llvm.br ^bb7(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb7(%{{[a-zA-Z0-9_]+}}: i64):  // 2 preds: ^bb6, ^bb11
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.icmp "slt" %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.cond_br %{{[a-zA-Z0-9_]+}}, ^bb8, ^bb12
// CHECK-NEXT:   ^bb8:  // pred: ^bb7
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(0 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(1 : index) : i64
// CHECK-NEXT:     llvm.br ^bb9(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb9(%{{[a-zA-Z0-9_]+}}: i64):  // 2 preds: ^bb8, ^bb10
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.icmp "slt" %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.cond_br %{{[a-zA-Z0-9_]+}}, ^bb10, ^bb11
// CHECK-NEXT:   ^bb10:  // pred: ^bb9
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mlir.constant(2 : index) : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.mul %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} overflow<nsw, nuw> : i64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.getelementptr inbounds|nuw %{{[a-zA-Z0-9_]+}}[%{{[a-zA-Z0-9_]+}}] : (!llvm.ptr, i64) -> !llvm.ptr, f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.load %{{[a-zA-Z0-9_]+}} : !llvm.ptr -> f64
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @printf(%{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}) vararg(!llvm.func<i32 (ptr, ...)>) : (!llvm.ptr, f64) -> i32
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.br ^bb9(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb11:  // pred: ^bb9
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.call @printf(%{{[a-zA-Z0-9_]+}}) vararg(!llvm.func<i32 (ptr, ...)>) : (!llvm.ptr) -> i32
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.add %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} : i64
// CHECK-NEXT:     llvm.br ^bb7(%{{[a-zA-Z0-9_]+}} : i64)
// CHECK-NEXT:   ^bb12:  // pred: ^bb7
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     llvm.call @free(%{{[a-zA-Z0-9_]+}}) : (!llvm.ptr) -> ()
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = llvm.extractvalue %{{[a-zA-Z0-9_]+}}[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
// CHECK-NEXT:     llvm.call @free(%{{[a-zA-Z0-9_]+}}) : (!llvm.ptr) -> ()
// CHECK-NEXT:     llvm.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
