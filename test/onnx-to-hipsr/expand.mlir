// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// Converts onnx.Expand to a placeholder-backed hipsr.expand. Rejected forms
// live in expand-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @expand(%arg0: !hipsr.context, %arg1: tensor<?x3xf16, #hipsr.mem<device>>, %arg2: tensor<2xi64, #hipsr.mem<host>>) -> tensor<?x?xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) {placeholder_type = #hipsr.placeholder<barrier>} : (!hipsr.context, tensor<?x3xf16, #hipsr.mem<device>>, tensor<2xi64, #hipsr.mem<host>>) -> tensor<?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.expand"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x3xf16, #hipsr.mem<device>>, tensor<2xi64, #hipsr.mem<host>>, tensor<?x?xf16, #hipsr.mem<device>>) -> tensor<?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @expand_broadcast_rank(%arg0: !hipsr.context, %arg1: tensor<2x3xf16, #hipsr.mem<device>>, %arg2: tensor<4xi64, #hipsr.mem<host>>) -> tensor<?x?x?x?xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) {placeholder_type = #hipsr.placeholder<barrier>} : (!hipsr.context, tensor<2x3xf16, #hipsr.mem<device>>, tensor<4xi64, #hipsr.mem<host>>) -> tensor<?x?x?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.expand"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<2x3xf16, #hipsr.mem<device>>, tensor<4xi64, #hipsr.mem<host>>, tensor<?x?x?x?xf16, #hipsr.mem<device>>) -> tensor<?x?x?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x?x?x?xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// The requested extents are read at runtime, so the init is a barrier
// placeholder over both the input and the shape operand.
//
// The conversion leaves the region empty; hipsr-populate-shape-region fills it.
func.func @expand(%ctx: !hipsr.context, %input: tensor<?x3xf16>,
                  %shape: tensor<2xi64, #hipsr.mem<host>>) -> tensor<?x?xf16> {
  %0 = "onnx.Expand"(%input, %shape)
      : (tensor<?x3xf16>, tensor<2xi64, #hipsr.mem<host>>) -> tensor<?x?xf16>
  "onnx.Return"(%0) : (tensor<?x?xf16>) -> ()
}

// -----

// A shape longer than the input rank raises the output rank, and the leading
// extents come from the shape operand alone.
func.func @expand_broadcast_rank(%ctx: !hipsr.context,
                                 %input: tensor<2x3xf16>,
                                 %shape: tensor<4xi64, #hipsr.mem<host>>)
    -> tensor<?x?x?x?xf16> {
  %0 = "onnx.Expand"(%input, %shape)
      : (tensor<2x3xf16>, tensor<4xi64, #hipsr.mem<host>>) -> tensor<?x?x?x?xf16>
  "onnx.Return"(%0) : (tensor<?x?x?x?xf16>) -> ()
}
