// An op that does not implement mlir::InferTypeOpInterface cannot be created without `-> type`: the
// error names the op and says what to do, instead of the op getting no result and the first use of
// its result failing somewhere else. The failed rewrite is reported as an error and the pass leaves
// the op alone.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s -allow-unregistered-dialect --mlir-disable-threading \
// RUN:   --crest-pass="dialects-in-scheme=bld=passes/bld-dialect passes=passes/use-plain" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: Exception in begin-mlir-code: no result type for bld.plain
// CHECK-SAME: does not implement mlir::InferTypeOpInterface; write -> type

func.func @f(%a: i32, %b: i32) {
  "test.src"(%a, %b) : (i32, i32) -> ()
  return
}
