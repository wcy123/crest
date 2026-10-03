// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --scheme-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QMatMul fusion patterns: DQ + DQ → hip.matmul → Q → hip.qmatmul
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: dead ops are retained because unregistered-dialect ops skip DCE.
//
// ui16 zero-point values are stored as i64 with two's-complement sign extension:
//   35275 → -30261 (35275 - 65536), 36322 → -29214 (36322 - 65536)

// Per-tensor B: both weight quantization parameters fold into attributes.
// CHECK-LABEL: func.func @qmatmul
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<64x128xi8>, %[[B:.*]]: tensor<128x32xi8>) -> tensor<64x32xi8> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<64x32xi8>
// CHECK:         %[[QMM:.*]] = "hip.qmatmul"(%[[CTX]], %[[A]], %[[B]], %[[INIT]]) {A_scale = 2.500000e-01 : f32, A_zero_point = -5 : i64, B_scale = 1.250000e-01 : f32, B_zero_point = 3 : i64, Y_scale = 5.000000e-01 : f32, Y_zero_point = 7 : i64, transA = 0 : i64, transB = 0 : i64}
// CHECK-SAME:    : (!hip.context, tensor<64x128xi8>, tensor<128x32xi8>, tensor<64x32xi8>) -> tensor<64x32xi8>
// CHECK:         return %[[QMM]] : tensor<64x32xi8>
func.func @qmatmul(%ctx: !hip.context,
                   %a: tensor<64x128xi8>,
                   %b: tensor<128x32xi8>) -> tensor<64x32xi8> {
  %a_scale = "hip.constant"() {value = dense<0.25>  : tensor<f32>} : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<-5>    : tensor<i8>}  : () -> tensor<i8>
  %b_scale = "hip.constant"() {value = dense<0.125> : tensor<f32>} : () -> tensor<f32>
  %b_zp    = "hip.constant"() {value = dense<3>     : tensor<i8>}  : () -> tensor<i8>
  %y_scale = "hip.constant"() {value = dense<0.5>   : tensor<f32>} : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<7>     : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<64x128xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<64x128xi8>, tensor<f32>, tensor<i8>, tensor<64x128xf32>)
      -> tensor<64x128xf32>

  %e1 = tensor.empty() : tensor<128x32xf32>
  %dq_b = "hip.dequantize_linear"(%ctx, %b, %b_scale, %b_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<128x32xi8>, tensor<f32>, tensor<i8>, tensor<128x32xf32>)
      -> tensor<128x32xf32>

  %e2 = tensor.empty() : tensor<64x32xf32>
  %prod = "hip.matmul"(%ctx, %dq_a, %dq_b, %e2)
      {transA = 0 : i64, transB = 0 : i64}
      : (!hip.context, tensor<64x128xf32>, tensor<128x32xf32>, tensor<64x32xf32>)
      -> tensor<64x32xf32>

  %e3 = tensor.empty() : tensor<64x32xi8>
  %q = "hip.quantize_linear"(%ctx, %prod, %y_scale, %y_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<64x32xf32>, tensor<f32>, tensor<i8>, tensor<64x32xi8>)
      -> tensor<64x32xi8>

  return %q : tensor<64x32xi8>
}

// -----

// A16 activation, packed INT4 weights quantized per output column. The weight
// scale and zero point stay operands, so their carriers survive the fusion.
// CHECK-LABEL: func.func @qmatmul_w4_per_column
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<4x8xui16>) -> tensor<4x6xui16> {
// CHECK:         %[[W:.*]] = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 24 : i64} : () -> tensor<8x6xi8>
// CHECK:         %[[WZP:.*]] = "hip.constant"() {location = "w.bin", offset = 24 : i64, size = 3 : i64} : () -> tensor<6xi8>
// CHECK:         %[[WSCALE:.*]] = "hip.constant"() {location = "w.bin", offset = 32 : i64, size = 24 : i64} : () -> tensor<6xf32>
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<4x6xui16>
// CHECK:         %[[QMM:.*]] = "hip.qmatmul"(%[[CTX]], %[[A]], %[[W]], %[[WSCALE]], %[[WZP]], %[[INIT]]) {A_scale = 1.638800e-04 : f32, A_zero_point = -30261 : i64, B_quant_axis = 1 : i64, Y_scale = 3.687020e-04 : f32, Y_zero_point = -29214 : i64, packed_int4, transA = 0 : i64, transB = 0 : i64}
// CHECK-SAME:    : (!hip.context, tensor<4x8xui16>, tensor<8x6xi8>, tensor<6xf32>, tensor<6xi8>, tensor<4x6xui16>) -> tensor<4x6xui16>
// CHECK:         return %[[QMM]] : tensor<4x6xui16>
func.func @qmatmul_w4_per_column(%ctx: !hip.context,
                                 %a: tensor<4x8xui16>) -> tensor<4x6xui16> {
  %w       = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 24 : i64} : () -> tensor<8x6xi8>
  %w_zp    = "hip.constant"() {location = "w.bin", offset = 24 : i64, size = 3 : i64} : () -> tensor<6xi8>
  %w_scale = "hip.constant"() {location = "w.bin", offset = 32 : i64, size = 24 : i64} : () -> tensor<6xf32>
  %a_scale = "hip.constant"() {value = dense<1.638800e-04> : tensor<f32>} : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<35275>        : tensor<ui16>} : () -> tensor<ui16>
  %y_scale = "hip.constant"() {value = dense<3.687020e-04> : tensor<f32>} : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<36322>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<4x8xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<4x8xui16>, tensor<f32>, tensor<ui16>, tensor<4x8xf32>)
      -> tensor<4x8xf32>

  %e1 = tensor.empty() : tensor<8x6xf32>
  %dq_w = "hip.dequantize_linear"(%ctx, %w, %w_scale, %w_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64, packed_int4}
      : (!hip.context, tensor<8x6xi8>, tensor<6xf32>, tensor<6xi8>, tensor<8x6xf32>)
      -> tensor<8x6xf32>

  %e2 = tensor.empty() : tensor<4x6xf32>
  %prod = "hip.matmul"(%ctx, %dq_a, %dq_w, %e2)
      {transA = 0 : i64, transB = 0 : i64}
      : (!hip.context, tensor<4x8xf32>, tensor<8x6xf32>, tensor<4x6xf32>)
      -> tensor<4x6xf32>

  %e3 = tensor.empty() : tensor<4x6xui16>
  %q = "hip.quantize_linear"(%ctx, %prod, %y_scale, %y_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<4x6xf32>, tensor<f32>, tensor<ui16>, tensor<4x6xui16>)
      -> tensor<4x6xui16>

  return %q : tensor<4x6xui16>
}

