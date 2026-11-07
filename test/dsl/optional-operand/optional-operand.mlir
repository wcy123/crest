// A lone optional or variadic operand takes the operands the required ones leave, as in MLIR (an
// operandSegmentSizes attribute is only needed for two or more of them).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/oo \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=oo=passes/oo | %FileCheck %s

// CHECK-LABEL: func.func @ok
// CHECK: "oo.maybe"(%arg0) : (i32) -> ()
// CHECK: "oo.maybe"(%arg0, %arg0) : (i32, i32) -> ()
// CHECK: "oo.many"(%arg0) : (i32) -> ()
// CHECK: "oo.many"(%arg0, %arg0, %arg0) : (i32, i32, i32) -> ()
func.func @ok(%a: i32) {
  "oo.maybe"(%a) : (i32) -> ()
  "oo.maybe"(%a, %a) : (i32, i32) -> ()
  "oo.many"(%a) : (i32) -> ()
  "oo.many"(%a, %a, %a) : (i32, i32, i32) -> ()
  return
}
