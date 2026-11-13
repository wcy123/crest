// A mistake in a pattern or in a dialect is an error with the form and the position, and says what to write instead
// (each library below is a run of its own: an error of expansion ends the import).
//
// DEFINE: %{run} = not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme %crest-opt %s
// RUN: %{run} --crest-pass="passes=passes/unreachable" 2>&1 | %FileCheck %s --check-prefix=UNREACHABLE
// RUN: %{run} --crest-pass="passes=passes/no-dot" 2>&1 | %FileCheck %s --check-prefix=NO-DOT
// RUN: %{run} --crest-pass="passes=passes/then-let-clash" 2>&1 | %FileCheck %s --check-prefix=CLASH
// RUN: %{run} --crest-scheme-dialect=repdialect=passes/repeated-operands 2>&1 | %FileCheck %s --check-prefix=OPERANDS
// RUN: %{run} --crest-scheme-dialect=verdialect=passes/repeated-verify 2>&1 | %FileCheck %s --check-prefix=VERIFY

// An op of the match that no value joins to the root can never be reached: that is an error, not a line on stdout.
// UNREACHABLE: error: Failed to import Scheme library: passes/unreachable:
// UNREACHABLE-SAME: test.other
// UNREACHABLE-SAME: not connected to the root

// An op without a result is written dialect.op: a name without a dot is something else.
// NO-DOT: error: Failed to import Scheme library: passes/no-dot:
// NO-DOT-SAME: {{.*}}expected a match operation
// NO-DOT-SAME: noname
// NO-DOT-NOT: Invalid3

// A :then-let variable cannot have the name of a variable of :if-match.
// CLASH: error: Failed to import Scheme library: passes/then-let-clash:
// CLASH-SAME: :then-let binds %x
// CLASH-SAME: :if-match

// A clause of define-op is given once.
// OPERANDS: error: Failed to import Scheme library: passes/repeated-operands:
// OPERANDS-SAME: repeated :operands
// VERIFY: error: Failed to import Scheme library: passes/repeated-verify:
// VERIFY-SAME: repeated :verify

module {
}
