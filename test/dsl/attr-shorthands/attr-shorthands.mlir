// The attribute shorthands in the manual's table, (name : val :string) and the others, work with
// only (crest) imported. Each shorthand keyword must be exported by (crest); a keyword that is not
// exported is not recognised, and the form falls through to a plain expression ("unbound
// identifier").
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/attr-shorthands" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.dst"() {
// CHECK-DAG:       a16 = array<i16: 3, 4>
// CHECK-DAG:       a32 = array<i32: 5, 6>
// CHECK-DAG:       a64 = array<i64: 7, 8>
// CHECK-DAG:       a8 = array<i8: 1, 2>
// CHECK-DAG:       f32 = 5.000000e-01 : f32
// CHECK-DAG:       f64 = 2.500000e-01 : f64
// CHECK-DAG:       i16 = 2 : i16
// CHECK-DAG:       i32 = 3 : i32
// CHECK-DAG:       i64 = 4 : i64
// CHECK-DAG:       i8 = 1 : i8
// CHECK-DAG:       ix = 7 : index
// CHECK-DAG:       s = "text"
// CHECK-DAG:       u}
// CHECK:         return
// CHECK-NOT:     test.src

func.func @f() {
  "test.src"() : () -> ()
  return
}
