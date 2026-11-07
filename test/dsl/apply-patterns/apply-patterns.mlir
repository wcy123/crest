// Declarative registration of greedy rewrite patterns. Every rewrite pass repeats the same shape: a
// RewritePatternSet, one add-rewrite-pattern per pattern, and applyPatternsGreedily. The planned
// form, apply-patterns (plans/14-apply-patterns.md), states the same thing as keyword arguments and returns #t on
// success.
//
//   test.a    pattern with an explicit benefit                      --> test.a_done
//   test.b    pattern with the default benefit                      --> test.b_done
//   test.c    pattern added by a :populate hook                     --> test.c_done
//   test.x    two patterns, benefit 1 and 5: the higher one wins    --> test.x_high
//   other.y   no pattern                                               kept
//
//   imperative   the control: the low-level API (works today)
//   declarative  apply-patterns
//   pattern-set  the same, with define-pattern-set and :populate with a list of sets
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/imperative" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme2 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/declarative" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme3 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/pattern-set" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK-NEXT:    "test.a_done"() : () -> ()
// CHECK-NEXT:    "test.b_done"() : () -> ()
// CHECK-NEXT:    "test.c_done"() : () -> ()
// CHECK-NEXT:    "test.x_high"() : () -> ()
// CHECK-NEXT:    "other.y"() : () -> ()
// CHECK-NEXT:    return

func.func @f() {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  "test.c"() : () -> ()
  "test.x"() : () -> ()
  "other.y"() : () -> ()
  return
}
