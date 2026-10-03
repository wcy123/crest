// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --scheme-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QLpNormalization fusion pattern: DQ → hip.rms_norm → Q → hip.qlpnormalization
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: dead ops are retained because unregistered-dialect ops skip DCE.
//
// The middle op is hip.rms_norm rather than LpNormalization. The fusion is
// licensed by the identity rms_norm(x, 1/sqrt(N), 0) = L2(x), so the trailing
// extent is fixed at 64 and the rms scale is 1/sqrt(64) = 0.125.
//
// ui16 zero-point values are stored as i64 with two's-complement sign extension:
//   35189 → -30347 (35189 - 65536), 35274 → -30262 (35274 - 65536)

// CHECK-LABEL: func.func @qlpnormalization
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<1x128x64xui16>) -> tensor<1x128x64xui16> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<1x128x64xui16>
// CHECK:         %[[QLP:.*]] = "hip.qlpnormalization"(%[[CTX]], %[[X]], %[[INIT]]) {axis = -1 : i64, input_scale = 5.000000e-01 : f32, input_zp = -30347 : i64, output_scale = 2.500000e-01 : f32, output_zp = -30262 : i64, p = 2 : i64}
// CHECK-SAME:    : (!hip.context, tensor<1x128x64xui16>, tensor<1x128x64xui16>) -> tensor<1x128x64xui16>
// CHECK:         return %[[QLP]] : tensor<1x128x64xui16>
func.func @qlpnormalization(%ctx: !hip.context,
                            %x: tensor<1x128x64xui16>) -> tensor<1x128x64xui16> {
  %in_s  = "hip.constant"() {value = dense<5.000000e-01> : tensor<f32>}    : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<35189>        : tensor<ui16>}   : () -> tensor<ui16>
  %out_s = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>}    : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<35274>        : tensor<ui16>}   : () -> tensor<ui16>
  %rms_s = "hip.constant"() {value = dense<1.250000e-01> : tensor<64xf32>} : () -> tensor<64xf32>

  %e0 = tensor.empty() : tensor<1x128x64xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x64xui16>, tensor<f32>, tensor<ui16>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e1 = tensor.empty() : tensor<1x128x64xf32>
  %rms = "hip.rms_norm"(%ctx, %dq, %rms_s, %e1)
      {axis = -1 : i64, epsilon = 0.000000e+00 : f32, stash_type = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<64xf32>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e2 = tensor.empty() : tensor<1x128x64xui16>
  %q = "hip.quantize_linear"(%ctx, %rms, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<f32>, tensor<ui16>, tensor<1x128x64xui16>)
      -> tensor<1x128x64xui16>

  return %q : tensor<1x128x64xui16>
}

// -----

// A nonzero epsilon breaks the identity: the denominator is no longer the
// plain L2 norm. This is a genuine RMS norm that happens to sit in a Q/DQ
// sandwich, and hip.qlpnormalization has no epsilon to carry it over to.
// CHECK-LABEL: func.func @rms_norm_nonzero_epsilon_not_fused
// CHECK-NOT:   hip.qlpnormalization
func.func @rms_norm_nonzero_epsilon_not_fused(%ctx: !hip.context,
                                              %x: tensor<1x128x64xui16>) -> tensor<1x128x64xui16> {
  %in_s  = "hip.constant"() {value = dense<5.000000e-01> : tensor<f32>}    : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<35189>        : tensor<ui16>}   : () -> tensor<ui16>
  %out_s = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>}    : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<35274>        : tensor<ui16>}   : () -> tensor<ui16>
  %rms_s = "hip.constant"() {value = dense<1.250000e-01> : tensor<64xf32>} : () -> tensor<64xf32>

  %e0 = tensor.empty() : tensor<1x128x64xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x64xui16>, tensor<f32>, tensor<ui16>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e1 = tensor.empty() : tensor<1x128x64xf32>
  %rms = "hip.rms_norm"(%ctx, %dq, %rms_s, %e1)
      {axis = -1 : i64, epsilon = 9.99999974E-6 : f32, stash_type = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<64xf32>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e2 = tensor.empty() : tensor<1x128x64xui16>
  %q = "hip.quantize_linear"(%ctx, %rms, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<f32>, tensor<ui16>, tensor<1x128x64xui16>)
      -> tensor<1x128x64xui16>

  return %q : tensor<1x128x64xui16>
}

// -----

// Unit scale instead of 1/sqrt(64): still splat, still epsilon 0, but the
// result is rescaled by sqrt(N) against an L2 norm.
// CHECK-LABEL: func.func @rms_norm_unit_scale_not_fused
// CHECK-NOT:   hip.qlpnormalization
func.func @rms_norm_unit_scale_not_fused(%ctx: !hip.context,
                                         %x: tensor<1x128x64xui16>) -> tensor<1x128x64xui16> {
  %in_s  = "hip.constant"() {value = dense<5.000000e-01> : tensor<f32>}    : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<35189>        : tensor<ui16>}   : () -> tensor<ui16>
  %out_s = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>}    : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<35274>        : tensor<ui16>}   : () -> tensor<ui16>
  %rms_s = "hip.constant"() {value = dense<1.000000e+00> : tensor<64xf32>} : () -> tensor<64xf32>

  %e0 = tensor.empty() : tensor<1x128x64xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x64xui16>, tensor<f32>, tensor<ui16>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e1 = tensor.empty() : tensor<1x128x64xf32>
  %rms = "hip.rms_norm"(%ctx, %dq, %rms_s, %e1)
      {axis = -1 : i64, epsilon = 0.000000e+00 : f32, stash_type = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<64xf32>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e2 = tensor.empty() : tensor<1x128x64xui16>
  %q = "hip.quantize_linear"(%ctx, %rms, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<f32>, tensor<ui16>, tensor<1x128x64xui16>)
      -> tensor<1x128x64xui16>

  return %q : tensor<1x128x64xui16>
}

// -----

// hip.qlpnormalization is a UINT16 kernel, so signed 16-bit storage has no
// fused form to fall through to.
// CHECK-LABEL: func.func @qlpnormalization_i16_not_fused
// CHECK-NOT:   hip.qlpnormalization
func.func @qlpnormalization_i16_not_fused(%ctx: !hip.context,
                                          %x: tensor<1x128x64xi16>) -> tensor<1x128x64xi16> {
  %in_s  = "hip.constant"() {value = dense<5.000000e-01> : tensor<f32>}    : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<-1200>        : tensor<i16>}    : () -> tensor<i16>
  %out_s = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>}    : () -> tensor<f32>
  %out_z = "hip.constant"() {value = dense<-2300>        : tensor<i16>}    : () -> tensor<i16>
  %rms_s = "hip.constant"() {value = dense<1.250000e-01> : tensor<64xf32>} : () -> tensor<64xf32>

  %e0 = tensor.empty() : tensor<1x128x64xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x64xi16>, tensor<f32>, tensor<i16>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e1 = tensor.empty() : tensor<1x128x64xf32>
  %rms = "hip.rms_norm"(%ctx, %dq, %rms_s, %e1)
      {axis = -1 : i64, epsilon = 0.000000e+00 : f32, stash_type = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<64xf32>, tensor<1x128x64xf32>)
      -> tensor<1x128x64xf32>

  %e2 = tensor.empty() : tensor<1x128x64xi16>
  %q = "hip.quantize_linear"(%ctx, %rms, %out_s, %out_z, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x64xf32>, tensor<f32>, tensor<i16>, tensor<1x128x64xi16>)
      -> tensor<1x128x64xi16>

  return %q : tensor<1x128x64xi16>
}
