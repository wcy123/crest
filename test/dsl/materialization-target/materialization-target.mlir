// A target materialization on its own: the operand of test.conv, a tensor<4xf32> that the type
// converter turns into tensor<?xf32>, is cast to the converted type when the pattern gets it.
//
// RUN: rm -rf %t/materialization-target-scheme && mkdir -p %t/materialization-target-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/materialization-target-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/target-materialization" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         %[[M:.*]] = "test.make"() : () -> tensor<4xf32>
// CHECK-NEXT:    %[[C:.*]] = tensor.cast %[[M]] : tensor<4xf32> to tensor<?xf32>
// CHECK-NEXT:    "test.conv_done"(%[[C]]) : (tensor<?xf32>) -> ()

func.func @f() {
  %0 = "test.make"() : () -> tensor<4xf32>
  "test.conv"(%0) : (tensor<4xf32>) -> ()
  return
}
