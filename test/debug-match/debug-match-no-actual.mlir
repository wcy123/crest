// :set-current-op failure is silent — no FAILED: logged.
//
// Pattern expects test.sub's operand to come from test.add.
// The IR passes a block argument (%x has no defining op) → :set-current-op
// returns #f silently. "No defining op" is a structural mismatch, not
// actionable on its own; the subsequent :check-op would give the real message.
// With CREST_DEBUG_MATCH=1, no warning is emitted for this case.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-no-actual" %s 2>&1 \
// RUN:   | %FileCheck %s

// No warning at all — :set-current-op failure is suppressed
// CHECK-NOT: [warning]

func.func @no_chain(%x: i32) -> i32 {
  %0 = "test.sub"(%x) : (i32) -> i32
  return %0 : i32
}
