// With --opt, LLVM's optimizing pipeline (O3) runs over the module (makeOptimizingTransformer). Every
// value in @main is a constant, so the buffers and the loops are gone, and what is left are the calls
// of printf with the six numbers of e and a putchar of a newline after each row. The attributes that
// LLVM puts on the declarations are not checked: they change with the version of LLVM.
//
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm --opt \
// RUN:   | FileCheck %s --implicit-check-not='call ptr @malloc' --implicit-check-not='br label'

// CHECK-LABEL: define void @main()
// CHECK:         @printf(ptr {{.*}}@frmt_spec, double 1.000000e+00)
// CHECK-NEXT:    @printf(ptr {{.*}}@frmt_spec, double 1.600000e+01)
// CHECK-NEXT:    @printf(ptr {{.*}}@frmt_spec, double 8.100000e+01)
// CHECK-NEXT:    @putchar(i32 10)
// CHECK-NEXT:    @printf(ptr {{.*}}@frmt_spec, double 2.560000e+02)
// CHECK-NEXT:    @printf(ptr {{.*}}@frmt_spec, double 6.250000e+02)
// CHECK-NEXT:    @printf(ptr {{.*}}@frmt_spec, double 1.296000e+03)
// CHECK-NEXT:    @putchar(i32 10)
// CHECK-NEXT:    ret void
