// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --crest-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QGemm fusion patterns: DQ + DQ [+ DQ] → hip.gemm → Q → hip.qgemm
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: dead ops are retained because unregistered-dialect ops skip DCE.
//
// ui16 zero-point values are stored as i64 with two's-complement sign extension:
//   35275 → -30261 (35275 - 65536), 36322 → -29214 (36322 - 65536)
// Similarly for ui8: 128 → -128 (128 - 256), 200 → -56 (200 - 256)

// transB=1 reads B as [N, K], so Y is [64, 32]; the rank-1 C broadcasts along
// M. transA keeps its default and so is elided on print, as is B_bits at 8.
// CHECK-LABEL: func.func @qgemm
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<64x128xi8>, %[[B:.*]]: tensor<32x128xi8>, %[[C:.*]]: tensor<32xi8>) -> tensor<64x32xi8> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<64x32xi8>
// CHECK:         %[[QGEMM:.*]] = "hip.qgemm"(%[[CTX]], %[[A]], %[[B]], %[[C]], %[[INIT]]) {A_scale = 2.500000e-01 : f32, A_zero_point = -5 : i64, B_bits = 8 : i64, B_scale = 1.250000e-01 : f32, B_zero_point = 3 : i64, C_scale = 3.125000e-02 : f32, C_zero_point = -2 : i64, Y_scale = 5.000000e-01 : f32, Y_zero_point = 7 : i64, alpha = 2.000000e+00 : f32, beta = 5.000000e-01 : f32, operandSegmentSizes = array<i32: 1, 1, 1, 0, 0, 1, 1>, transA = 0 : i64, transB = 1 : i64}
// CHECK-SAME:    : (!hip.context, tensor<64x128xi8>, tensor<32x128xi8>, tensor<32xi8>, tensor<64x32xi8>) -> tensor<64x32xi8>
// CHECK:         return %[[QGEMM]] : tensor<64x32xi8>
func.func @qgemm(%ctx: !hip.context,
                 %a: tensor<64x128xi8>,
                 %b: tensor<32x128xi8>,
                 %c: tensor<32xi8>) -> tensor<64x32xi8> {
  %a_scale = "hip.constant"() {value = dense<0.25>    : tensor<f32>} : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<-5>      : tensor<i8>}  : () -> tensor<i8>
  %b_scale = "hip.constant"() {value = dense<0.125>   : tensor<f32>} : () -> tensor<f32>
  %b_zp    = "hip.constant"() {value = dense<3>       : tensor<i8>}  : () -> tensor<i8>
  %c_scale = "hip.constant"() {value = dense<0.03125> : tensor<f32>} : () -> tensor<f32>
  %c_zp    = "hip.constant"() {value = dense<-2>      : tensor<i8>}  : () -> tensor<i8>
  %y_scale = "hip.constant"() {value = dense<0.5>     : tensor<f32>} : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<7>       : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<64x128xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<64x128xi8>, tensor<f32>, tensor<i8>, tensor<64x128xf32>)
      -> tensor<64x128xf32>

  %e1 = tensor.empty() : tensor<32x128xf32>
  %dq_b = "hip.dequantize_linear"(%ctx, %b, %b_scale, %b_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<32x128xi8>, tensor<f32>, tensor<i8>, tensor<32x128xf32>)
      -> tensor<32x128xf32>

  %e2 = tensor.empty() : tensor<32xf32>
  %dq_c = "hip.dequantize_linear"(%ctx, %c, %c_scale, %c_zp, %e2)
      {axis = 0 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<32xi8>, tensor<f32>, tensor<i8>, tensor<32xf32>)
      -> tensor<32xf32>

  %e3 = tensor.empty() : tensor<64x32xf32>
  %gemm = "hip.gemm"(%ctx, %dq_a, %dq_b, %dq_c, %e3)
      {alpha = 2.000000e+00 : f32, beta = 5.000000e-01 : f32,
       transA = 0 : i64, transB = 1 : i64}
      : (!hip.context, tensor<64x128xf32>, tensor<32x128xf32>, tensor<32xf32>, tensor<64x32xf32>)
      -> tensor<64x32xf32>

  %e4 = tensor.empty() : tensor<64x32xi8>
  %q = "hip.quantize_linear"(%ctx, %gemm, %y_scale, %y_zp, %e4)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<64x32xf32>, tensor<f32>, tensor<i8>, tensor<64x32xi8>)
      -> tensor<64x32xi8>

  return %q : tensor<64x32xi8>
}

