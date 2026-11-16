// A mistake with { } in an op-form is an error of expansion that names the form (each library
// below is a run of its own: an error of expansion ends the import).
//
// DEFINE: %{run} = not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme %crest-opt %s
// RUN: %{run} --crest-pass="passes=passes/missing-close" 2>&1 | %FileCheck %s --check-prefix=MISSING
// RUN: %{run} --crest-pass="passes=passes/label-without-arguments" 2>&1 | %FileCheck %s --check-prefix=LABEL
// RUN: %{run} --crest-pass="passes=passes/stray-close" 2>&1 | %FileCheck %s --check-prefix=STRAY

// MISSING: error: Failed to import Scheme library: passes/missing-close:
// MISSING-SAME: this { has no matching }

// LABEL: error: Failed to import Scheme library: passes/label-without-arguments:
// LABEL-SAME: a block label is followed by its arguments

// STRAY: error: Failed to import Scheme library: passes/stray-close:
// STRAY-SAME: misplaced }

module {
}
