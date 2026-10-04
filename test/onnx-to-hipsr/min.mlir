// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @min_two_inputs(%arg0: !hipsr.context, %arg1: tensor<4x1024xf16, #hipsr.mem<device>>, %arg2: tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
// CHECK-NEXT:       %2 = shape.broadcast %arg3, %arg4 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%2) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.min"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @min_three_inputs(%arg0: !hipsr.context, %arg1: tensor<4x1024xf16, #hipsr.mem<device>>, %arg2: tensor<4x1024xf16, #hipsr.mem<device>>, %arg3: tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape, %arg5: !shape.shape):
// CHECK-NEXT:       %4 = shape.broadcast %arg4, %arg5 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.min"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %2 = "hipsr.placeholder"(%arg0, %1, %arg3) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape, %arg5: !shape.shape):
// CHECK-NEXT:       %4 = shape.broadcast %arg4, %arg5 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %3 = "hipsr.min"(%arg0, %1, %arg3, %2) : (!hipsr.context, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>, tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %3 : tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @min_three_inputs_broadcast(%arg0: !hipsr.context, %arg1: tensor<2x1xf16, #hipsr.mem<device>>, %arg2: tensor<1x3xf16, #hipsr.mem<device>>, %arg3: tensor<2x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape, %arg5: !shape.shape):
// CHECK-NEXT:       %4 = shape.broadcast %arg4, %arg5 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<2x1xf16, #hipsr.mem<device>>, tensor<1x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.min"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<2x1xf16, #hipsr.mem<device>>, tensor<1x3xf16, #hipsr.mem<device>>, tensor<2x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %2 = "hipsr.placeholder"(%arg0, %1, %arg3) ({
// CHECK-NEXT:     ^bb0(%arg4: !shape.shape, %arg5: !shape.shape):
// CHECK-NEXT:       %4 = shape.broadcast %arg4, %arg5 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%4) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<2x3xf16, #hipsr.mem<device>>, tensor<2x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %3 = "hipsr.min"(%arg0, %1, %arg3, %2) : (!hipsr.context, tensor<2x3xf16, #hipsr.mem<device>>, tensor<2x3xf16, #hipsr.mem<device>>, tensor<2x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %3 : tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @min_single_input(%arg0: !hipsr.context, %arg1: tensor<4x1024xf16, #hipsr.mem<device>>) -> tensor<4x1024xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     return %arg1 : tensor<4x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @min_broadcast(%arg0: !hipsr.context, %arg1: tensor<?x1024xf16, #hipsr.mem<device>>, %arg2: tensor<1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
// CHECK-NEXT:       %2 = shape.broadcast %arg3, %arg4 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%2) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x1024xf16, #hipsr.mem<device>>, tensor<1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.min"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x1024xf16, #hipsr.mem<device>>, tensor<1024xf16, #hipsr.mem<device>>, tensor<?x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

func.func @min_two_inputs(%ctx: !hipsr.context, %a: tensor<4x1024xf16>,
                          %b: tensor<4x1024xf16>) -> tensor<4x1024xf16> {
  %0 = "onnx.Min"(%a, %b) : (tensor<4x1024xf16>, tensor<4x1024xf16>)
      -> tensor<4x1024xf16>
  "onnx.Return"(%0) : (tensor<4x1024xf16>) -> ()
}

// -----

func.func @min_three_inputs(%ctx: !hipsr.context, %a: tensor<4x1024xf16>,
                            %b: tensor<4x1024xf16>, %c: tensor<4x1024xf16>)
    -> tensor<4x1024xf16> {
  %0 = "onnx.Min"(%a, %b, %c)
      : (tensor<4x1024xf16>, tensor<4x1024xf16>, tensor<4x1024xf16>)
      -> tensor<4x1024xf16>
  "onnx.Return"(%0) : (tensor<4x1024xf16>) -> ()
}

// -----

func.func @min_three_inputs_broadcast(%ctx: !hipsr.context, %a: tensor<2x1xf16>,
                                      %b: tensor<1x3xf16>, %c: tensor<2x3xf16>)
    -> tensor<2x3xf16> {
  %0 = "onnx.Min"(%a, %b, %c)
      : (tensor<2x1xf16>, tensor<1x3xf16>, tensor<2x3xf16>) -> tensor<2x3xf16>
  "onnx.Return"(%0) : (tensor<2x3xf16>) -> ()
}

// -----

func.func @min_single_input(%ctx: !hipsr.context, %a: tensor<4x1024xf16>)
    -> tensor<4x1024xf16> {
  %0 = "onnx.Min"(%a) : (tensor<4x1024xf16>) -> tensor<4x1024xf16>
  "onnx.Return"(%0) : (tensor<4x1024xf16>) -> ()
}

// -----

func.func @min_broadcast(%ctx: !hipsr.context, %a: tensor<?x1024xf16>,
                         %b: tensor<1024xf16>) -> tensor<?x1024xf16> {
  %0 = "onnx.Min"(%a, %b) : (tensor<?x1024xf16>, tensor<1024xf16>)
      -> tensor<?x1024xf16>
  "onnx.Return"(%0) : (tensor<?x1024xf16>) -> ()
}
