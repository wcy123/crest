// A Scheme dialect whose hooks raise errors must leave nothing behind: a verifier that raises is a diagnostic
// at its Scheme source (the callable reports it and answers 0), and the C++ heap does not grow however many
// errors there are.
//
// REQUIRES: system-linux
// It measures the heap of its own process, which valgrind's allocator changes:
// UNSUPPORTED: valgrind
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/hook-errors-leak-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s

// CHECK: hook-errors-leak: ok

"hkv.raises"() {hkv.flag = 1 : i32} : () -> ()