// -----

// The bias-free form leaves C_scale / C_zero_point / beta unset.
// A ui8 activation also exercises the unsigned zero-point read.
// CHECK-LABEL: func.func @qgemm_no_bias
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<16x64xui8>, %[[B:.*]]: tensor<64x8xi8>) -> tensor<16x8xui8> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<16x8xui8>
// CHECK:         %[[QGEMM:.*]] = "hip.qgemm"(%[[CTX]], %[[A]], %[[B]], %[[INIT]]) {A_scale = 5.000000e-01 : f32, A_zero_point = -128 : i64, B_bits = 8 : i64, B_scale = 2.500000e-01 : f32, B_zero_point = -3 : i64, Y_scale = 1.250000e-01 : f32, Y_zero_point = -56 : i64, alpha = 1.000000e+00 : f32, operandSegmentSizes = array<i32: 1, 1, 1, 0, 0, 0, 1>, transA = 0 : i64, transB = 0 : i64}
// CHECK-SAME:    : (!hip.context, tensor<16x64xui8>, tensor<64x8xi8>, tensor<16x8xui8>) -> tensor<16x8xui8>
// CHECK:         return %[[QGEMM]] : tensor<16x8xui8>
func.func @qgemm_no_bias(%ctx: !hip.context,
                         %a: tensor<16x64xui8>,
                         %b: tensor<64x8xi8>) -> tensor<16x8xui8> {
  %a_scale = "hip.constant"() {value = dense<0.5>   : tensor<f32>}  : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<128>   : tensor<ui8>}  : () -> tensor<ui8>
  %b_scale = "hip.constant"() {value = dense<0.25>  : tensor<f32>}  : () -> tensor<f32>
  %b_zp    = "hip.constant"() {value = dense<-3>    : tensor<i8>}   : () -> tensor<i8>
  %y_scale = "hip.constant"() {value = dense<0.125> : tensor<f32>}  : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<200>   : tensor<ui8>}  : () -> tensor<ui8>

  %e0 = tensor.empty() : tensor<16x64xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<16x64xui8>, tensor<f32>, tensor<ui8>, tensor<16x64xf32>)
      -> tensor<16x64xf32>

  %e1 = tensor.empty() : tensor<64x8xf32>
  %dq_b = "hip.dequantize_linear"(%ctx, %b, %b_scale, %b_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<64x8xi8>, tensor<f32>, tensor<i8>, tensor<64x8xf32>)
      -> tensor<64x8xf32>

  %e2 = tensor.empty() : tensor<16x8xf32>
  %gemm = "hip.gemm"(%ctx, %dq_a, %dq_b, %e2)
      {alpha = 1.000000e+00 : f32, beta = 1.000000e+00 : f32,
       transA = 0 : i64, transB = 0 : i64}
      : (!hip.context, tensor<16x64xf32>, tensor<64x8xf32>, tensor<16x8xf32>)
      -> tensor<16x8xf32>

  %e3 = tensor.empty() : tensor<16x8xui8>
  %q = "hip.quantize_linear"(%ctx, %gemm, %y_scale, %y_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<16x8xf32>, tensor<f32>, tensor<ui8>, tensor<16x8xui8>)
      -> tensor<16x8xui8>

  return %q : tensor<16x8xui8>
}

// -----

