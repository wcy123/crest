// An inferReturnTypes clause that raises an error: MLIR calls it through a plain function pointer, and C++
// calls the procedure itself, so the error must not cross either (Rule 17). It is a diagnostic at the Scheme
// source of the clause, the inference fails ("cannot infer the result types of badr.op"), and the program goes on.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme-raises \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=badr=passes/bad-raises-dialect passes=passes/use-bad-raises" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: {{.*}}bad-raises-dialect.sls:{{[0-9]+}}:{{[0-9]+}}: inferReturnTypes: the clause is broken
// CHECK: cannot infer the result types of badr.op

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
