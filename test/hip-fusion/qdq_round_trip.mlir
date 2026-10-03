// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// RUN: %crest-opt -allow-unregistered-dialect --crest-pass="module=passes/hip-fusion" --split-input-file %s | %FileCheck %s

// Tests the QDQ round-trip elimination: Q(layout(DQ(x))) → layout(x) when Q/DQ params match.
// Written in generic MLIR op format so no hip dialect registration is required.
// Note: unregistered ops (hip.*) and dead ops survive since DCE skips unregistered-dialect ops.
//
// A layout op only moves elements, so with identical parameters on both ends
// the Q/DQ pair is a no-op and the op can run on the quantized tensor.
// Every case here therefore expects the dequantize and the quantize to be gone.
// The two negative cases at the end are the same chains with one parameter perturbed.
//
// For hip.transpose (DPS op): the cloned op in generic form has all operands explicit.
// For tensor.{collapse,expand}_shape: these are registered ops and stay in custom assembly.

// hip.transpose is a DPS op, so the rebuilt copy needs a fresh init carrying
// the quantized element type.
// CHECK-LABEL: func.func @qdq_transpose
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<1x2x3x4xui16>) -> tensor<1x3x2x4xui16> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<1x3x2x4xui16>
// CHECK:         %[[T:.*]] = "hip.transpose"(%[[CTX]], %[[X]], %[[INIT]]) {perm = [0, 2, 1, 3]}
// CHECK-SAME:    : (!hip.context, tensor<1x2x3x4xui16>, tensor<1x3x2x4xui16>) -> tensor<1x3x2x4xui16>
// CHECK:         return %[[T]] : tensor<1x3x2x4xui16>
func.func @qdq_transpose(%ctx: !hip.context,
                         %x: tensor<1x2x3x4xui16>) -> tensor<1x3x2x4xui16> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<1x2x3x4xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<1x2x3x4xui16>, tensor<f32>, tensor<ui16>, tensor<1x2x3x4xf32>)
      -> tensor<1x2x3x4xf32>

  %e1 = tensor.empty() : tensor<1x3x2x4xf32>
  %t = "hip.transpose"(%ctx, %dq, %e1) {perm = [0, 2, 1, 3]}
      : (!hip.context, tensor<1x2x3x4xf32>, tensor<1x3x2x4xf32>)
      -> tensor<1x3x2x4xf32>

  %e2 = tensor.empty() : tensor<1x3x2x4xui16>
  %q = "hip.quantize_linear"(%ctx, %t, %scale, %zp, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<1x3x2x4xf32>, tensor<f32>, tensor<ui16>, tensor<1x3x2x4xui16>)
      -> tensor<1x3x2x4xui16>

  return %q : tensor<1x3x2x4xui16>
}

// -----

// onnx.Squeeze, Reshape and Flatten all converge on tensor.collapse_shape, so
// one case covers what took three patterns at the ONNX layer. Being pure
// metadata it carries no init, only a reassociation that survives untouched.
// CHECK-LABEL: func.func @qdq_collapse_shape
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<2x1x3xui16>) -> tensor<2x3xui16> {
// CHECK:         %[[C:.*]] = tensor.collapse_shape %[[X]] {{\[}}[0, 1], [2]] : tensor<2x1x3xui16> into tensor<2x3xui16>
// CHECK:         return %[[C]] : tensor<2x3xui16>
func.func @qdq_collapse_shape(%ctx: !hip.context,
                              %x: tensor<2x1x3xui16>) -> tensor<2x3xui16> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<2x1x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x1x3xui16>, tensor<f32>, tensor<ui16>, tensor<2x1x3xf32>)
      -> tensor<2x1x3xf32>

  %c = tensor.collapse_shape %dq [[0, 1], [2]]
      : tensor<2x1x3xf32> into tensor<2x3xf32>

  %e1 = tensor.empty() : tensor<2x3xui16>
  %q = "hip.quantize_linear"(%ctx, %c, %scale, %zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<2x3xf32>, tensor<f32>, tensor<ui16>, tensor<2x3xui16>)
      -> tensor<2x3xui16>

  return %q : tensor<2x3xui16>
}

