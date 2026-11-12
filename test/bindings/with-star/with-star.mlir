// with* is let* for with- forms: (with* ((with-X var (args ...)) ...) body ...) is the same as the nested forms.
//
// RUN: %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: order: ((body ((a b) c)) (free ((a b) c)) (free (a b)) (free a))
// CHECK-NEXT: error: ((free 2) (free 1) caught)
// CHECK-NEXT: 42
// CHECK-NEXT: 20
// CHECK-NEXT: context: made

module {}
