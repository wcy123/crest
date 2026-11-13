// A dialect type defined in Scheme: define-type with :parse, :print and :verify, backed by
// DynamicTypeDefinition. It prints as `!dt.pair<i32, f32>`, parses back, is verified, and an op can
// ask for it in :results.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/types \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=dt=passes/type-dialect | %FileCheck %s

// CHECK: func.func @f(%arg0: i32, %arg1: f32) -> !dt.pair<i32, f32>
// CHECK: %[[P:.*]] = "dt.make"(%arg0, %arg1) : (i32, f32) -> !dt.pair<i32, f32>

func.func @f(%a: i32, %b: f32) -> !dt.pair<i32, f32> {
  %0 = "dt.make"(%a, %b) : (i32, f32) -> !dt.pair<i32, f32>
  return %0 : !dt.pair<i32, f32>
}
