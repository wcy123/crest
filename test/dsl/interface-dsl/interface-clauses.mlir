// Method clauses of :interfaces entries are what MLIR's call through the Concept reaches.
// An op that gives no clause for a method keeps the default (see interface-dsl.mlir).

// RUN: rm -rf %t/iface-scheme && mkdir -p %t/iface-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/iface-scheme \
// RUN:   %scheme-mlir %S/passes/interface-clauses.sls %s \
// RUN:   | %FileCheck %s

// CHECK: clause getFunctionType
// CHECK: getFunctionType: true
// CHECK: clause verifyBody
// CHECK: verifyBody: true
// CHECK: clause verifyType
// CHECK: verifyType: true
// CHECK: clause getCallableRegion
// CHECK: getCallableRegion: true
// CHECK: bad verifyBody: false
// CHECK: bad verifyType: false

module {
  "ifaceclauses.good"() ({
  }) {function_type = () -> (), sym_name = "good_fn"} : () -> ()
  "ifaceclauses.bad"() ({
  }) {function_type = () -> (), sym_name = "bad_fn"} : () -> ()
}
