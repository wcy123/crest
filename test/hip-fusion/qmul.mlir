// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --crest-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QMul fusion pattern: DQ + DQ → hip.mul → hip.quantize_linear → hip.qmul
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: dead ops (constants, DQ, mul) are retained because unregistered-dialect
// ops are not eligible for automatic DCE by the greedy rewriter.

// CHECK-LABEL: func.func @qmul
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[LHS:.*]]: tensor<1x128x32xi8>, %[[RHS:.*]]: tensor<32xi8>) -> tensor<1x128x32xi8> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<1x128x32xi8>
// CHECK:         %[[QMUL:.*]] = "hip.qmul"(%[[CTX]], %[[LHS]], %[[RHS]], %[[INIT]]) {lhs_scale = 2.500000e-01 : f32, lhs_zp = -12 : i64, output_scale = 1.250000e-01 : f32, output_zp = 4 : i64, rhs_scale = 5.000000e-01 : f32, rhs_zp = 9 : i64}
// CHECK-SAME:    : (!hip.context, tensor<1x128x32xi8>, tensor<32xi8>, tensor<1x128x32xi8>) -> tensor<1x128x32xi8>
// CHECK:         return %[[QMUL]] : tensor<1x128x32xi8>
func.func @qmul(%ctx: !hip.context,
                %lhs: tensor<1x128x32xi8>,
                %rhs: tensor<32xi8>) -> tensor<1x128x32xi8> {
  %lhs_scale = "hip.constant"() {value = dense<0.25>  : tensor<f32>} : () -> tensor<f32>
  %lhs_zp    = "hip.constant"() {value = dense<-12>   : tensor<i8>}  : () -> tensor<i8>
  %rhs_scale = "hip.constant"() {value = dense<0.5>   : tensor<f32>} : () -> tensor<f32>
  %rhs_zp    = "hip.constant"() {value = dense<9>     : tensor<i8>}  : () -> tensor<i8>
  %out_scale = "hip.constant"() {value = dense<0.125> : tensor<f32>} : () -> tensor<f32>
  %out_zp    = "hip.constant"() {value = dense<4>     : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<1x128x32xf32>
  %dq_lhs = "hip.dequantize_linear"(%ctx, %lhs, %lhs_scale, %lhs_zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x128x32xi8>, tensor<f32>, tensor<i8>, tensor<1x128x32xf32>)
      -> tensor<1x128x32xf32>

  %e1 = tensor.empty() : tensor<32xf32>
  %dq_rhs = "hip.dequantize_linear"(%ctx, %rhs, %rhs_scale, %rhs_zp, %e1)
      {axis = 0 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<32xi8>, tensor<f32>, tensor<i8>, tensor<32xf32>)
      -> tensor<32xf32>

  %e2 = tensor.empty() : tensor<1x128x32xf32>
  %product = "hip.mul"(%ctx, %dq_lhs, %dq_rhs, %e2)
      : (!hip.context, tensor<1x128x32xf32>, tensor<32xf32>, tensor<1x128x32xf32>)
      -> tensor<1x128x32xf32>

  %e3 = tensor.empty() : tensor<1x128x32xi8>
  %q = "hip.quantize_linear"(%ctx, %product, %out_scale, %out_zp, %e3)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x128x32xf32>, tensor<f32>, tensor<i8>, tensor<1x128x32xi8>)
      -> tensor<1x128x32xi8>

  return %q : tensor<1x128x32xi8>
}
