// A Scheme dialect whose hooks raise errors must leave nothing behind: a verifier that raises, and an
// :initialize that raises, are diagnostics (the callable answers (who . why), C++ reports it), and the C++
// heap does not grow however many errors there are.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/hook-errors-leak-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s

// CHECK: hook-errors-leak: ok

"hkv.raises"() {hkv.flag = 1 : i32} : () -> ()
