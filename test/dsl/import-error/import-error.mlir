// When a pass library fails to import, the diagnostic says why: the Scheme error with
// its source line and column for a library that fails to expand, or "not found" for a
// library that does not exist.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/broken" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=BROKEN
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/does-not-exist" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=MISSING

// BROKEN: error: Failed to import Scheme library: passes/broken: Exception: attempt to reference unbound identifier this-name-is-not-bound at line 9, char 6 of {{.*}}broken.sls
// MISSING: error: Failed to import Scheme library: passes/does-not-exist: Exception: library (passes does-not-exist) not found

module {}
