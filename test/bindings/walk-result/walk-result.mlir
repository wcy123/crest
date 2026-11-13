// The visitor of mlir::Operation::walk has the C++ prototype WalkResult(Operation*), and Scheme has the constants of
// the enum (mlir Support WalkResult): interrupt is 0, advance is 1, skip is 2. `walk` answers the WalkResult of the
// walk: interrupt when the visitor stopped it, advance otherwise. Interrupt stops the walk; skip and advance go on
// (the walk is post-order, so the nested ops of an op are visited before it, and skipping it skips nothing).
//
// RUN: %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: constants: 0 1 2
// CHECK-NEXT: advance: visited 6, answer is advance #t
// CHECK-NEXT: interrupt: visited 1, answer is interrupt #t
// CHECK-NEXT: skip: visited 6, answer is advance #t

func.func @f() {
  "test.a"() ({
    "test.inner"() : () -> ()
  }) : () -> ()
  "test.b"() : () -> ()
  return
}
