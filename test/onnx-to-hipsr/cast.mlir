// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// Converts onnx.Cast to hipsr.cast, leaving the shape region empty (a later
// pass populates it).
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" | %FileCheck %s

// CHECK: module {
// CHECK-NEXT:   func.func @cast_chain(%arg0: !hipsr.context, %arg1: tensor<?x8xf32, #hipsr.mem<device>>) -> tensor<?x8xf32, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1) ({
// CHECK-NEXT:     ^bb0(%arg2: !shape.shape):
// CHECK-NEXT:       "hipsr.shape_yield"(%arg2) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x8xf32, #hipsr.mem<device>>) -> tensor<?x8xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.cast"(%arg0, %arg1, %0) : (!hipsr.context, tensor<?x8xf32, #hipsr.mem<device>>, tensor<?x8xf16, #hipsr.mem<device>>) -> tensor<?x8xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %2 = "hipsr.placeholder"(%arg0, %1) ({
// CHECK-NEXT:     ^bb0(%arg2: !shape.shape):
// CHECK-NEXT:       "hipsr.shape_yield"(%arg2) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x8xf16, #hipsr.mem<device>>) -> tensor<?x8xf32, #hipsr.mem<device>>
// CHECK-NEXT:     %3 = "hipsr.cast"(%arg0, %1, %2) : (!hipsr.context, tensor<?x8xf16, #hipsr.mem<device>>, tensor<?x8xf32, #hipsr.mem<device>>) -> tensor<?x8xf32, #hipsr.mem<device>>
// CHECK-NEXT:     return %3 : tensor<?x8xf32, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// The second placeholder follows the shape graph through the first
// placeholder, while the second cast follows the data graph.
func.func @cast_chain(
    %ctx: !hipsr.context, %input: tensor<?x8xf32>) -> tensor<?x8xf32> {
  %0 = "onnx.Cast"(%input) {to = f16} : (tensor<?x8xf32>) -> tensor<?x8xf16>
  %1 = "onnx.Cast"(%0) {to = f32} : (tensor<?x8xf16>) -> tensor<?x8xf32>
  "onnx.Return"(%1) : (tensor<?x8xf32>) -> ()
}
