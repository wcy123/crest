#!/usr/bin/env python3
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
"""Write an MLIR module of many copies of the qadd fusion input.

Usage: generate-module.py FUNCTIONS [--no-match] > module.mlir

Each function is the one of test/hip-fusion/qadd.mlir: two dequantize_linear ops, an add and a quantize_linear.
With the hip-fusion pass every function becomes one hip.qadd. With --no-match the add is a hip.sub, which no
pattern fuses: the patterns still run on every quantize_linear and fail, which measures the cost of a failed
attempt.
"""
import argparse
import sys

# Operations in one function: the func.func, six constants, four tensor.empty, two dequantize_linear, the add or sub,
# the quantize_linear and the return.
OPS_PER_FUNCTION = 16

FUNCTION = """\
func.func @qadd_{index}(%ctx: !hip.context,
                %lhs: tensor<1x128x32xi8>,
                %rhs: tensor<1x128x32xi8>) -> tensor<1x128x32xi8> {{
  %lhs_scale = "hip.constant"() {{value = dense<0.25> : tensor<f32>}} : () -> tensor<f32>
  %lhs_zp    = "hip.constant"() {{value = dense<-5>   : tensor<i8>}}  : () -> tensor<i8>
  %rhs_scale = "hip.constant"() {{value = dense<0.5>  : tensor<f32>}} : () -> tensor<f32>
  %rhs_zp    = "hip.constant"() {{value = dense<3>    : tensor<i8>}}  : () -> tensor<i8>
  %out_scale = "hip.constant"() {{value = dense<0.125>: tensor<f32>}} : () -> tensor<f32>
  %out_zp    = "hip.constant"() {{value = dense<7>    : tensor<i8>}}  : () -> tensor<i8>

  %e0 = tensor.empty() : tensor<1x128x32xf32>
  %dq_lhs = "hip.dequantize_linear"(%ctx, %lhs, %lhs_scale, %lhs_zp, %e0)
      {{axis = 1 : i64, block_size = 0 : i64, operandSegmentSizes = array<i32: 1, 1, 1, 1, 1>}}
      : (!hip.context, tensor<1x128x32xi8>, tensor<f32>, tensor<i8>, tensor<1x128x32xf32>)
      -> tensor<1x128x32xf32>

  %e1 = tensor.empty() : tensor<1x128x32xf32>
  %dq_rhs = "hip.dequantize_linear"(%ctx, %rhs, %rhs_scale, %rhs_zp, %e1)
      {{axis = 1 : i64, block_size = 0 : i64, operandSegmentSizes = array<i32: 1, 1, 1, 1, 1>}}
      : (!hip.context, tensor<1x128x32xi8>, tensor<f32>, tensor<i8>, tensor<1x128x32xf32>)
      -> tensor<1x128x32xf32>

  %e2 = tensor.empty() : tensor<1x128x32xf32>
  %sum = "{add_name}"(%ctx, %dq_lhs, %dq_rhs, %e2)
      : (!hip.context, tensor<1x128x32xf32>, tensor<1x128x32xf32>, tensor<1x128x32xf32>)
      -> tensor<1x128x32xf32>

  %e3 = tensor.empty() : tensor<1x128x32xi8>
  %q = "hip.quantize_linear"(%ctx, %sum, %out_scale, %out_zp, %e3)
      {{axis = 1 : i64, block_size = 0 : i64, operandSegmentSizes = array<i32: 1, 1, 1, 1, 1>, precision = 8 : i64, saturate = 1 : i64}}
      : (!hip.context, tensor<1x128x32xf32>, tensor<f32>, tensor<i8>, tensor<1x128x32xi8>)
      -> tensor<1x128x32xi8>

  return %q : tensor<1x128x32xi8>
}}
"""


def generate(functions, match=True):
    add_name = "hip.add" if match else "hip.sub"
    return "\n".join(
        FUNCTION.format(index=i, add_name=add_name) for i in range(functions)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("functions", type=int, help="number of functions")
    parser.add_argument(
        "--no-match", action="store_true", help="use hip.sub so that no pattern fuses"
    )
    args = parser.parse_args()
    sys.stdout.write(generate(args.functions, match=not args.no_match))


if __name__ == "__main__":
    main()
