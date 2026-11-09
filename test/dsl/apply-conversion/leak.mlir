// The C functions that a conversion makes for its callbacks are released when the pattern set, the
// target and the type converter that call them are destroyed: running the conversion many times
// does not leave code objects behind.
//
// RUN: rm -rf %t/apply-conversion-leak-scheme && mkdir -p %t/apply-conversion-leak-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/apply-conversion-leak-scheme \
// RUN:   %scheme-mlir %S/leak-driver.sls %s | %FileCheck %s

// CHECK: released

module {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  "test.c"() : () -> ()
  "test.keep"() : () -> ()
}
