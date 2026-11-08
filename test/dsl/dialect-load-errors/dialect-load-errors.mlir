// REGRESSION: a Scheme dialect library that cannot be loaded aborts the process.
//
// Today: `LLVM ERROR: CrestDialect: failed to import Scheme library ...`, the LLVM crash banner
// ("PLEASE submit a bug report") and a core dump (exit 134), or, when the import itself "succeeds" but
// leaves no callbacks vector (an error in the library body, a dialect that is not exported, a name bound to
// something else), a bare `Error: invalid memory reference` that does not even name the library.
// Cause: CrestDialect's constructor (lib/Crest/Dialect.cpp) imports the library the first time a dialect op
// is parsed, cannot return a failure, and reads the callbacks vector without checking it.
//
// Wanted: the same as a pass library that fails to import (test/dsl/import-error): a diagnostic
// `error: Failed to import Scheme library: <library>: <reason>` and exit status 1, whichever way the
// dialect is named (--crest-scheme-dialect, dialects-in-scheme=). The CHECK-NOT lines catch the abort.
//
// XFAIL: *
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/macro-error 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,MACRO
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/unbound 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,UNBOUND
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/does-not-exist 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,MISSING
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/body-error 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,BODY
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/not-exported 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,NOTEXPORTED
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=bad=passes/not-a-vector 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,NOTVECTOR
// The other entry point: the pass option dialects-in-scheme=, which loads the dialect when the pass runs
// (so the input must not use it: empty.mlir; the pass is a no-op).
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %S/empty.mlir --mlir-disable-threading --crest-pass="dialects-in-scheme=bad=passes/macro-error passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,MACRO
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %S/empty.mlir --mlir-disable-threading --crest-pass="dialects-in-scheme=bad=passes/body-error passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s --check-prefixes=ALL,BODY

// ALL-NOT: PLEASE submit a bug report
// ALL-NOT: invalid memory reference
// MACRO: error: Failed to import Scheme library: passes/macro-error: Exception in define-op: assembly-format: $nope
// UNBOUND: error: Failed to import Scheme library: passes/unbound: Exception: attempt to reference unbound identifier this-predicate-is-not-bound
// MISSING: error: Failed to import Scheme library: passes/does-not-exist: Exception: library (passes does-not-exist) not found
// BODY: error: Failed to import Scheme library: passes/body-error: {{.*}}boom at library load
// NOTEXPORTED: error: Failed to import Scheme library: passes/not-exported:
// NOTVECTOR: error: Failed to import Scheme library: passes/not-a-vector:

// The dialect is used, so a lazy loader would load it here; an eager one reports before parsing.
func.func @f(%a: i32) {
  "bad.op"(%a) : (i32) -> ()
  return
}
