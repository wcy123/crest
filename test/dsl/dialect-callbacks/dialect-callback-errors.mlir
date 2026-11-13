// What the dialect says about the attributes that carry its name: a verifier that answers #f after
// emitting an error, and one that raises a Scheme error (the process must go on: the verifier
// fails, and the diagnostic has the text of the error, at the Scheme source of the verifier).
// The diagnostic of a raised error is not at a line of this file, so the output is checked with FileCheck.

// RUN: rm -rf %t/dialect-callback-errors-scheme && mkdir -p %t/dialect-callback-errors-scheme
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/dialect-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=dcbdep=passes/dcbdep --crest-scheme-dialect=dcb=passes/dcb 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: the attribute is not allowed
// CHECK: error: the argument attribute is not allowed
// CHECK: error: {{.*}}dcb.sls:{{[0-9]+}}:{{[0-9]+}}: verify-op-attr: the attribute is broken
// CHECK: error: attribute dcb.flag = 11 : i32 is too big
// CHECK: error: argument attribute dcb.flag = 12 : i32 is too big
// CHECK: error: result attribute dcb.flag = 13 : i32 is too big

"dcb.bad"() {dcb.flag = 1 : i32} : () -> ()

// -----

func.func @f(%a: i32, %b: i32, %c: i32 {dcb.flag = 1 : i32}) {
  return
}

// -----

"dcb.raises"() {dcb.flag = 1 : i32} : () -> ()

// -----

// The verifiers inspect the attribute they get: its name and its value.

"dcb.holder"() {dcb.flag = 11 : i32} : () -> ()

// -----

func.func @g(%a: i32 {dcb.flag = 12 : i32}) {
  return
}

// -----

func.func @h() -> (i32 {dcb.flag = 13 : i32}) {
  %0 = "dcb.make"() : () -> i32
  return %0 : i32
}
