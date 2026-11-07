// A mistake in an apply-patterns or define-pattern-set form is reported when the library compiles, at
// the key or the entry, with its line and column.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unknown-key" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNKNOWN
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/repeated-key" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=REPEATED
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/key-without-value" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=NOVALUE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-entry" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=ENTRY
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-list" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=LIST
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-set-entry" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=SET

// UNKNOWN: Failed to import Scheme library: passes/unknown-key: Exception in apply-patterns: unknown key :pattern at line {{[0-9]+}}, char {{[0-9]+}}
// REPEATED: Failed to import Scheme library: passes/repeated-key: Exception in apply-patterns: repeated key :patterns at line {{[0-9]+}}, char {{[0-9]+}}
// NOVALUE: Failed to import Scheme library: passes/key-without-value: Exception in apply-patterns: key without a value :patterns at line {{[0-9]+}}, char {{[0-9]+}}
// ENTRY: Failed to import Scheme library: passes/bad-entry: Exception in apply-patterns: a pattern is (name pattern [benefit]) ("a") at line {{[0-9]+}}, char {{[0-9]+}}
// LIST: Failed to import Scheme library: passes/bad-list: Exception in apply-patterns: :patterns expects a list "a" at line {{[0-9]+}}, char {{[0-9]+}}
// SET: Failed to import Scheme library: passes/bad-set-entry: Exception in define-pattern-set: a pattern is (name pattern [benefit]) ("a") at line {{[0-9]+}}, char {{[0-9]+}}

module {}
