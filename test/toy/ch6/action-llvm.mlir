// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm --opt \
// RUN:   | FileCheck %s

// CHECK:      declare{{.*}}void @free(ptr)
// CHECK:      declare{{.*}}ptr @malloc(i64)
// CHECK-LABEL: define void @main()
// CHECK:         call ptr @malloc
// CHECK:         insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] }
// CHECK:         call void @free(ptr
// CHECK:         ret void
