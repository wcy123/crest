// An inferReturnTypes clause that answers #f fails: the diagnostic says "cannot infer the result types of
// bad.op". (The clauses of an interface are called by MLIR itself, so they must not raise.)
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=bad=passes/bad-dialect passes=passes/use-bad" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: {{.*}}cannot infer the result types of bad.op

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