// -----

// The W4 case with full-width INT8 weights: same shapes, no packed_int4 marker
// on either the matched dequantize or the fused op.
// CHECK-LABEL: func.func @qmatmul_w8_per_column
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[A:.*]]: tensor<4x8xui16>) -> tensor<4x6xui16> {
// CHECK:         %[[W:.*]] = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 48 : i64} : () -> tensor<8x6xi8>
// CHECK:         %[[WZP:.*]] = "hip.constant"() {location = "w.bin", offset = 48 : i64, size = 6 : i64} : () -> tensor<6xi8>
// CHECK:         %[[WSCALE:.*]] = "hip.constant"() {location = "w.bin", offset = 56 : i64, size = 24 : i64} : () -> tensor<6xf32>
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<4x6xui16>
// CHECK:         %[[QMM:.*]] = "hip.qmatmul"(%[[CTX]], %[[A]], %[[W]], %[[WSCALE]], %[[WZP]], %[[INIT]]) {A_scale = 1.638800e-04 : f32, A_zero_point = -30261 : i64, B_quant_axis = 1 : i64, Y_scale = 3.687020e-04 : f32, Y_zero_point = -29214 : i64, transA = 0 : i64, transB = 0 : i64}
// CHECK-SAME:    : (!hip.context, tensor<4x8xui16>, tensor<8x6xi8>, tensor<6xf32>, tensor<6xi8>, tensor<4x6xui16>) -> tensor<4x6xui16>
// CHECK:         return %[[QMM]] : tensor<4x6xui16>
func.func @qmatmul_w8_per_column(%ctx: !hip.context,
                                 %a: tensor<4x8xui16>) -> tensor<4x6xui16> {
  %w       = "hip.constant"() {location = "w.bin", offset = 0 : i64, size = 48 : i64} : () -> tensor<8x6xi8>
  %w_zp    = "hip.constant"() {location = "w.bin", offset = 48 : i64, size = 6 : i64} : () -> tensor<6xi8>
  %w_scale = "hip.constant"() {location = "w.bin", offset = 56 : i64, size = 24 : i64} : () -> tensor<6xf32>
  %a_scale = "hip.constant"() {value = dense<1.638800e-04> : tensor<f32>} : () -> tensor<f32>
  %a_zp    = "hip.constant"() {value = dense<35275>        : tensor<ui16>} : () -> tensor<ui16>
  %y_scale = "hip.constant"() {value = dense<3.687020e-04> : tensor<f32>} : () -> tensor<f32>
  %y_zp    = "hip.constant"() {value = dense<36322>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<4x8xf32>
  %dq_a = "hip.dequantize_linear"(%ctx, %a, %a_scale, %a_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<4x8xui16>, tensor<f32>, tensor<ui16>, tensor<4x8xf32>)
      -> tensor<4x8xf32>

  %e1 = tensor.empty() : tensor<8x6xf32>
  %dq_w = "hip.dequantize_linear"(%ctx, %w, %w_scale, %w_zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<8x6xi8>, tensor<6xf32>, tensor<6xi8>, tensor<8x6xf32>)
      -> tensor<8x6xf32>

  %e2 = tensor.empty() : tensor<4x6xf32>
  %prod = "hip.matmul"(%ctx, %dq_a, %dq_w, %e2)
      {transA = 0 : i64, transB = 0 : i64}
      : (!hip.context, tensor<4x8xf32>, tensor<8x6xf32>, tensor<4x6xf32>)
      -> tensor<4x6xf32>

  %e3 = tensor.empty() : tensor<4x6xui16>
  %q = "hip.quantize_linear"(%ctx, %prod, %y_scale, %y_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<4x6xf32>, tensor<f32>, tensor<ui16>, tensor<4x6xui16>)
      -> tensor<4x6xui16>

  return %q : tensor<4x6xui16>
}
