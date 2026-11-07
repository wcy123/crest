// The one-argument form (:fold (op) ...) is an error: a folder gets the constant operand attributes
// and returns results, so it says (:fold (op operand-attributes) ...).
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/fold-err \
// RUN:   %crest-opt %s --crest-pass="passes=passes/old-fold" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: Failed to import Scheme library: passes/old-fold: Exception in define-op: expected (:fold (op operand-attributes) body ...)

module {}
