// A mistake with { } in an op-form is an error of expansion that names the form (each library
// below is a run of its own: an error of expansion ends the import).
//
// DEFINE: %{run} = not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme %crest-opt %s
// RUN: %{run} --crest-pass="passes=passes/missing-close" 2>&1 | %FileCheck %s --check-prefix=MISSING
// RUN: %{run} --crest-pass="passes=passes/label-without-arguments" 2>&1 | %FileCheck %s --check-prefix=LABEL
// RUN: %{run} --crest-pass="passes=passes/stray-close" 2>&1 | %FileCheck %s --check-prefix=STRAY
// RUN: %{run} --crest-pass="passes=passes/label-at-end" 2>&1 | %FileCheck %s --check-prefix=AT-END
// RUN: %{run} --crest-pass="passes=passes/nested-missing-close" 2>&1 | %FileCheck %s --check-prefix=NESTED
// RUN: %{run} --crest-pass="passes=passes/label-with-bad-arguments" 2>&1 | %FileCheck %s --check-prefix=BAD-ARGUMENTS
// RUN: %{run} --crest-pass="passes=passes/missing-brace-import" 2>&1 | %FileCheck %s --check-prefix=NO-IMPORT
// RUN: %{run} --crest-pass="passes=passes/dynamic-arguments-without-label" 2>&1 | %FileCheck %s --check-prefix=NO-LABEL
// RUN: %{run} --crest-pass="passes=passes/close-not-imported" 2>&1 | %FileCheck %s --check-prefix=CLOSE
// RUN: %{run} --crest-pass="passes=passes/empty-begin-mlir-code" 2>&1 | %FileCheck %s --check-prefix=EMPTY
// RUN: %{run} --crest-pass="passes=passes/old-label-form" 2>&1 | %FileCheck %s --check-prefix=OLD-LABEL
// RUN: %{run} --crest-pass="passes=passes/old-region-form" 2>&1 | %FileCheck %s --check-prefix=OLD-REGION

// MISSING: error: Failed to import Scheme library: passes/missing-close:
// MISSING-SAME: this { has no matching }

// LABEL: error: Failed to import Scheme library: passes/label-without-arguments:
// LABEL-SAME: a block label is followed by its arguments

// STRAY: error: Failed to import Scheme library: passes/stray-close:
// STRAY-SAME: misplaced }

// A label that is the last item of its brace has no arguments after it.
// AT-END: error: Failed to import Scheme library: passes/label-at-end:
// AT-END-SAME: a block label is followed by its arguments

// Two { with no } at all: an error, whichever { it names.
// NESTED: error: Failed to import Scheme library: passes/nested-missing-close:
// NESTED-SAME: this { has no matching }

// The item after a label must have the shape of an argument list, not just be a list.
// BAD-ARGUMENTS: error: Failed to import Scheme library: passes/label-with-bad-arguments:
// BAD-ARGUMENTS-SAME: a block label is followed by its arguments

// A { that is not the keyword says to import it.
// NO-IMPORT: error: Failed to import Scheme library: passes/missing-brace-import:
// NO-IMPORT-SAME: this { is not the brace keyword: import { } from (crest)

// ,@types is the arguments of a block, so it comes after a label.
// NO-LABEL: error: Failed to import Scheme library: passes/dynamic-arguments-without-label:
// NO-LABEL-SAME: a block with dynamic arguments needs a label

// A } that is not the keyword says to import it.
// CLOSE: error: Failed to import Scheme library: passes/close-not-imported:
// CLOSE-SAME: this } is not the brace keyword: import { } from (crest)

// begin-mlir-code needs at least one op-form or expression.
// EMPTY: error: Failed to import Scheme library: passes/empty-begin-mlir-code:
// EMPTY-SAME: expected at least one op-form or Scheme expression

// The regions of before braces are an error that says what to write.
// OLD-LABEL: error: Failed to import Scheme library: passes/old-label-form:
// OLD-LABEL-SAME: (^label ...) is not a region any more: write { ^label ... } instead
// OLD-REGION: error: Failed to import Scheme library: passes/old-region-form:
// OLD-REGION-SAME: (:region ...) is not a region any more: write { ^a ... ^b ... } instead

module {
}
