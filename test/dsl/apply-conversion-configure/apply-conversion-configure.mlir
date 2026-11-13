// apply-conversion with configure hooks. Some passes set up their TypeConverter and
// ConversionTarget with helpers that take the object (onnx-to-hipsr does), which the keys
// :type-converter (a (type) -> type procedure) and the fixed legal/illegal lists cannot say.
// :configure-type-converter takes a procedure of the converter and :configure-target a procedure
// of the target and the converter; both run after the declarative keys.
//
// The pass fails if the converter hook did not run. The input needs the target hook to convert:
//
//   test.a   --> test.a_done   (test is illegal, test.a_done legal: both set by the target hook)
//   other.x     kept           (a dialect the target does not mention, partial mode)
//
//   imperative   the control: the low-level API (works today)
//   declarative  apply-conversion with the hooks
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/imperative" %s | %FileCheck %s
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme2 \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/declarative" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK-NEXT:    "test.a_done"() : () -> ()
// CHECK-NEXT:    "other.x"() : () -> ()
// CHECK-NEXT:    return

func.func @f() {
  "test.a"() : () -> ()
  "other.x"() : () -> ()
  return
}
