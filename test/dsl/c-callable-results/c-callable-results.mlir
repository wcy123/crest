// A callable has the C prototype that C++ declares, result type included (plan 05). An error of the procedure is a
// diagnostic at the Scheme source of the callback, and the callable answers the failure value of its type; a void
// callable has no place for an error: the process ends with the text, also when there is no current context to make
// the location in.
//
// RUN: %scheme-mlir %S/driver.sls values | %FileCheck %s --check-prefix=VALUES
// RUN: %scheme-mlir %S/driver.sls failure-values 2>/dev/null | %FileCheck %s --check-prefix=FAILURE
// RUN: %scheme-mlir %S/driver.sls failure-values 2>&1 >/dev/null | %FileCheck %s --check-prefix=DIAG
// RUN: not %scheme-mlir %S/driver.sls void 2>&1 | %FileCheck %s --check-prefix=VOID
// RUN: not %scheme-mlir %S/driver.sls no-context 2>&1 | %FileCheck %s --check-prefix=VOID

// VALUES: int: 42
// VALUES-NEXT: unsigned-8: 1
// VALUES-NEXT: uptr: 4096
// VALUES-NEXT: static int: 42

// FAILURE: int: 0
// FAILURE-NEXT: unsigned-8: 0
// FAILURE-NEXT: uptr: 0

// DIAG: error: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: int failed
// DIAG: error: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: unsigned-8 failed
// DIAG: error: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: uptr failed

// VOID: LLVM ERROR: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: void failed
// VOID-NOT: not reached

module {}
