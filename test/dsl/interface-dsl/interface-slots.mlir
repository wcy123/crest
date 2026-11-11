// A method clause of an :interfaces entry answers what MLIR's Concept asks for: the clause gets the
// op (not the Concept), and what it answers is what the caller gets. setFunctionTypeAttr reaches the
// clause of each op: one that announces itself, and one that only stores the attribute.

// RUN: rm -rf %t/iface-slots-scheme && mkdir -p %t/iface-slots-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/iface-slots-scheme \
// RUN:   %scheme-mlir %S/passes/interface-slots.sls %s \
// RUN:   | %FileCheck %s

// CHECK: clause getCallableRegion
// CHECK-NEXT: callable region is region 0: true
// CHECK: clause getFunctionType
// CHECK-NEXT: function type: () -> ()
// CHECK: clause setFunctionTypeAttr
// CHECK-NEXT: type after set (clause): (i32) -> i64
// CHECK-NEXT: type after set (plain): (i32) -> i64

module {
  "ifaceclauses.good"() ({
  }) {function_type = () -> (), sym_name = "good_fn"} : () -> ()
  "ifaceclauses.settable"() ({
  }) {function_type = () -> (), sym_name = "settable_fn"} : () -> ()
  "ifaceclauses.bad"() ({
  }) {function_type = () -> (), sym_name = "bad_fn"} : () -> ()
}
