// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm \
// RUN:   | FileCheck %s

// CHECK-LABEL: ; ModuleID = 'LLVMDialectModule'
// CHECK-NEXT: source_filename = "LLVMDialectModule"
// CHECK-NEXT: target datalayout = "{{.*}}"
// CHECK-NEXT: target triple = "{{.*}}"
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
// CHECK-NEXT: 155:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 158:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 159:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 162:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 173:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 175:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 176:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 179:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 180:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 183:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 194:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 196:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 197:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 200:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 201:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 204:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
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
// CHECK-NEXT: 221:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 223:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 224:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 227:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 228:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 231:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 242:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 244:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 245:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 248:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 249:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 252:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 263:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 265:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 266:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 269:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 270:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 273:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
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
// CHECK-NEXT: 290:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 292:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 293:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 296:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 297:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 300:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 311:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 313:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 314:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 317:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 318:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 321:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 332:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 334:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 335:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 338:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 339:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 342:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
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
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = mul nuw nsw i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add nuw nsw i64 %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = getelementptr inbounds nuw double, ptr %{{[a-zA-Z0-9_]+}}, i64 %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-NEXT:   store double %{{[a-zA-Z0-9_]+}}, ptr %{{[a-zA-Z0-9_]+}}, align 8, !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 359:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 361:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 362:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 365:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 366:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 369:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 380:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 382:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 383:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 386:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 387:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 390:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 401:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 403:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 404:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 3, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 407:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 408:                                              ; preds = %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = phi i64 [ 0, %{{[a-zA-Z0-9_]+}} ], [ %{{[a-zA-Z0-9_]+}}, %{{[a-zA-Z0-9_]+}} ], !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = icmp slt i64 %{{[a-zA-Z0-9_]+}}, 2, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br i1 %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 411:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT: 428:                                              ; preds = %{{[a-zA-Z0-9_]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = add i64 %{{[a-zA-Z0-9_]+}}, 1, !dbg !{{[0-9]+}}
// CHECK-NEXT:   br label %{{[a-zA-Z0-9_]+}}, !dbg !{{[0-9]+}}
// CHECK-EMPTY:
// CHECK-NEXT: 430:                                              ; preds = %{{[a-zA-Z0-9_]+}}
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
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   %{{[a-zA-Z0-9_]+}} = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %{{[a-zA-Z0-9_]+}}, 0, !dbg !{{[0-9]+}}
// CHECK-NEXT:   call void @free(ptr %{{[a-zA-Z0-9_]+}}), !dbg !{{[0-9]+}}
// CHECK-NEXT:   ret void, !dbg !{{[0-9]+}}
// CHECK-NEXT: }
