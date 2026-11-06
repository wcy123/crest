// Declarative conversion registration (G8, plans/08). Every conversion pass repeats the same
// imperative shape: a TypeConverter, a ConversionTarget with legal/illegal dialects and ops,
// a RewritePatternSet, one add-conversion-pattern per pattern, and applyPartialConversion
// with its (eqv? 1 ...) idiom. The planned form, apply-conversion, states the same thing as
// keyword arguments and returns #t on success.
//
// The input exercises each part of the form:
//
//   test.a      pattern with the type converter                  --> test.a_done
//   test.b      pattern without it (:no-type-converter)          --> test.b_done
//   test.c      pattern registered by a :populate hook           --> test.c_done
//   test.keep   dynamically legal                                    kept
//   other.x     a dialect the target does not mention               kept (partial mode)
//
//   imperative   the control: the low-level API (works today)
//   declarative  apply-conversion, which does not exist yet
//
// Remove XFAIL when G8 is implemented. The syntax is the one proposed in the plan; if another
// is chosen, change declarative.sls.
//
// XFAIL: *
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/imperative" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme2 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/declarative" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK-NEXT:    "test.a_done"() : () -> ()
// CHECK-NEXT:    "test.b_done"() : () -> ()
// CHECK-NEXT:    "test.c_done"() : () -> ()
// CHECK-NEXT:    "test.keep"() : () -> ()
// CHECK-NEXT:    "other.x"() : () -> ()
// CHECK-NEXT:    return

func.func @f() {
  "test.a"() : () -> ()
  "test.b"() : () -> ()
  "test.c"() : () -> ()
  "test.keep"() : () -> ()
  "other.x"() : () -> ()
  return
}
