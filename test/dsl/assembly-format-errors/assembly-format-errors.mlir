// A mistake in an :assembly-format string is reported when the library compiles, with the problem and its
// column in the format; what the first version does not support says so.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unknown-directive" 2>&1 | %FileCheck %s --check-prefix=DIRECTIVE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unknown-variable" 2>&1 | %FileCheck %s --check-prefix=VARIABLE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/missing-operand" 2>&1 | %FileCheck %s --check-prefix=OPERAND
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/missing-type" 2>&1 | %FileCheck %s --check-prefix=TYPE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/missing-result-type" 2>&1 | %FileCheck %s --check-prefix=RESULT
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/missing-attr-dict" 2>&1 | %FileCheck %s --check-prefix=ATTRDICT
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unsupported-literal" 2>&1 | %FileCheck %s --check-prefix=LITERAL
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unsupported-directive" 2>&1 | %FileCheck %s --check-prefix=CUSTOM
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-group" 2>&1 | %FileCheck %s --check-prefix=GROUP
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/unterminated" 2>&1 | %FileCheck %s --check-prefix=UNTERMINATED
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/else-group" 2>&1 | %FileCheck %s --check-prefix=ELSE
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-pass="passes=passes/with-parse" 2>&1 | %FileCheck %s --check-prefix=BOTH

// DIRECTIVE: Failed to import Scheme library: passes/unknown-directive: Exception in define-op: assembly-format: unknown directive foo at column 7
// VARIABLE: Failed to import Scheme library: passes/unknown-variable: Exception in define-op: assembly-format: $nope (column 0) is not an operand or an attribute of the op
// OPERAND: Failed to import Scheme library: passes/missing-operand: Exception in define-op: assembly-format: the operand $other does not appear in the format
// TYPE: Failed to import Scheme library: passes/missing-type: Exception in define-op: assembly-format: the type of the operand $input does not appear in the format
// RESULT: Failed to import Scheme library: passes/missing-result-type: Exception in define-op: assembly-format: the type of the result $out does not appear in the format: write type($out) or type(results)
// ATTRDICT: Failed to import Scheme library: passes/missing-attr-dict: Exception in define-op: assembly-format: attr-dict does not appear in the format
// LITERAL: Failed to import Scheme library: passes/unsupported-literal: Exception in define-op: assembly-format: the literal `=` (column 7) is not supported yet
// CUSTOM: Failed to import Scheme library: passes/unsupported-directive: Exception in define-op: assembly-format: the directive custom (column 0) is not supported yet
// GROUP: Failed to import Scheme library: passes/bad-group: Exception in define-op: assembly-format: the first element of a group (column 0) must be an optional operand
// UNTERMINATED: Failed to import Scheme library: passes/unterminated: Exception in define-op: assembly-format: unterminated literal at column 34
// ELSE: Failed to import Scheme library: passes/else-group: Exception in define-op: assembly-format: an else group (column 26) is not supported yet
// BOTH: Failed to import Scheme library: passes/with-parse: Exception in define-op: :assembly-format cannot be combined with :parse or :print

module {}
