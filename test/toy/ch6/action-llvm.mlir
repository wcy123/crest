// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: ; ModuleID = 'LLVMDialectModule'
// CHECK-NEXT: source_filename = "LLVMDialectModule"
// CHECK-EMPTY:
// CHECK-NEXT: declare !dbg !{{[0-9]+}} void @free(ptr)
// CHECK-EMPTY:
// CHECK-NEXT: declare !dbg !{{[0-9]+}} ptr @malloc(i64)
// CHECK-EMPTY:
// CHECK-NEXT: define void @main() !dbg !{{[0-9]+}} {
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, i64 6, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call ptr @malloc(i64 48), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 0, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 4, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 1, 4, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 1.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 2.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 3.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 4.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 4, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 5.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 5, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 6.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 1.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 2.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 3.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 4.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 4, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 5.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 5, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 6.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 1.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 2.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 3.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 4.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 4, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 5.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 5, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double 6.000000e+00, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 91:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 94:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 95:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 98:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = fmul double %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = fmul double %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = fmul double %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 125:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 127:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 128:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 131:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 132:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 135:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = fmul double %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 152:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 154:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [1 x i64], [1 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   ret void, !dbg !{{[0-9]+}}
// CHECK-NEXT: }
