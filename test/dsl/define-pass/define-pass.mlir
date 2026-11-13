// define-pass: a pass written in Scheme, added to a PassManager like any other.
// A pass nested on func.func runs on each function, a pass on the module runs once, and a pass whose
// body returns #f fails the pipeline (the diagnostic it emitted is reported).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass \
// RUN:   %scheme-mlir %S/driver.sls %s ok | FileCheck %s
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass2 \
// RUN:   %scheme-mlir %S/driver.sls %s fail 2>&1 | FileCheck %s --check-prefix=FAIL

// CHECK: func.func @a() attributes {tagged = "yes"}
// CHECK: func.func @b() attributes {tagged = "yes"}
// CHECK: passes ran: 1

// FAIL: error: pass always-fail: this module is not accepted
// FAIL: pipeline failed

func.func @a() {
  return
}

func.func @b() {
  return
}
