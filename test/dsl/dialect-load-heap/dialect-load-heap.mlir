// Loading a Scheme dialect (ops, a type, interfaces, an inliner) into a context and freeing the context must give
// the C++ heap back: nothing that the dialect registers may outlive its context. A global map from (context,
// dialect, name) to the definition of a type was kept in lib/Crest/Type.cpp, and its entries were never removed, so
// the heap grew with every context that loaded a dialect.
//
// REQUIRES: system-linux
// It measures the heap of the process, which valgrind's allocator changes:
// UNSUPPORTED: valgrind
// RUN: env CREST_PATH=%S/../callback-leaks CREST_SCHEME_BINARY_DIR=%t/dialect-heap-scheme \
// RUN:   %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: dialect-load-heap: ok

module {}
