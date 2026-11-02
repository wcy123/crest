// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm \
// RUN:   | %FileCheck %s

// CHECK: define void @main()
// CHECK: call ptr @malloc
// CHECK: call void @free
// CHECK: ret void
