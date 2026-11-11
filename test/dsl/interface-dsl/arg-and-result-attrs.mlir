// The standard clauses of ArgAndResultAttrsOpInterface keep the attributes in "arg_attrs" and
// "res_attrs": get answers the attribute or null, remove takes it away and answers it, set puts it back.

// RUN: rm -rf %t/aarattrs-scheme && mkdir -p %t/aarattrs-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/aarattrs-scheme \
// RUN:   %scheme-mlir %S/passes/arg-and-result-attrs.sls %s \
// RUN:   | %FileCheck %s

// CHECK: argument attributes: present
// CHECK: result attributes: present
// CHECK: removed the same: yes
// CHECK: after remove: none
// CHECK: after set: same
// CHECK: op without: none

module {
  "aarattrs.fn"() {arg_attrs = [{a = 1 : i32}], res_attrs = [{b = 2 : i32}]} : () -> ()
  "aarattrs.fn"() : () -> ()
}