// -----

// The expanding direction, where output_shape also has to carry over.
// CHECK-LABEL: func.func @qdq_expand_shape
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<2x3xui16>) -> tensor<2x1x3xui16> {
// CHECK:         %[[E:.*]] = tensor.expand_shape %[[X]] {{\[}}[0, 1], [2]] output_shape [2, 1, 3] : tensor<2x3xui16> into tensor<2x1x3xui16>
// CHECK:         return %[[E]] : tensor<2x1x3xui16>
func.func @qdq_expand_shape(%ctx: !hip.context,
                            %x: tensor<2x3xui16>) -> tensor<2x1x3xui16> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<2x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x3xui16>, tensor<f32>, tensor<ui16>, tensor<2x3xf32>)
      -> tensor<2x3xf32>

  %e = tensor.expand_shape %dq [[0, 1], [2]] output_shape [2, 1, 3]
      : tensor<2x3xf32> into tensor<2x1x3xf32>

  %e1 = tensor.empty() : tensor<2x1x3xui16>
  %q = "hip.quantize_linear"(%ctx, %e, %scale, %zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<2x1x3xf32>, tensor<f32>, tensor<ui16>, tensor<2x1x3xui16>)
      -> tensor<2x1x3xui16>

  return %q : tensor<2x1x3xui16>
}

// -----

// onnx.Identity is replaced by its operand during conversion, so what used to
// be a three-op chain arrives as an adjacent pair with nothing between it.
// There is no op left to rebuild: the quantize's users read the dequantize's
// input directly.
// CHECK-LABEL: func.func @qdq_pair
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<2x3xui16>) -> tensor<2x3xui16> {
// CHECK:         return %[[X]] : tensor<2x3xui16>
func.func @qdq_pair(%ctx: !hip.context,
                    %x: tensor<2x3xui16>) -> tensor<2x3xui16> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<2x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x3xui16>, tensor<f32>, tensor<ui16>, tensor<2x3xf32>)
      -> tensor<2x3xf32>

  %e1 = tensor.empty() : tensor<2x3xui16>
  %q = "hip.quantize_linear"(%ctx, %dq, %scale, %zp, %e1)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<2x3xf32>, tensor<f32>, tensor<ui16>, tensor<2x3xui16>)
      -> tensor<2x3xui16>

  return %q : tensor<2x3xui16>
}

// -----

// Signed 8-bit storage takes the same path: the elimination leans on the
// layout op's own lowering, which is width-agnostic.
// CHECK-LABEL: func.func @qdq_transpose_i8
// CHECK-SAME:  (%[[CTX:.*]]: !hip.context, %[[X:.*]]: tensor<2x3xi8>) -> tensor<3x2xi8> {
// CHECK:         %[[INIT:.*]] = tensor.empty() : tensor<3x2xi8>
// CHECK:         %[[T:.*]] = "hip.transpose"(%[[CTX]], %[[X]], %[[INIT]]) {perm = [1, 0]}
// CHECK-SAME:    : (!hip.context, tensor<2x3xi8>, tensor<3x2xi8>) -> tensor<3x2xi8>
// CHECK:         return %[[T]] : tensor<3x2xi8>
func.func @qdq_transpose_i8(%ctx: !hip.context,
                            %x: tensor<2x3xi8>) -> tensor<3x2xi8> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>} : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<-5>           : tensor<i8>}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<2x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x3xi8>, tensor<f32>, tensor<i8>, tensor<2x3xf32>)
      -> tensor<2x3xf32>

  %e1 = tensor.empty() : tensor<3x2xf32>
  %t = "hip.transpose"(%ctx, %dq, %e1) {perm = [1, 0]}
      : (!hip.context, tensor<2x3xf32>, tensor<3x2xf32>)
      -> tensor<3x2xf32>

  %e2 = tensor.empty() : tensor<3x2xi8>
  %q = "hip.quantize_linear"(%ctx, %t, %scale, %zp, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 8 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<3x2xf32>, tensor<f32>, tensor<i8>, tensor<3x2xi8>)
      -> tensor<3x2xi8>

  return %q : tensor<3x2xi8>
}

