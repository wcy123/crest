// An error in a callback is a diagnostic, reported where it happens, and the callable answers the failure value of
// the C++ result type; the C++ prototype of the callable is the one MLIR declares (plan 05).
//   - the diagnostic is at the Scheme source of the callback (driver.sls), made in (current-MLIRContext);
//   - a walk visitor answers a WalkResult; on an error the answer is `interrupt`, which stops the walk; the walk
//     answers it to Scheme as a number and raises nothing;
//   - a visitor that runs a walk of its own (C++ -> Scheme -> C++ -> Scheme): each failure is reported where it
//     happens, and the outer walk goes on;
//   - a callback whose C++ result is void has no place for an error: the process ends with the text;
//   - with no current context there is no place for a location: the process ends with the text;
//   - the current context that a dialect load sets goes with the context of the dialect.
//
// RUN: %scheme-mlir %S/driver.sls %s walk 2>/dev/null | %FileCheck %s --check-prefix=WALK
// RUN: %scheme-mlir %S/driver.sls %s walk 2>&1 >/dev/null | %FileCheck %s --check-prefix=WALK-DIAG
// RUN: %scheme-mlir %S/driver.sls %s nested 2>/dev/null | %FileCheck %s --check-prefix=NESTED
// RUN: %scheme-mlir %S/driver.sls %s nested 2>&1 >/dev/null | %FileCheck %s --check-prefix=NESTED-DIAG
// RUN: not %scheme-mlir %S/driver.sls %s no-context 2>&1 | %FileCheck %s --check-prefix=NO-CONTEXT
// RUN: env CREST_PATH=%S/../callback-errors CREST_SCHEME_BINARY_DIR=%t/callback-diagnostics-scheme \
// RUN:   not %scheme-mlir %S/fatal-driver.sls %s 2>&1 | %FileCheck %s --check-prefix=FATAL
// RUN: env CREST_PATH=%S/../hook-errors-leak CREST_SCHEME_BINARY_DIR=%t/callback-diagnostics-stale \
// RUN:   %scheme-mlir %S/stale-driver.sls 2>&1 | %FileCheck %s --check-prefix=STALE

// The walk is post-order: "test.a" is visited first, then "test.b", where the visitor raises.
// WALK: visited: 2
// WALK-NEXT: interrupted: #t
// WALK-DIAG: error: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: boom

// NESTED: inner interrupted: #t
// NESTED-NEXT: outer interrupted: #f
// NESTED-DIAG: error: {{.*}}driver.sls:{{[0-9]+}}:{{[0-9]+}}: callback: boom

// NO-CONTEXT: LLVM ERROR: {{.*}}callback: boom
// NO-CONTEXT-NOT: visited

// FATAL: LLVM ERROR: {{.*}}callback: boom
// FATAL-NOT: not reached

// A dialect load sets current-MLIRContext, and the parameter is #f again when the context is gone (it holds a bare pointer).
// STALE: before the load: #f
// STALE-NEXT: after the load: a context
// STALE-NEXT: after the context: #f

func.func @f() {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  "test.rw"() : () -> ()
  return
}
