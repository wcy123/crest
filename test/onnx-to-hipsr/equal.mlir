// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.Equal becomes hipsr.equal with the i1 mask a comparison yields.
// Both operands must be on the device, so a host constant gets a device copy.
// Rejected forms are in equal-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK-NEXT:   func.func @host_scalar_on_device(%arg0: !hipsr.context, %arg1: tensor<?x?xi64, #hipsr.mem<device>>) -> tensor<?x?xi1, #hipsr.mem<device>> {
// CHECK-NEXT:     %cst = arith.constant dense<248056> : tensor<i64>
// CHECK-NEXT:     %0 = "hipsr.placeholder"(%arg0, %arg1, %cst) ({
// CHECK-NEXT:     ^bb0(%arg2: !shape.shape, %arg3: !shape.shape):
// CHECK-NEXT:       %2 = shape.broadcast %arg2, %arg3 : !shape.shape, !shape.shape -> !shape.shape
// CHECK-NEXT:       "hipsr.shape_yield"(%2) : (!shape.shape) -> ()
// CHECK-NEXT:     }) : (!hipsr.context, tensor<?x?xi64, #hipsr.mem<device>>, tensor<i64>) -> tensor<?x?xi1, #hipsr.mem<device>>
// CHECK-NEXT:     %1 = "hipsr.equal"(%arg0, %arg1, %cst, %0) : (!hipsr.context, tensor<?x?xi64, #hipsr.mem<device>>, tensor<i64>, tensor<?x?xi1, #hipsr.mem<device>>) -> tensor<?x?xi1, #hipsr.mem<device>>
// CHECK-NEXT:     return %1 : tensor<?x?xi1, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// An embedding graph holds the id it compares against as a rank-0 constant,
// which the constant conversion leaves on the host, so it gets a device
// constant of the same rank. The ids are already on the device and stay as
// they are. The placeholder gets no shape region here: hipsr.equal is DPS, so
// hipsr-populate-shape-region fills it in later.
// The host constant has no use left and waits for canonicalization.
func.func @host_scalar_on_device(%ctx: !hipsr.context, %ids: tensor<?x?xi64>)
    -> tensor<?x?xi1> {
  %0 = "onnx.Constant"() {value = dense<248056> : tensor<i64>}
      : () -> tensor<i64>
  %1 = "onnx.Equal"(%ids, %0) : (tensor<?x?xi64>, tensor<i64>) -> tensor<?x?xi1>
  "onnx.Return"(%1) : (tensor<?x?xi1>) -> ()
}
