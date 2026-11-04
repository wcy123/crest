// with-CrestObject returns the body's value on a normal return and lets an
// error propagate to a guard outside the form.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/with-crestobject" \
// RUN:   | %FileCheck %s

// CHECK: normal
// CHECK-NEXT: guard-caught

module {}
