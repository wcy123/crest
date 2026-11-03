// A type-converter materialization callback receives the builder as a raw OpBuilder*, and
// bindings that take a builder (here tensor.cast) accept it. The function argument is
// converted from tensor<4xf32> to tensor<?xf32>, while test.use keeps the old type, so the
// converter must materialize a tensor.cast back to tensor<4xf32>.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/materialization-builder dialects=func,tensor" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f(%arg0: tensor<?xf32>)
// CHECK-NEXT:    %[[C:.*]] = tensor.cast %arg0 : tensor<?xf32> to tensor<4xf32>
// CHECK-NEXT:    "test.use"(%[[C]]) : (tensor<4xf32>) -> ()

func.func @f(%arg0: tensor<4xf32>) {
  "test.use"(%arg0) : (tensor<4xf32>) -> ()
  return
}
