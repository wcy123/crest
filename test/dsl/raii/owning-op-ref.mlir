// with-mlir::OwningOpRef of (mlir IR OwningOpRef) parses a file and erases the module when its body
// ends. The tests show that the body gets the module, that a file that cannot be parsed gives 0 (and
// erasing it does nothing), and that an error and an escape in the body do not break it. That the
// memory is freed is measured in the valgrind run of the pull request that added the macro, and by
// the leak drivers of test/dsl/callback-leaks, which use it.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/owning-op-ref-scheme %scheme-mlir %S/owning-op-ref-driver.sls %s 2>&1 | %FileCheck %s

// CHECK:      builtin.module
// CHECK:      no module
// CHECK-NEXT: caught
// CHECK-NEXT: end

module {
}
