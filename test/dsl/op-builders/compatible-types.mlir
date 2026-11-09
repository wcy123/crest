// An op that implements InferTypeOpInterface says what result types fit its inference with
// isCompatibleReturnTypes, as an ODS op of C++ that overrides it does. bld.loose infers the type of its
// operand (i32) and accepts any single result type, so i64 verifies, where bld.add (no clause: the types
// must be equal) is rejected (inferred-type-mismatch.mlir).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bld=passes/bld-dialect | %FileCheck %s

// CHECK: %{{.*}} = "bld.loose"(%arg0) : (i32) -> i64

func.func @f(%a: i32) {
  %0 = "bld.loose"(%a) : (i32) -> i64
  return
}
