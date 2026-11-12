// A binding that fails must leave no C++ memory behind (plans/04-errors-are-values.md). It answers an error
// object and Scheme raises it after the C++ call has returned, so no C++ destructor is skipped (a name of
// 15 characters or less needs no heap, a longer one does: both must be free) and nothing is kept for an
// escaped call. The same holds for a block that Region::push_back<Block> could make before it fails: it
// must be given to the region or never made.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/error-path-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: error-path-leak: ok
// CHECK-NEXT: block-leak: ok

"a.b"() : () -> ()
"test.a_long_operation_name_that_needs_the_heap"() : () -> ()
