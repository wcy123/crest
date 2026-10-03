// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// Converts onnx.NonZero to hipsr.nonzero, the hipsr.copy_d2h that brings the
// count to the host, and the hipsr.compute that narrows the worst-case search
// destination. Rejected forms live in nonzero-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @nonzero_mask(%arg0: !hipsr.context, %arg1: tensor<?x?xi8>) -> tensor<2x?xi64> {
// CHECK-NEXT:     %0 = "onnx.NonZero"(%arg1) : (tensor<?x?xi8>) -> tensor<2x?xi64>
// CHECK-NEXT:     "onnx.Return"(%0) : (tensor<2x?xi64>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @static_capacity_rank_one(%arg0: !hipsr.context, %arg1: tensor<12xi1>) -> tensor<1x?xi64> {
// CHECK-NEXT:     %0 = "onnx.NonZero"(%arg1) : (tensor<12xi1>) -> tensor<1x?xi64>
// CHECK-NEXT:     "onnx.Return"(%0) : (tensor<1x?xi64>) -> ()
// CHECK-NEXT:   }
// CHECK-NEXT: }

// The search is DPS, so its placeholder stays empty for
// hipsr-populate-shape-region. The narrowing is a compute, so this fills the
// barrier region from the host copy of the count.
// A copy keeps the source shape, so the host destination forwards the shape of
// the search's count destination.
// The compute lists the count the barrier reads, so the two share a pool
// domain, and ignores it in the body.
func.func @nonzero_mask(%ctx: !hipsr.context,
                        %mask: tensor<?x?xi8>) -> tensor<2x?xi64> {
  %0 = "onnx.NonZero"(%mask) : (tensor<?x?xi8>) -> tensor<2x?xi64>
  "onnx.Return"(%0) : (tensor<2x?xi64>) -> ()
}

// -----

// A static input pins the worst case at its element count, so the search
// destination is static even though the published result stays dynamic. A
// rank-1 input names a position with a single row.
func.func @static_capacity_rank_one(%ctx: !hipsr.context,
                                    %mask: tensor<12xi1>) -> tensor<1x?xi64> {
  %0 = "onnx.NonZero"(%mask) : (tensor<12xi1>) -> tensor<1x?xi64>
  "onnx.Return"(%0) : (tensor<1x?xi64>) -> ()
}
