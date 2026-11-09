// A define-pass is made into a pass every time it is called: the same one in several pipelines, and
// twice in one, runs each time. A body that raises a Scheme error does not end the process: the pass
// fails and the diagnostic has the text of the error.
//
// RUN: rm -rf %t/define-pass-reuse-scheme %t/define-pass-raise-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/define-pass-reuse-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s reuse | FileCheck %s
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/define-pass-raise-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s raise 2>&1 | FileCheck %s --check-prefix=RAISE

// CHECK: passes ran: 3

// RAISE: this pass is broken
// RAISE: pipeline failed

func.func @a() {
  return
}
