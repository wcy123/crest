// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --scheme-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QSigmoid fusion pattern: DQ → hip.sigmoid → Q → hip.qsigmoid
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: dead ops (constants, DQ, sigmoid) are retained because unregistered-dialect
// ops are not eligible for automatic DCE by the greedy rewriter.
//
// ui16 zero-point values are stored as i64 with two's-complement sign extension:
//   35189 → -30347 (35189 - 65536), 35274 → -30262 (35274 - 65536)

// Sigmoid changes values, so the input and output quantization parameters are
// deliberately different throughout: requantization is part of the fused op,
// and the checks have to prove both pairs reach the attributes.

// CHECK-LABEL: func.func @qsigmoid
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<1x128x2048xui16>) -> tensor<1x128x2048xui16> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<1x128x2048xui16>
// CHECK:         %[[QSIG:.*]] = "hip.qsigmoid"(%[[CTX]], %[[X]], %[[INIT]]) {input_scale = 1.000000e-01 : f32, input_zp = -30347 : i64, output_scale = 2.000000e-01 : f32, output_zp = -30262 : i64}
// CHECK-SAME:    : (!hip.context, tensor<1x128x2048xui16>, tensor<1x128x2048xui16>) -> tensor<1x128x2048xui16>
// CHECK:         return %[[QSIG]] : tensor<1x128x2048xui16>
func.func @qsigmoid(%ctx: !hip.context,
                    %x: tensor<1x128x2048xui16>) -> tensor<1x128x2048xui16> {
  %in_s  = "hip.constant"() {value = dense<1.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<35189> : tensor<ui16>} : () -> tensor<ui16>
  %out_s = "hip.constant"() {value = dense<2.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<35274> : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<1x128x2048xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x2048xui16>, tensor<f32>, tensor<ui16>, tensor<1x128x2048xf32>)
      -> tensor<1x128x2048xf32>

  %e1 = tensor.empty() : tensor<1x128x2048xf32>
  %s = "hip.sigmoid"(%ctx, %dq, %e1)
      : (!hip.context, tensor<1x128x2048xf32>, tensor<1x128x2048xf32>)
      -> tensor<1x128x2048xf32>

  %e2 = tensor.empty() : tensor<1x128x2048xui16>
  %q = "hip.quantize_linear"(%ctx, %s, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x2048xf32>, tensor<f32>, tensor<ui16>, tensor<1x128x2048xui16>)
      -> tensor<1x128x2048xui16>

  return %q : tensor<1x128x2048xui16>
}

// -----

// An 8-bit sandwich is not the supported width, and there is no 8-bit
// qsigmoid pattern for it to fall through to.
// CHECK-LABEL: func.func @qsigmoid_i8_not_fused
// CHECK-NOT:   hip.qsigmoid
func.func @qsigmoid_i8_not_fused(%ctx: !hip.context,
                                 %x: tensor<1x8x16xi8>) -> tensor<1x8x16xi8> {
  %in_s  = "hip.constant"() {value = dense<1.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<0>            : tensor<i8>}  : () -> tensor<i8>
  %out_s = "hip.constant"() {value = dense<2.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<1>            : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<1x8x16xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x8x16xi8>, tensor<f32>, tensor<i8>, tensor<1x8x16xf32>)
      -> tensor<1x8x16xf32>

  %e1 = tensor.empty() : tensor<1x8x16xf32>
  %s = "hip.sigmoid"(%ctx, %dq, %e1)
      : (!hip.context, tensor<1x8x16xf32>, tensor<1x8x16xf32>)
      -> tensor<1x8x16xf32>

  %e2 = tensor.empty() : tensor<1x8x16xi8>
  %q = "hip.quantize_linear"(%ctx, %s, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x8x16xf32>, tensor<f32>, tensor<i8>, tensor<1x8x16xi8>)
      -> tensor<1x8x16xi8>

  return %q : tensor<1x8x16xi8>
}

// -----

// A signed 16-bit sandwich has the supported width but not the supported
// signedness: it spans a different range and widens differently, so it stays
// unfused rather than reaching a wrap that reads the codes as unsigned.
// CHECK-LABEL: func.func @qsigmoid_i16_not_fused
// CHECK-NOT:   hip.qsigmoid
func.func @qsigmoid_i16_not_fused(%ctx: !hip.context,
                                  %x: tensor<1x8x16xi16>) -> tensor<1x8x16xi16> {
  %in_s  = "hip.constant"() {value = dense<1.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<-5>           : tensor<i16>} : () -> tensor<i16>
  %out_s = "hip.constant"() {value = dense<2.000000e-01> : tensor<f32>} : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<7>            : tensor<i16>} : () -> tensor<i16>

  %e0 = tensor.empty() : tensor<1x8x16xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x8x16xi16>, tensor<f32>, tensor<i16>, tensor<1x8x16xf32>)
      -> tensor<1x8x16xf32>

  %e1 = tensor.empty() : tensor<1x8x16xf32>
  %s = "hip.sigmoid"(%ctx, %dq, %e1)
      : (!hip.context, tensor<1x8x16xf32>, tensor<1x8x16xf32>)
      -> tensor<1x8x16xf32>

  %e2 = tensor.empty() : tensor<1x8x16xi16>
  %q = "hip.quantize_linear"(%ctx, %s, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x8x16xf32>, tensor<f32>, tensor<i16>, tensor<1x8x16xi16>)
      -> tensor<1x8x16xi16>

  return %q : tensor<1x8x16xi16>
}
