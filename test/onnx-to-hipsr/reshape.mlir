// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.Reshape becomes a hipsr.compute holding a collapse, an expand, or both,
// with a placeholder whose shape region resolves the destination. The result
// type comes from the operands, not from the type ONNX declared, and the region
// never reads memory. Rejected forms are in reshape-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @flatten_dynamic(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16>) -> tensor<?xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<-1> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Reshape"(%arg1, %0) {allowzero = 0 : si64} : (tensor<?x4096xf16>, tensor<1xi64>) -> tensor<?xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @expand_dynamic(%arg0: !hipsr.context, %arg1: tensor<?xf16>) -> tensor<?x4096xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<[-1, 4096]> : tensor<2xi64>} : () -> tensor<2xi64>
// CHECK-NEXT:     %1 = "onnx.Reshape"(%arg1, %0) {allowzero = 0 : si64} : (tensor<?xf16>, tensor<2xi64>) -> tensor<?x4096xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?x4096xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @cast_and_expand(%arg0: !hipsr.context, %arg1: tensor<?x4xi64>) -> tensor<6x4xi64> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<[6, 4]> : tensor<2xi64>} : () -> tensor<2xi64>
// CHECK-NEXT:     %1 = "onnx.Reshape"(%arg1, %0) {allowzero = 0 : si64} : (tensor<?x4xi64>, tensor<2xi64>) -> tensor<6x4xi64>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<6x4xi64>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @refines_to_input(%arg0: !hipsr.context, %arg1: tensor<?x32xf16>) -> tensor<?x?xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<[-1, 32]> : tensor<2xi64>} : () -> tensor<2xi64>
// CHECK-NEXT:     %1 = "onnx.Reshape"(%arg1, %0) {allowzero = 0 : si64} : (tensor<?x32xf16>, tensor<2xi64>) -> tensor<?x?xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?x?xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @static_infers_dim(%arg0: !hipsr.context, %arg1: tensor<2x3x4xf16>) -> tensor<?x?xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<[-1, 4]> : tensor<2xi64>} : () -> tensor<2xi64>
// CHECK-NEXT:     %1 = "onnx.Reshape"(%arg1, %0) {allowzero = 0 : si64} : (tensor<2x3x4xf16>, tensor<2xi64>) -> tensor<?x?xf16>
// CHECK-NEXT:     "onnx.Return"(%1) : (tensor<?x?xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// A constant [-1] flattens a dynamic batch, as an embedding graph does to its
// image features. Nothing else is stated, so the divisor is 1, and the collapse
// alone already reaches the 1-D result.
func.func @flatten_dynamic(%ctx: !hipsr.context,
                           %input: tensor<?x4096xf16>) -> tensor<?xf16> {
  %shape = "onnx.Constant"() {value = dense<-1> : tensor<1xi64>}
      : () -> tensor<1xi64>
  %0 = "onnx.Reshape"(%input, %shape) {allowzero = 0 : si64}
      : (tensor<?x4096xf16>, tensor<1xi64>) -> tensor<?xf16>
  "onnx.Return"(%0) : (tensor<?xf16>) -> ()
}

// -----

// A rank-1 input is already flat, so no collapse comes first. The expand takes
// its dynamic dimension off the destination rather than dividing again.
func.func @expand_dynamic(%ctx: !hipsr.context,
                          %input: tensor<?xf16>) -> tensor<?x4096xf16> {
  %shape = "onnx.Constant"() {value = dense<[-1, 4096]> : tensor<2xi64>}
      : () -> tensor<2xi64>
  %0 = "onnx.Reshape"(%input, %shape) {allowzero = 0 : si64}
      : (tensor<?xf16>, tensor<2xi64>) -> tensor<?x4096xf16>
  "onnx.Return"(%0) : (tensor<?x4096xf16>) -> ()
}

// -----

// A dynamic input against a target shape that names every dimension. Neither
// collapse nor expand can make the flat dimension static, so a cast stands
// between them.
func.func @cast_and_expand(%ctx: !hipsr.context,
                           %input: tensor<?x4xi64>) -> tensor<6x4xi64> {
  %shape = "onnx.Constant"() {value = dense<[6, 4]> : tensor<2xi64>}
      : () -> tensor<2xi64>
  %0 = "onnx.Reshape"(%input, %shape) {allowzero = 0 : si64}
      : (tensor<?x4xi64>, tensor<2xi64>) -> tensor<6x4xi64>
  "onnx.Return"(%0) : (tensor<6x4xi64>) -> ()
}

// -----

// The identity check runs on the inferred type, so a declared tensor<?x?xf16>
// cannot hide one. The reshape is replaced by its input, with no destination.
func.func @refines_to_input(%ctx: !hipsr.context,
                            %input: tensor<?x32xf16>) -> tensor<?x?xf16> {
  %shape = "onnx.Constant"() {value = dense<[-1, 32]> : tensor<2xi64>}
      : () -> tensor<2xi64>
  %0 = "onnx.Reshape"(%input, %shape) {allowzero = 0 : si64}
      : (tensor<?x32xf16>, tensor<2xi64>) -> tensor<?x?xf16>
  "onnx.Return"(%0) : (tensor<?x?xf16>) -> ()
}

// -----

// A static input resolves the -1 at compile time, so the result type is static,
// the shape region is constants alone, and the expand states its dimensions.
func.func @static_infers_dim(%ctx: !hipsr.context,
                             %input: tensor<2x3x4xf16>) -> tensor<?x?xf16> {
  %shape = "onnx.Constant"() {value = dense<[-1, 4]> : tensor<2xi64>}
      : () -> tensor<2xi64>
  %0 = "onnx.Reshape"(%input, %shape) {allowzero = 0 : si64}
      : (tensor<2x3x4xf16>, tensor<2xi64>) -> tensor<?x?xf16>
  "onnx.Return"(%0) : (tensor<?x?xf16>) -> ()
}
