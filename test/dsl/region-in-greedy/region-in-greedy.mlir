// Same scenario as region-in-conversion, for the greedy rewrite driver. Ops created in a
// region body by begin-mlir-code are reported to the driver through the builder's listener.
//
// Unlike the conversion driver, the greedy driver rescans the whole IR on every iteration, so
// it would also rewrite test.inner without the listener: this test guards the listener path
// under the greedy driver (no crash, same result); region-in-conversion guards the bug.
//
//   test.src   -->  test.wrapper { test.inner }   (region body built by the DSL)
//   test.inner -->  test.done                      (must fire on the body op as well)
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/region-in-greedy" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.wrapper"() ({
// CHECK-NEXT:      "test.done"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
// CHECK-NOT:     test.inner
// CHECK-NOT:     test.src

func.func @f() {
  "test.src"() : () -> ()
  return
}
