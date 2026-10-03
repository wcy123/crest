// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// Converts onnx.MatMul to hipsr.matmul (placeholder init, empty shape region).
// Two cases: a plain 2-D matmul and a 1-D-operand matmul (the rank-reducing
// ONNX case).
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @matmul_2d(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16, #hipsr.mem<device>>, %arg2: tensor<4096x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
// CHECK-NEXT:       %c1 = shape.const_size 1
// CHECK-NEXT:       %c0 = shape.const_size 0
// CHECK-NEXT:       %2 = shape.get_extent %arg3, %c1 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %3 = shape.get_extent %arg4, %c0 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %4 = shape.from_extents %2 : !shape.size
// CHECK-NEXT:       %5 = shape.from_extents %3 : !shape.size
// CHECK-NEXT:       %6 = shape.cstr_eq %4, %5 : !shape.shape, !shape.shape
// CHECK-NEXT:       %c0_0 = shape.const_size 0
// CHECK-NEXT:       %c0_1 = shape.const_size 0
// CHECK-NEXT:       %head, %tail = "shape.split_at"(%arg3, %c0_0) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
// CHECK-NEXT:       %head_2, %tail_3 = "shape.split_at"(%arg4, %c0_1) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
// CHECK-NEXT:       %7 = shape.cstr_broadcastable %head, %head_2 : !shape.shape, !shape.shape
// CHECK-NEXT:       %8 = shape.assuming_all %6, %7
// CHECK-NEXT:       %c0_4 = shape.const_size 0
// CHECK-NEXT:       %c1_5 = shape.const_size 1
// CHECK-NEXT:       %9 = shape.get_extent %arg3, %c0_4 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %10 = shape.get_extent %arg4, %c1_5 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %11 = shape.assuming %8 -> (!shape.shape) {
// CHECK-NEXT:         %12 = shape.broadcast %head, %head_2 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:         %13 = shape.from_extents %9, %10 : !shape.size, !shape.size
// CHECK-NEXT:         %14 = shape.concat %12, %13 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:         shape.assuming_yield %14 : !shape.shape
// CHECK-NEXT:       }
// CHECK-NEXT:       "hipsr.shape_yield"(%11) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.matmul"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096x1024xf16, #hipsr.mem<device>>, tensor<?x1024xf16, #hipsr.mem<device>>) -> tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x1024xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @matmul_1d_rhs(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16, #hipsr.mem<device>>, %arg2: tensor<4096xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %arg2) ({
// CHECK-NEXT:     ^bb0(%arg3: !shape.shape, %arg4: !shape.shape):
// CHECK-NEXT:       %c1 = shape.const_size 1
// CHECK-NEXT:       %c0 = shape.const_size 0
// CHECK-NEXT:       %2 = shape.get_extent %arg3, %c1 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %3 = shape.get_extent %arg4, %c0 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %4 = shape.from_extents %2 : !shape.size
// CHECK-NEXT:       %5 = shape.from_extents %3 : !shape.size
// CHECK-NEXT:       %6 = shape.cstr_eq %4, %5 : !shape.shape, !shape.shape
// CHECK-NEXT:       %c0_0 = shape.const_size 0
// CHECK-NEXT:       %c0_1 = shape.const_size 0
// CHECK-NEXT:       %head, %tail = "shape.split_at"(%arg3, %c0_0) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
// CHECK-NEXT:       %head_2, %tail_3 = "shape.split_at"(%arg4, %c0_1) : (!shape.shape, !shape.size) -> (!shape.shape, !shape.shape)
// CHECK-NEXT:       %7 = shape.cstr_broadcastable %head, %head_2 : !shape.shape, !shape.shape
// CHECK-NEXT:       %8 = shape.assuming_all %6, %7
// CHECK-NEXT:       %c0_4 = shape.const_size 0
// CHECK-NEXT:       %c0_5 = shape.const_size 0
// CHECK-NEXT:       %9 = shape.get_extent %arg3, %c0_4 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %10 = shape.get_extent %arg4, %c0_5 : !shape.shape, !shape.size -> !shape.size
// CHECK-NEXT:       %11 = shape.assuming %8 -> (!shape.shape) {
// CHECK-NEXT:         %12 = shape.broadcast %head, %head_2 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:         %13 = shape.from_extents %9, %10 : !shape.size, !shape.size
// CHECK-NEXT:         %14 = shape.concat %12, %13 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:         shape.assuming_yield %14 : !shape.shape
// CHECK-NEXT:       }
// CHECK-NEXT:       "hipsr.shape_yield"(%11) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.matmul"(%arg0, %arg1, %arg2, %0) : (!hipsr.context, tensor<?x4096xf16, #hipsr.mem<device>>, tensor<4096xf16, #hipsr.mem<device>>, tensor<?xf16, #hipsr.mem<device>>) -> tensor<?xf16, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// 2-D x 2-D (dynamic M).
func.func @matmul_2d(%ctx: !hipsr.context, %a: tensor<?x4096xf16>,
                     %b: tensor<4096x1024xf16>) -> tensor<?x1024xf16> {
  %0 = "onnx.MatMul"(%a, %b) : (tensor<?x4096xf16>, tensor<4096x1024xf16>)
      -> tensor<?x1024xf16>
  "onnx.Return"(%0) : (tensor<?x1024xf16>) -> ()
}

// -----

// 1-D B: (M,K) @ (K) -> (M), a rank-reducing result mirrored as-is.
func.func @matmul_1d_rhs(%ctx: !hipsr.context, %a: tensor<?x4096xf16>,
                         %b: tensor<4096xf16>) -> tensor<?xf16> {
  %0 = "onnx.MatMul"(%a, %b) : (tensor<?x4096xf16>, tensor<4096xf16>)
      -> tensor<?xf16>
  "onnx.Return"(%0) : (tensor<?xf16>) -> ()
}
