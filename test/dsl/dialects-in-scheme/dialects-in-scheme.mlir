// Tests that dialects-in-scheme= imports a Scheme library and calls its
// register-dialects function in initialize(), before runOnOperation().
// If initialize() fails (register-dialects returns #f or the import fails),
// the pipeline errors and this test fails. The CHECK line proves both
// initialize() and run-pass succeeded.

// RUN: env CREST_PATH=%S \
// RUN:   %crest-opt %s \
// RUN:   --crest-pass="dialects-in-scheme=passes/test-dialect \
// RUN:                 passes=passes/dialects-in-scheme" \
// RUN:   | %FileCheck %s

// CHECK: dialect-loaded: testd

module {}
