// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.Slice becomes hipsr.slice. Entries the compiler can read become
// attributes and the placeholder is normal; entries the graph computes stay a
// host operand and the placeholder is a barrier, whose region reads them.
// Rejected forms are in slice-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @strided_window(%arg0: !hipsr.context, %arg1: tensor<8x4xf16>) -> tensor<3x4xf16> {
// CHECK-NEXT:     %0 = "onnx.Constant"() {value = dense<1> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Constant"() {value = dense<7> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %2 = "onnx.Constant"() {value = dense<0> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %3 = "onnx.Constant"() {value = dense<2> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %4 = "onnx.Slice"(%arg1, %0, %1, %2, %3) : (tensor<8x4xf16>, tensor<1xi64>, tensor<1xi64>, tensor<1xi64>, tensor<1xi64>) -> tensor<3x4xf16>
// CHECK-NEXT:     "onnx.Return"(%4) : (tensor<3x4xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @computed_bound(%arg0: !hipsr.context, %arg1: tensor<8xf16>, %arg2: tensor<?x4096xf16>) -> tensor<?xf16> {
// CHECK-NEXT:     %0 = "onnx.Shape"(%arg2) {end = 1 : si64, start = 0 : si64} : (tensor<?x4096xf16>) -> tensor<1xi64>
// CHECK-NEXT:     %1 = "onnx.Constant"() {value = dense<0> : tensor<1xi64>} : () -> tensor<1xi64>
// CHECK-NEXT:     %2 = "onnx.NoValue"() {value} : () -> none
// CHECK-NEXT:     %3 = "onnx.Slice"(%arg1, %1, %0, %2, %2) : (tensor<8xf16>, tensor<1xi64>, tensor<1xi64>, none, none) -> tensor<?xf16>
// CHECK-NEXT:     "onnx.Return"(%3) : (tensor<?xf16>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// A constant window goes over as attributes, leaving the device constants the
// constant conversion made for dead-code elimination to drop. The placeholder
// takes only the data, and its shape region stays empty for
// hipsr-populate-shape-region.
func.func @strided_window(%ctx: !hipsr.context,
                          %data: tensor<8x4xf16>) -> tensor<3x4xf16> {
  %starts = "onnx.Constant"() {value = dense<1> : tensor<1xi64>} : () -> tensor<1xi64>
  %ends = "onnx.Constant"() {value = dense<7> : tensor<1xi64>} : () -> tensor<1xi64>
  %axes = "onnx.Constant"() {value = dense<0> : tensor<1xi64>} : () -> tensor<1xi64>
  %steps = "onnx.Constant"() {value = dense<2> : tensor<1xi64>} : () -> tensor<1xi64>
  %0 = "onnx.Slice"(%data, %starts, %ends, %axes, %steps)
      : (tensor<8x4xf16>, tensor<1xi64>, tensor<1xi64>, tensor<1xi64>,
         tensor<1xi64>) -> tensor<3x4xf16>
  "onnx.Return"(%0) : (tensor<3x4xf16>) -> ()
}

// -----

// A bound the graph computes stays an operand and leaves the sliced axis
// dynamic, so the init is a barrier placeholder holding the data and that one
// operand for its region to read. The barrier names the value the compute
// wrote, not the destination it was given, because its region reads the bound
// itself. `axes` and `steps` arrive as onnx.NoValue and get ONNX's defaults,
// the leading axis and a unit step.
func.func @computed_bound(%ctx: !hipsr.context, %data: tensor<8xf16>,
                          %other: tensor<?x4096xf16>) -> tensor<?xf16> {
  %ends = "onnx.Shape"(%other) {start = 0 : si64, end = 1 : si64}
      : (tensor<?x4096xf16>) -> tensor<1xi64>
  %starts = "onnx.Constant"() {value = dense<0> : tensor<1xi64>} : () -> tensor<1xi64>
  %none = "onnx.NoValue"() {value} : () -> none
  %0 = "onnx.Slice"(%data, %starts, %ends, %none, %none)
      : (tensor<8xf16>, tensor<1xi64>, tensor<1xi64>, none, none)
      -> tensor<?xf16>
  "onnx.Return"(%0) : (tensor<?xf16>) -> ()
}
