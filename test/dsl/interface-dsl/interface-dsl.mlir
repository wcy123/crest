// Tests the :interfaces DSL end-to-end.
// Uses an isolated scheme binary dir to avoid stale cache issues.

// RUN: rm -rf %t/iface-scheme && mkdir -p %t/iface-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/iface-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/interface-dsl dialects=ifacetest" %s \
// RUN:   | %FileCheck %s

// CHECK: dispatcher-op-name: ifacetest.func
// CHECK: dispatcher-getFunctionType: #f
// CHECK: dispatcher-verifyBody: #f
// CHECK: getFunctionType: #t
// CHECK: verifyBody: #t
// CHECK: verifyType: #t
// CHECK: getCallableRegion: non-null
// CHECK: getNameAttr: non-null
// CHECK: module

module {
  "ifacetest.func"() ({
  }) {function_type = () -> (), sym_name = "test_fn"} : () -> ()
}