// A16W4 quantized per output feature, with an int32 bias at a symmetric zero
// point. transB=1 reads B as [N, K], which puts the feature axis at 0.
// CHECK-LABEL: func.func @qgemm_per_channel_w4
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<8x32xui16>, %[[C:.*]]: tensor<16xi32>) -> tensor<8x16xui16> {
// CHECK:         %[[B:.*]] = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 256 : i64} : () -> tensor<16x32xi8>
// CHECK:         %[[BZP:.*]] = "hip.constant"() {location = "w.bin", offset = 256 : i64, size = 8 : i64} : () -> tensor<16xi8>
// CHECK:         %[[BSCALE:.*]] = "hip.constant"() {location = "w.bin", offset = 264 : i64, size = 64 : i64} : () -> tensor<16xf32>
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<8x16xui16>
// CHECK:         %[[QGEMM:.*]] = "hip.qgemm"(%[[CTX]], %[[A]], %[[B]], %[[BSCALE]], %[[BZP]], %[[C]], %[[INIT]]) {A_scale = 1.250000e-01 : f32, A_zero_point = -30261 : i64, B_bits = 4 : i64, C_scale = 3.125000e-02 : f32, C_zero_point = 0 : i64, Y_scale = 2.500000e-01 : f32, Y_zero_point = -29214 : i64, alpha = 1.000000e+00 : f32, beta = 1.000000e+00 : f32, operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1>, transA = 0 : i64, transB = 1 : i64}
// CHECK-SAME:    : (!hip.context, tensor<8x32xui16>, tensor<16x32xi8>, tensor<16xf32>, tensor<16xi8>, tensor<16xi32>, tensor<8x16xui16>) -> tensor<8x16xui16>
// CHECK:         return %[[QGEMM]] : tensor<8x16xui16>
func.func @qgemm_per_channel_w4(%ctx: !hip.context,
                                %a: tensor<8x32xui16>,
                                %c: tensor<16xi32>) -> tensor<8x16xui16> {
  %b       = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 256 : i64} : () -> tensor<16x32xi8>
  %b_zp    = "hip.constant"() {location = "w.bin", offset = 256 : i64, size = 8 : i64} : () -> tensor<16xi8>
  %b_scale = "hip.constant"() {location = "w.bin", offset = 264 : i64, size = 64 : i64} : () -> tensor<16xf32>
  %a_scale = "hip.constant"() {value = dense<0.125>   : tensor<f32>}  : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<35275>   : tensor<ui16>} : () -> tensor<ui16>
  %c_scale = "hip.constant"() {value = dense<0.03125> : tensor<f32>}  : () -> tensor<f32>
  %c_zp    = "hip.constant"() {value = dense<0>       : tensor<i32>}  : () -> tensor<i32>
  %y_scale = "hip.constant"() {value = dense<0.25>    : tensor<f32>}  : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<36322>   : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<8x32xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<8x32xui16>, tensor<f32>, tensor<ui16>, tensor<8x32xf32>)
      -> tensor<8x32xf32>

  %e1 = tensor.empty() : tensor<16x32xf32>
  %dq_b = "hip.dequantize_linear"(%ctx, %b, %b_scale, %b_zp, %e1)
      {axis = 0 : i64, block_size = 0 : i64, packed_int4}
      : (!hip.context, tensor<16x32xi8>, tensor<16xf32>, tensor<16xi8>, tensor<16x32xf32>)
      -> tensor<16x32xf32>

  %e2 = tensor.empty() : tensor<16xf32>
  %dq_c = "hip.dequantize_linear"(%ctx, %c, %c_scale, %c_zp, %e2)
      {axis = 0 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<16xi32>, tensor<f32>, tensor<i32>, tensor<16xf32>)
      -> tensor<16xf32>

  %e3 = tensor.empty() : tensor<8x16xf32>
  %gemm = "hip.gemm"(%ctx, %dq_a, %dq_b, %dq_c, %e3)
      {alpha = 1.000000e+00 : f32, beta = 1.000000e+00 : f32,
       transA = 0 : i64, transB = 1 : i64}
      : (!hip.context, tensor<8x32xf32>, tensor<16x32xf32>, tensor<16xf32>, tensor<8x16xf32>)
      -> tensor<8x16xf32>

  %e4 = tensor.empty() : tensor<8x16xui16>
  %q = "hip.quantize_linear"(%ctx, %gemm, %y_scale, %y_zp, %e4)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<8x16xf32>, tensor<f32>, tensor<ui16>, tensor<8x16xui16>)
      -> tensor<8x16xui16>

  return %q : tensor<8x16xui16>
}

