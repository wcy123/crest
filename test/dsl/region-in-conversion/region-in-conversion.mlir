// Ops created in a region body by begin-mlir-code inside a conversion pattern must be
// reported to the dialect-conversion driver, so that other patterns legalize them.
//
//   test.src   -->  test.wrapper { test.inner }   (region body built by the DSL)
//   test.inner -->  test.done                      (must fire on the body op as well)
//
// If the block builder had no listener, test.inner would be left in the output.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/region-in-conversion" %s \
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
