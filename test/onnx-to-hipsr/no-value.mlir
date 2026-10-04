// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.NoValue stands in for an operand the exporter omitted. It stays legal
// through the conversion so each consumer can drop it, and the pass erases the
// placeholders left dead afterwards.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK-NEXT:   func.func @dead_placeholder(%arg0: tensor<2x3xf16, #hipsr.mem<device>>) -> tensor<2x3xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     return %arg0 : tensor<2x3xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// An unused placeholder is erased. The return directly after the signature is
// what proves it.
func.func @dead_placeholder(%input: tensor<2x3xf16>) -> tensor<2x3xf16> {
  %none = "onnx.NoValue"() {value} : () -> none
  "onnx.Return"(%input) : (tensor<2x3xf16>) -> ()
}
