// What the guard of a callable needs to report an error (plan 05): mlir::FileLineColLoc::get makes a location from a
// Scheme source position, and mlir::emitError reports at it; llvm::report_fatal_error ends the process with a text
// (exit 1, no abort).
//
// RUN: %scheme-mlir %S/driver.sls locations 2>&1 | %FileCheck %s --check-prefix=ERR
// RUN: not %scheme-mlir %S/driver.sls fatal 2>&1 | %FileCheck %s --check-prefix=FATAL

// ERR: scheme-source.sls":12:5): error: reported at a Scheme position
// FATAL: LLVM ERROR: the callback failed
// FATAL-NOT: not reached

module {}
