// The count of a lone optional operand is checked: 0 or 1 values; the required operand is still needed.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/oo-err \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=oo=passes/oo --split-input-file 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: {{.*}}optional operand 'second' must have 0 or 1 value
func.func @too_many(%a: i32) {
  "oo.maybe"(%a, %a, %a) : (i32, i32, i32) -> ()
  return
}

// -----

// CHECK: error: {{.*}}expected at least 1 operand(s)
func.func @none() {
  "oo.many"() : () -> ()
  return
}