// -----

// Different scales make the pair a real requantization, not a round trip, so
// all three ops have to survive. In generic format they stay as unregistered ops.
// CHECK-LABEL: func.func @different_scale_stays_unfused
// CHECK:         "hip.dequantize_linear"
// CHECK:         "hip.transpose"
// CHECK:         "hip.quantize_linear"
func.func @different_scale_stays_unfused(%ctx: !hip.context,
                                         %x: tensor<2x3xui16>) -> tensor<3x2xui16> {
  %in_s  = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %out_s = "hip.constant"() {value = dense<2.500000e-01> : tensor<f32>}  : () -> tensor<f32>
  %zp    = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<2x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %in_s, %zp, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x3xui16>, tensor<f32>, tensor<ui16>, tensor<2x3xf32>)
      -> tensor<2x3xf32>

  %e1 = tensor.empty() : tensor<3x2xf32>
  %t = "hip.transpose"(%ctx, %dq, %e1) {perm = [1, 0]}
      : (!hip.context, tensor<2x3xf32>, tensor<3x2xf32>)
      -> tensor<3x2xf32>

  %e2 = tensor.empty() : tensor<3x2xui16>
  %q = "hip.quantize_linear"(%ctx, %t, %out_s, %zp, %e2)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<3x2xf32>, tensor<f32>, tensor<ui16>, tensor<3x2xui16>)
      -> tensor<3x2xui16>

  return %q : tensor<3x2xui16>
}

// -----

// Same for a shifted zero point: the codes come back offset by one, which a
// bare collapse_shape would not reproduce.
// CHECK-LABEL: func.func @different_zp_stays_unfused
// CHECK:         "hip.dequantize_linear"
// CHECK:         tensor.collapse_shape
// CHECK:         "hip.quantize_linear"
func.func @different_zp_stays_unfused(%ctx: !hip.context,
                                      %x: tensor<2x1x3xui16>) -> tensor<2x3xui16> {
  %scale = "hip.constant"() {value = dense<1.250000e-01> : tensor<f32>}  : () -> tensor<f32>
  %in_z  = "hip.constant"() {value = dense<32768>        : tensor<ui16>} : () -> tensor<ui16>
  %out_z = "hip.constant"() {value = dense<32769>        : tensor<ui16>} : () -> tensor<ui16>

  %e0 = tensor.empty() : tensor<2x1x3xf32>
  %dq = "hip.dequantize_linear"(%ctx, %x, %scale, %in_z, %e0)
      {axis = 1 : i64, block_size = 0 : i64}
      : (!hip.context, tensor<2x1x3xui16>, tensor<f32>, tensor<ui16>, tensor<2x1x3xf32>)
      -> tensor<2x1x3xf32>

  %c = tensor.collapse_shape %dq [[0, 1], [2]]
      : tensor<2x1x3xf32> into tensor<2x3xf32>

  %e1 = tensor.empty() : tensor<2x3xui16>
  %q = "hip.quantize_linear"(%ctx, %c, %scale, %out_z, %e1)
      {axis = 1 : i64, block_size = 0 : i64, precision = 16 : i64, saturate = 1 : i64}
      : (!hip.context, tensor<2x3xf32>, tensor<f32>, tensor<ui16>, tensor<2x3xui16>)
      -> tensor<2x3xui16>

  return %q : tensor<2x3xui16>
}
