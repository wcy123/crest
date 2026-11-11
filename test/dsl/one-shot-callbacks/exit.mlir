// The maker of the prototype of a per-run callback is a static member that is unlocked when the process
// ends. That must be safe when the program ends normally and when it ends through (exit n), which runs
// the static destructors after Scheme's own exit.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/exit-scheme %scheme-mlir %S/exit-driver.sls %s end | %FileCheck %s
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/exit-scheme %scheme-mlir %S/exit-driver.sls %s exit > %t.exit.txt
// RUN: %FileCheck %s --input-file=%t.exit.txt

// CHECK: walked

module {
}
