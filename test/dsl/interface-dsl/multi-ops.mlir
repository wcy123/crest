// Several ops of one dialect have clauses for the same methods: each op answers with its own
// clause, and an op without one keeps the default.

// RUN: rm -rf %t/multi-ops-scheme && mkdir -p %t/multi-ops-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/multi-ops-scheme \
// RUN:   %scheme-mlir %S/passes/multi-ops.sls %s \
// RUN:   | %FileCheck %s

// CHECK: first: region 0
// CHECK: second: region 1
// CHECK: third: region 2
// CHECK: plain: region 0
// CHECK: fn-a type: (i32) -> i32
// CHECK: fn-b type: (i64) -> i64
// CHECK: fn-c type: (f16) -> f16
// CHECK: fn-a verifyBody: true
// CHECK: fn-b verifyBody: false
// CHECK: fn-c verifyBody: true
// CHECK: fn-a set: set_by_a=true set_by_b=false
// CHECK: fn-b set: set_by_a=false set_by_b=true

module {
  "multiops.first"() ({ }, { }, { }) : () -> ()
  "multiops.second"() ({ }, { }, { }) : () -> ()
  "multiops.third"() ({ }, { }, { }) : () -> ()
  "multiops.plain"() ({ }, { }, { }) : () -> ()
  "multiops.fn-a"() ({ }) {function_type = (f16) -> f16, sym_name = "a"} : () -> ()
  "multiops.fn-b"() ({ }) {function_type = (f16) -> f16, sym_name = "b"} : () -> ()
  "multiops.fn-c"() ({ }) {function_type = (f16) -> f16, sym_name = "c"} : () -> ()
}
