// REGRESSION: an op that implements InferTypeOpInterface was not checked against it. bld.add infers the
// type of its left operand (i32); an op that says i64 was accepted. A C++ op with the interface is
// rejected ("inferred type(s) ... are incompatible with return type(s) of operation ...") and so is this.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bld=passes/bld-dialect 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: 'bld.add' op inferred type(s) 'i32' are incompatible with return type(s) of operation 'i64'

func.func @f(%a: i32, %b: i32) {
  %0 = "bld.add"(%a, %b) : (i32, i32) -> i64
  return
}
