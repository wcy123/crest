// A pass that is made and added to a pass manager leaves no C++ memory behind: the pass manager
// owns the pass, and nothing else is allocated for the handle that Scheme held. Each run makes a
// pass manager and adds four passes (two directly, two to a nested pass manager) of four kinds,
// among them a pass made by define-pass, and the C++ heap must not grow.
//
// REQUIRES: system-linux
// It measures the heap of its own process, which valgrind's allocator changes:
// UNSUPPORTED: valgrind
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass-leak-scheme \
// RUN:   %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: pass-leak: ok

module {}
