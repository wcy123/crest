// A dialect that asks for a dialect that is not registered ends the process (MLIR gives the dialect
// no way to fail), with the text of the error at the Scheme source of the clause, as every
// callback of Scheme does, and with a clean exit, not an abort.
//
// RUN: rm -rf %t/missing-dependent-scheme && mkdir -p %t/missing-dependent-scheme
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/missing-dependent-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=missingdep=passes/missingdep 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: missingdep.sls:{{[0-9]+}}:{{[0-9]+}}: {{.*}}nonexistentdialect

module {
  "missingdep.thing"() : () -> ()
}
