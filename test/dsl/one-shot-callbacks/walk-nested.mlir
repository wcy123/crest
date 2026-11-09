// The callback of walk runs for each op, and may walk again. The module has five ops (the module,
// the function, and the three in it): the outer walk visits each once, and the inner walks visit the
// ops under each of them: 1 + 1 + 1 + 4 + 5.
//
// RUN: rm -rf %t/walk-nested-scheme && mkdir -p %t/walk-nested-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/walk-nested-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --crest-pass="passes=passes/walk-nested" %s \
// RUN:   | %FileCheck %s

// CHECK: module attributes {test.inner = 12 : i64, test.outer = 5 : i64}

func.func @f() {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  return
}
