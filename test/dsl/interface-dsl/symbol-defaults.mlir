// An op that gives no clause for SymbolOpInterface gets what MLIR does by default: the name is the
// "sym_name" attribute, the visibility the "sym_visibility" attribute (public when it is absent),
// the use queries are those of SymbolTable. A clause overrides one method.

// RUN: rm -rf %t/symdefaults-scheme && mkdir -p %t/symdefaults-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/symdefaults-scheme \
// RUN:   %scheme-mlir %S/passes/symbol-defaults.sls %s \
// RUN:   | %FileCheck %s

// CHECK: a: public nested=no private=no public=yes discard=no declaration=no optional=no
// CHECK: b: private nested=no private=yes public=no discard=yes declaration=no optional=no
// CHECK: c: nested nested=yes private=no public=no discard=yes declaration=no optional=no
// CHECK: d: public nested=no private=no public=yes discard=no declaration=yes optional=yes
// CHECK: after setPrivate: private attribute=yes
// CHECK: after setPublic: public attribute=no
// CHECK: after setNested: nested
// CHECK: after setVisibility 1: private
// CHECK: after setName: renamed
// CHECK: no uses in the module: yes
// CHECK: rename succeeds: yes

module {
  "symdefaults.sym"() {sym_name = "a"} : () -> ()
  "symdefaults.sym"() {sym_name = "b", sym_visibility = "private"} : () -> ()
  "symdefaults.sym"() {sym_name = "c", sym_visibility = "nested"} : () -> ()
  "symdefaults.overriding"() {sym_name = "d"} : () -> ()
}
