// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm \
// RUN:   | FileCheck %s

// CHECK-LABEL: ; ModuleID = 'LLVMDialectModule'
// CHECK-NEXT: source_filename = "LLVMDialectModule"
// CHECK-NEXT: target datalayout = "{{.*}}"
// CHECK-NEXT: target triple = "{{.*}}"
// CHECK-EMPTY:
// CHECK-NEXT: @nl = internal constant [2 x i8] c"\0A\00"
// CHECK-NEXT: @frmt_spec = internal constant [4 x i8] c"%{{[a-zA-Z0-9_]+}} \00"
// CHECK-EMPTY:
// CHECK-NEXT: declare !dbg !{{[0-9]+}} void @free(ptr)
// CHECK-EMPTY:
// CHECK-NEXT: declare !dbg !{{[0-9]+}} i32 @printf(ptr, ...)
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
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 2, 3, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 3, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, i64 3, 4, 0, !dbg !{{[0-9]+}}
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
// CHECK-NEXT: 53:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 56:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 57:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 60:                                               ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 71:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 73:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 74:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 77:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 78:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 81:                                               ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 93:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 95:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 96:                                               ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 99:                                               ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 100:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 103:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 114:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 116:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 117:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 120:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 121:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 124:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
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
// CHECK-NEXT: 141:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 143:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 144:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 147:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 148:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 151:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = load double, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call i32 (ptr, ...) @printf(ptr @frmt_spec, double %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 159:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = call i32 (ptr, ...) @printf(ptr @nl), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 162:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
