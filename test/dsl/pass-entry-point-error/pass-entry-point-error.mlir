// An error of the body of pass-entry-point (define-pass-entry-point) is answered as (who . why); the runner of
// --crest-pass emits "who: why" as an error on the module, and the pass fails. Nothing is raised into C++.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/raises" 2>&1 | %FileCheck %s

// CHECK: error: raises: the pass is broken

module {}
