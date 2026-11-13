// The root of a conversion pattern gets the operands that the type converter made, also when the root has
// an (:optional ...) or (:variadic ...) operand: both operands of test.conv are tensor<4xf32>, which the
// type converter turns into tensor<?xf32>, so test.conv_done takes the two casts and not the original values.
//
// RUN: rm -rf %t/conversion-flex-scheme && mkdir -p %t/conversion-flex-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/conversion-flex-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/conversion-flex" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[A:.*]] = "test.make"() : () -> tensor<4xf32>
// CHECK:         %[[CA:.*]] = tensor.cast %[[A]] : tensor<4xf32> to tensor<?xf32>
// CHECK:         %[[B:.*]] = "test.make"() : () -> tensor<4xf32>
// CHECK:         %[[CB:.*]] = tensor.cast %[[B]] : tensor<4xf32> to tensor<?xf32>
// CHECK:         "test.conv_done"(%[[CA]], %[[CB]]) : (tensor<?xf32>, tensor<?xf32>) -> ()

func.func @f() {
  %0 = "test.make"() : () -> tensor<4xf32>
  %1 = "test.make"() : () -> tensor<4xf32>
  "test.conv"(%0, %1) {operandSegmentSizes = array<i32: 1, 1>} : (tensor<4xf32>, tensor<4xf32>) -> ()
  return
}
