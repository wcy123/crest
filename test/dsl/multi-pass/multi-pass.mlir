// Tests that multiple Scheme pass libraries can be chained in a single
// --crest-pass (passes=a,b) and across multiple --crest-pass flags separated
// by MLIR built-in passes.

// RUN: env CREST_PATH=%S \
// RUN:   %crest-opt %s \
// RUN:   --crest-pass="passes=passes/pass-a,passes/pass-b" \
// RUN:   --canonicalize \
// RUN:   --crest-pass="passes=passes/pass-c" \
// RUN:   | %FileCheck %s

// CHECK: pass-a: running
// CHECK: pass-b: running
// CHECK: pass-c: running

module {}
