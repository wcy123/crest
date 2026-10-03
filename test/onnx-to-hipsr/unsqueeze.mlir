// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.Unsqueeze becomes a hipsr.compute holding a tensor.expand_shape, with a
// placeholder whose shape region resolves the destination. The result type comes
// from the operands, not from the type ONNX declared: the axes place the unit
// dimensions and the input gives the rest. Rejected forms are in
// unsqueeze-invalid.mlir.
//
// The result aliases the input, so it keeps the input's memory space.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @trailing_axis(%arg0: !hipsr.context, %arg1: tensor<?x?xi1>) -> tensor<?x?x1xi1> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<-1> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Unsqueeze"(%arg1, %0) : (tensor<?x?xi1>, tensor<1xi64>) -> tensor<?x?x1xi1>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?x?x1xi1>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @interior_axis(%arg0: !hipsr.context, %arg1: tensor<?x?xi1>) -> tensor<?x?x?xi1> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<1> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Unsqueeze"(%arg1, %0) : (tensor<?x?xi1>, tensor<1xi64>) -> tensor<?x?x?xi1>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?x?x?xi1>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @host_input(%arg0: !hipsr.context, %arg1: tensor<2xi64, #hipsr.mem<host>>) -> tensor<1x2xi64> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<0> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Unsqueeze"(%arg1, %0) : (tensor<2xi64, #hipsr.mem<host>>, tensor<1xi64>) -> tensor<1x2xi64>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<1x2xi64>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @two_axes(%arg0: !hipsr.context, %arg1: tensor<3x4xf16>) -> tensor<1x3x4x1xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<[3, 0]> : tensor<2xi64>} : () -> tensor<2xi64>
// CHECK-NEXT:     %1 = "onnx.Unsqueeze"(%arg1, %0) : (tensor<3x4xf16>, tensor<2xi64>) -> tensor<1x3x4x1xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<1x3x4x1xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @no_axes(%arg0: !hipsr.context, %arg1: tensor<2x3xf16>) -> tensor<2x3xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<> : tensor<0xi64>} : () -> tensor<0xi64>
// CHECK-NEXT:     %1 = "onnx.Unsqueeze"(%arg1, %0) : (tensor<2x3xf16>, tensor<0xi64>) -> tensor<2x3xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<2x3xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// A trailing axis on a fully dynamic input, which is what an embedding graph
// inserts on a token mask. The region reads every dynamic dimension off the
// input's shape, and the body reads them off the input itself.
// One unused divisor per dynamic group, left by the expand's shape inference.
// One unused divisor per dynamic group, as in the region above.
func.func @trailing_axis(%ctx: !hipsr.context,
                         %input: tensor<?x?xi1>) -> tensor<?x?x1xi1> {
  %axes = "onnx.Constant"() {value = dense<-1> : tensor<1xi64>}
      : () -> tensor<1xi64>
  %0 = "onnx.Unsqueeze"(%input, %axes)
      : (tensor<?x?xi1>, tensor<1xi64>) -> tensor<?x?x1xi1>
  "onnx.Return"(%0) : (tensor<?x?x1xi1>) -> ()
}

// -----

// The axes resolve a dimension the declared tensor<?x?x?xi1> leaves dynamic.
// The unit lands between the two dimensions the input gives, so the result
// carries its dynamic dimensions at axes 0 and 2.
// One unused divisor per dynamic group, then the inserted unit.
// One unused divisor per dynamic group, as in the region above.
func.func @interior_axis(%ctx: !hipsr.context,
                         %input: tensor<?x?xi1>) -> tensor<?x?x?xi1> {
  %axes = "onnx.Constant"() {value = dense<1> : tensor<1xi64>}
      : () -> tensor<1xi64>
  %0 = "onnx.Unsqueeze"(%input, %axes)
      : (tensor<?x?xi1>, tensor<1xi64>) -> tensor<?x?x?xi1>
  "onnx.Return"(%0) : (tensor<?x?x?xi1>) -> ()
}

// -----

// A leading axis on a static host input. The chain stays in #hipsr.mem<host>,
// and a static result reads nothing off the input's shape: the region is
// constants and the expand states its dimensions.
func.func @host_input(%ctx: !hipsr.context,
                      %input: tensor<2xi64, #hipsr.mem<host>>)
    -> tensor<1x2xi64> {
  %axes = "onnx.Constant"() {value = dense<0> : tensor<1xi64>}
      : () -> tensor<1xi64>
  %0 = "onnx.Unsqueeze"(%input, %axes)
      : (tensor<2xi64, #hipsr.mem<host>>, tensor<1xi64>) -> tensor<1x2xi64>
  "onnx.Return"(%0) : (tensor<1x2xi64>) -> ()
}

// -----

// Two axes given out of order, which ONNX allows. They bracket the input, so
// each of its dimensions groups with one unit.
func.func @two_axes(%ctx: !hipsr.context,
                    %input: tensor<3x4xf16>) -> tensor<1x3x4x1xf16> {
  %axes = "onnx.Constant"() {value = dense<[3, 0]> : tensor<2xi64>}
      : () -> tensor<2xi64>
  %0 = "onnx.Unsqueeze"(%input, %axes)
      : (tensor<3x4xf16>, tensor<2xi64>) -> tensor<1x3x4x1xf16>
  "onnx.Return"(%0) : (tensor<1x3x4x1xf16>) -> ()
}

// -----

// Empty axes insert nothing, so the input stands as the result and no
// destination is built.
func.func @no_axes(%ctx: !hipsr.context,
                   %input: tensor<2x3xf16>) -> tensor<2x3xf16> {
  %axes = "onnx.Constant"() {value = dense<> : tensor<0xi64>}
      : () -> tensor<0xi64>
  %0 = "onnx.Unsqueeze"(%input, %axes)
      : (tensor<2x3xf16>, tensor<0xi64>) -> tensor<2x3xf16>
  "onnx.Return"(%0) : (tensor<2x3xf16>) -> ()
}
