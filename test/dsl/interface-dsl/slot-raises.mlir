// A clause of an interface of a Scheme op that raises an error (plan 05): MLIR calls the slot with its own
// prototype, so the callable of the slot reports the error as a diagnostic at the Scheme source of the clause and
// answers the zero of its result kind: an empty range for getArgumentTypes, a null region for getCallableRegion.
//
// RUN: rm -rf %t/slot-raises-scheme && mkdir -p %t/slot-raises-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/slot-raises-scheme \
// RUN:   %scheme-mlir %S/passes/slot-raises.sls %s 2>&1 | %FileCheck %s

// CHECK: error: {{.*}}slotraises.sls:{{[0-9]+}}:{{[0-9]+}}: getArgumentTypes: the arguments clause is broken
// CHECK: arguments: ()
// CHECK: error: {{.*}}slotraises.sls:{{[0-9]+}}:{{[0-9]+}}: getCallableRegion: the region clause is broken
// CHECK: region is null: #t

module {
  "slotraises.op"() ({ }) : () -> ()
}
