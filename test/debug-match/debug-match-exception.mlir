// Always-on exception logging — no CREST_DEBUG_MATCH needed
//
// (:attr "name") asserts the attribute must exist. If absent, it raises
// an unexpected error that is always logged via crest::logging::warning,
// even in production (without CREST_DEBUG_MATCH=1).
//
// Pattern: (:attr "missing") on test.add — attribute never present.
// Expected: warning line containing "exception:" and the attribute name.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-attr-error" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [warning] unknown: [%%require-missing-attr] exception:
// CHECK-SAME: attribute 'missing' absent on op:

func.func @attr_error(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
