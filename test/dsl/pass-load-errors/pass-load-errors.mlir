// REGRESSION: a --crest-pass=passes= library that does not export run-pass crashed crest-opt.
//
// The pass imports its libraries and then calls run-pass without checking that the name is bound, so a
// library that has none (a typo in the name of the library, a library of a dialect, one made with
// define-pass) ended in a segmentation fault: the LLVM crash banner ("PLEASE submit a bug report") and a
// bare `Exception: invalid memory reference` that does not even name the library.
//
// Now: an error that names the library and says what it lacks, and exit status 1, as for a library
// that fails to import (test/dsl/import-error) or a dialect library that does not load
// (test/dsl/dialect-load-errors).
//
// XFAIL: *
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/no-run-pass" 2>&1 \
// RUN:   | %FileCheck %s --implicit-check-not='PLEASE submit a bug report' --implicit-check-not='invalid memory reference'

// CHECK: error: {{.*}}passes/no-run-pass{{.*}}run-pass

module {}
