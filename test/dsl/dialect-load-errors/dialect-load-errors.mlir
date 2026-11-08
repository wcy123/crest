// REGRESSION: a Scheme dialect library that cannot be loaded used to abort the process.
//
// It used to give: `LLVM ERROR: CrestDialect: failed to import Scheme library ...`, the LLVM crash banner
// ("PLEASE submit a bug report") and a core dump (exit 134), or, when the import itself "succeeds" but
// leaves no callbacks vector (an error in the library body, a dialect that is not exported, a name bound to
// something else), a bare `Error: invalid memory reference` that does not even name the library.
// Cause was: CrestDialect's constructor (lib/Crest/Dialect.cpp) imports the library the first time a dialect op
// is parsed, cannot return a failure, and reads the callbacks vector without checking it.
//
// Now: the same as a pass library that fails to import (test/dsl/import-error): a diagnostic
// `error: Failed to import Scheme library: <library>: <reason>` and exit status 1, whichever way the
// dialect is named (--crest-scheme-dialect, dialects-in-scheme=). The ALL-NOT lines catch the abort.
//
// One run per failure path (a failed run ends the process, so a run can only test one library):
//   - the import fails (library not found; a macro error or an unbound identifier take the same path, and
//     test/dsl/import-error checks their message texts),
//   - the import succeeds but the body is never run (Chez runs a library body when an export is first used),
//   - the import succeeds but leaves no callbacks vector (the dialect is not exported),
// the first two again through dialects-in-scheme=, and the Scheme entry points (load-from-scheme.sps).
//
// DEFINE: %{opt} = env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme %crest-opt --mlir-disable-threading
// DEFINE: %{via-flag} = %{opt} %s --crest-scheme-dialect=bad=passes
// DEFINE: %{via-pass} = %{opt} %S/empty.in --crest-pass="passes=passes/identity dialects-in-scheme=bad=passes
//
// RUN: not %{via-flag}/does-not-exist 2>&1 | %FileCheck %s --check-prefixes=ALL,MISSING
// RUN: not %{via-flag}/body-error 2>&1 | %FileCheck %s --check-prefixes=ALL,BODY
// RUN: not %{via-flag}/not-exported 2>&1 | %FileCheck %s --check-prefixes=ALL,NOTEXPORTED
// dialects-in-scheme= loads the dialect when the pass runs, so its input must not use the dialect.
// RUN: not %{via-pass}/does-not-exist" 2>&1 | %FileCheck %s --check-prefixes=ALL,MISSING
// RUN: not %{via-pass}/body-error" 2>&1 | %FileCheck %s --check-prefixes=ALL,BODY
// A Scheme program gets a Scheme error that names the library (load-from-scheme.sps).
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme %scheme-mlir %S/load-from-scheme.sps 2>&1 | %FileCheck %s --check-prefix=SCHEME

// ALL-NOT: PLEASE submit a bug report
// ALL-NOT: invalid memory reference
// MISSING: error: Failed to import Scheme library: passes/does-not-exist: Exception: library (passes does-not-exist) not found
// BODY: error: Failed to import Scheme library: passes/body-error: {{.*}}boom at library load
// NOTEXPORTED: error: Failed to import Scheme library: passes/not-exported:
// SCHEME: load-scheme-dialect!: Exception in crest::load-scheme-dialect!: Failed to import Scheme library: passes/body-error: Exception in body-error: boom at library load
// SCHEME-NEXT: DialectRegistry::insert: Exception in mlir::DialectRegistry::insert: Failed to import Scheme library: passes/body-error: Exception in body-error: boom at library load

// The dialect is used, so a lazy loader would load it here; an eager one reports before parsing.
func.func @f(%a: i32) {
  "bad.op"(%a) : (i32) -> ()
  return
}
