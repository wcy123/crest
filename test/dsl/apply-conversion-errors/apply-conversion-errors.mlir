// A mistake in an apply-conversion form is reported when the library compiles, at the key or the
// entry, with its line and column.
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
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-mode" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=MODE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-pattern" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=PATTERN
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-dynamic" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=DYNAMIC
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-list" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=LIST

// UNKNOWN: Failed to import Scheme library: passes/unknown-key: Exception in apply-conversion: unknown key :legal-dialect at line {{[0-9]+}}, char {{[0-9]+}}
// REPEATED: Failed to import Scheme library: passes/repeated-key: Exception in apply-conversion: repeated key :mode at line {{[0-9]+}}, char {{[0-9]+}}
// NOVALUE: Failed to import Scheme library: passes/key-without-value: Exception in apply-conversion: key without a value :mode at line {{[0-9]+}}, char {{[0-9]+}}
// MODE: Failed to import Scheme library: passes/bad-mode: Exception in apply-conversion: :mode is partial or full sometimes at line {{[0-9]+}}, char {{[0-9]+}}
// PATTERN: Failed to import Scheme library: passes/bad-pattern: Exception in apply-conversion: a pattern is (name fn [benefit] [:no-type-converter]) ("toy.add") at line {{[0-9]+}}, char {{[0-9]+}}
// DYNAMIC: Failed to import Scheme library: passes/bad-dynamic: Exception in apply-conversion: a dynamically legal entry is (name predicate) ("toy.print") at line {{[0-9]+}}, char {{[0-9]+}}
// LIST: Failed to import Scheme library: passes/bad-list: Exception in apply-conversion: :legal-dialects expects a list "func" at line {{[0-9]+}}, char {{[0-9]+}}

module {}