// -----

// Per-feature weights need not be 4-bit: without the packed_int4 marker
// B_bits stays at its 8 default and is elided. transB is 0 here.
// CHECK-LABEL: func.func @qgemm_per_channel_w8_no_bias
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<4x6xi8>) -> tensor<4x3xi8> {
// CHECK:         %[[B:.*]] = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 18 : i64} : () -> tensor<6x3xi8>
// CHECK:         %[[BZP:.*]] = "hip.constant"() {location = "w.bin", offset = 18 : i64, size = 3 : i64} : () -> tensor<3xi8>
// CHECK:         %[[BSCALE:.*]] = "hip.constant"() {location = "w.bin", offset = 24 : i64, size = 12 : i64} : () -> tensor<3xf32>
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<4x3xi8>
// CHECK:         %[[QGEMM:.*]] = "hip.qgemm"(%[[CTX]], %[[A]], %[[B]], %[[BSCALE]], %[[BZP]], %[[INIT]]) {A_scale = 5.000000e-01 : f32, A_zero_point = -5 : i64, B_bits = 8 : i64, Y_scale = 1.250000e-01 : f32, Y_zero_point = 7 : i64, alpha = 1.000000e+00 : f32, operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 0, 1>, transA = 0 : i64, transB = 0 : i64}
// CHECK-SAME:    : (!hip.context, tensor<4x6xi8>, tensor<6x3xi8>, tensor<3xf32>, tensor<3xi8>, tensor<4x3xi8>) -> tensor<4x3xi8>
// CHECK:         return %[[QGEMM]] : tensor<4x3xi8>
func.func @qgemm_per_channel_w8_no_bias(%ctx: !hip.context,
                                        %a: tensor<4x6xi8>) -> tensor<4x3xi8> {
  %b       = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 18 : i64} : () -> tensor<6x3xi8>
  %b_zp    = "hip.constant"() {location = "w.bin", offset = 18 : i64, size = 3 : i64} : () -> tensor<3xi8>
  %b_scale = "hip.constant"() {location = "w.bin", offset = 24 : i64, size = 12 : i64} : () -> tensor<3xf32>
  %a_scale = "hip.constant"() {value = dense<0.5>   : tensor<f32>} : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<-5>    : tensor<i8>}  : () -> tensor<i8>
  %y_scale = "hip.constant"() {value = dense<0.125> : tensor<f32>} : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<7>     : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<4x6xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<4x6xi8>, tensor<f32>, tensor<i8>, tensor<4x6xf32>)
      -> tensor<4x6xf32>

  %e1 = tensor.empty() : tensor<6x3xf32>
  %dq_b = "hip.dequantize_linear"(%ctx, %b, %b_scale, %b_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<6x3xi8>, tensor<3xf32>, tensor<3xi8>, tensor<6x3xf32>)
      -> tensor<6x3xf32>

  %e2 = tensor.empty() : tensor<4x3xf32>
  %gemm = "hip.gemm"(%ctx, %dq_a, %dq_b, %e2)
      {alpha = 1.000000e+00 : f32, beta = 1.000000e+00 : f32,
       transA = 0 : i64, transB = 0 : i64}
      : (!hip.context, tensor<4x6xf32>, tensor<6x3xf32>, tensor<4x3xf32>)
      -> tensor<4x3xf32>

  %e3 = tensor.empty() : tensor<4x3xi8>
  %q = "hip.quantize_linear"(%ctx, %gemm, %y_scale, %y_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<4x3xf32>, tensor<f32>, tensor<i8>, tensor<4x3xi8>)
      -> tensor<4x3xi8>

  return %q : tensor<4x3xi8>
}
