// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.ScatterND becomes hipsr.scatter_nd. Rejected forms are in
// scatter_nd-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @scatter_features(%arg0: !hipsr.context, %arg1: tensor<?x?x4096xf16, #hipsr.mem<device>>, %arg2: tensor<?x3xi64, #hipsr.mem<device>>, %arg3: tensor<?xf16, #hipsr.mem<device>>) -> tensor<?x?x4096xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape):
// CHECK-NEXT:       "hipsr.shape_yield"(%arg4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x?x4096xf16, #hipsr.mem<device>>) -> tensor<?x?x4096xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.scatter_nd"(%arg0, %arg1, %arg2, %arg3, %0) : (!hipsr.context, tensor<?x?x4096xf16, #hipsr.mem<device>>, tensor<?x3xi64, #hipsr.mem<device>>, tensor<?xf16, #hipsr.mem<device>>, tensor<?x?x4096xf16, #hipsr.mem<device>>) -> tensor<?x?x4096xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x?x4096xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @default_reduction(%arg0: !hipsr.context, %arg1: tensor<4x8x2xf16, #hipsr.mem<device>>, %arg2: tensor<5x1xi64, #hipsr.mem<device>>, %arg3: tensor<5x8x2xf16, #hipsr.mem<device>>) -> tensor<4x8x2xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape):
// CHECK-NEXT:       "hipsr.shape_yield"(%arg4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<4x8x2xf16, #hipsr.mem<device>>) -> tensor<4x8x2xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.scatter_nd"(%arg0, %arg1, %arg2, %arg3, %0) : (!hipsr.context, tensor<4x8x2xf16, #hipsr.mem<device>>, tensor<5x1xi64, #hipsr.mem<device>>, tensor<5x8x2xf16, #hipsr.mem<device>>, tensor<4x8x2xf16, #hipsr.mem<device>>) -> tensor<4x8x2xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<4x8x2xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// The embedding graph writes image features into the token embeddings at the
// positions it found. The result takes the data's shape, but the placeholder
// still lists every scatter operand so the two stay in one pool domain. Its
// shape region stays empty for hipsr-populate-shape-region to fill in.
func.func @scatter_features(%ctx: !hipsr.context,
                            %embeds: tensor<?x?x4096xf16>,
                            %positions: tensor<?x3xi64>,
                            %features: tensor<?xf16>) -> tensor<?x?x4096xf16> {
  %0 = "onnx.ScatterND"(%embeds, %positions, %features) {reduction = "none"}
      : (tensor<?x?x4096xf16>, tensor<?x3xi64>, tensor<?xf16>)
      -> tensor<?x?x4096xf16>
  "onnx.Return"(%0) : (tensor<?x?x4096xf16>) -> ()
}

// -----

// ONNX defaults the reduction to overwriting, so an absent attribute converts
// like an explicit one. A row here addresses one axis instead of all of them,
// so the updates carry the data extents it does not reach.
func.func @default_reduction(%ctx: !hipsr.context, %data: tensor<4x8x2xf16>,
                             %ids: tensor<5x1xi64>,
                             %updates: tensor<5x8x2xf16>) -> tensor<4x8x2xf16> {
  %0 = "onnx.ScatterND"(%data, %ids, %updates)
      : (tensor<4x8x2xf16>, tensor<5x1xi64>, tensor<5x8x2xf16>)
      -> tensor<4x8x2xf16>
  "onnx.Return"(%0) : (tensor<4x8x2xf16>) -> ()
}
