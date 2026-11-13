// :fold that returns results. The folder returns #f (no fold) or one entry per result,
// (fold-value v) for an operand or (fold-attribute a) for a constant; the dialect's
// :materialize-constant turns an attribute into an op. The canonicalizer applies them:
//
//   fd.add %a, 0    --> %a         (a value, the second operand is a known constant)
//   fd.cast i64->i64 --> its operand
//   fd.seven         --> fd.const 7 (an attribute, materialized)
//   fd.cast i64->i32  kept          (the folder says no)
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/fold \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=fd=passes/fold-ops --canonicalize \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK-NOT:     "fd.add"
// CHECK-NOT:     "fd.seven"
// CHECK:         %[[C7:.*]] = "fd.const"() {value = 7 : i64} : () -> i64
// CHECK:         %[[K:.*]] = "fd.cast"(%arg0) : (i64) -> i32
// CHECK-NEXT:    return %arg0, %[[C7]], %[[K]]

func.func @f(%a: i64) -> (i64, i64, i32) {
  %c0 = "fd.const"() {value = 0 : i64} : () -> i64
  %0 = "fd.add"(%a, %c0) : (i64, i64) -> i64
  %1 = "fd.cast"(%0) : (i64) -> i64
  %2 = "fd.seven"() : () -> i64
  %3 = "fd.cast"(%a) : (i64) -> i32
  return %1, %2, %3 : i64, i64, i32
}
