// A pattern that changes its op through modifyOpInPlace: the driver sees the change, and stops once
// the pattern no longer matches.
//
// RUN: rm -rf %t/modify-in-place-scheme && mkdir -p %t/modify-in-place-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/modify-in-place-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --crest-pass="passes=passes/modify-in-place" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.mark"() {marked} : () -> ()
// CHECK: "test.keep"() : () -> ()

func.func @f() {
  "test.mark"() : () -> ()
  "test.keep"() : () -> ()
  return
}
