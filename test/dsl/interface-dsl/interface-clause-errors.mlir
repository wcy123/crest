// A clause of :interface2 that raises a Scheme error must not end the process: the verifier
// answers failure and the diagnostic carries the text of the error.

// RUN: rm -rf %t/iface-clause-errors-scheme && mkdir -p %t/iface-clause-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/iface-clause-errors-scheme \
// RUN:   %scheme-mlir %S/passes/interface-clause-errors.sls %s \
// RUN:   > %t/iface-clause-errors-out.txt 2> %t/iface-clause-errors-err.txt
// RUN: %FileCheck %s --input-file=%t/iface-clause-errors-out.txt
// RUN: %FileCheck %s --check-prefix=ERR --input-file=%t/iface-clause-errors-err.txt

// CHECK: raises verifyBody: false
// CHECK: raises verifyType: false
// CHECK: still running

// ERR: error: 'ifaceclauses.raises' op {{.*}}the body is broken
// ERR: error: 'ifaceclauses.raises' op {{.*}}the type is broken

module {
  "ifaceclauses.raises"() ({
  }) {function_type = () -> (), sym_name = "raising_fn"} : () -> ()
}
