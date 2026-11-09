// An error raised by a Scheme inferReturnTypes is part of the diagnostic: the callable used to print it
// on its own line of stderr, and the diagnostic said only "cannot infer the result types of bad.op".
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=bad=passes/bad-dialect passes=passes/use-bad" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: {{.*}}cannot infer the result types of bad.op{{.*}}boom

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
