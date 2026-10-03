// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

//===----------------------------------------------------------------------===//
// onnx.Return becomes func.return, and the function's result types follow the
// operands it carries. Rejected forms live in return-invalid.mlir.
//===----------------------------------------------------------------------===//

// RUN: %crest-opt %s -allow-unregistered-dialect --crest-pass="module=passes/onnx-to-hipsr" --split-input-file | %FileCheck %s

// CHECK: module {
// CHECK:   func.func @imported_graph(%arg0: !hipsr.context, %arg1: tensor<?x4096xf16, #hipsr.mem<device>>) -> tensor<?x4096xf16, #hipsr.mem<device>> {
// CHECK-NEXT:     return %arg1 : tensor<?x4096xf16, #hipsr.mem<device>>
// CHECK-NEXT:   }
// CHECK-NEXT: }

// -----

// CHECK: module {
// CHECK:   func.func @return_no_operands(%arg0: !hipsr.context) {
// CHECK-NEXT:     return
// CHECK-NEXT:   }
// CHECK-NEXT: }

// The shape an ONNX importer produces, with the return carrying the graph's
// result.
func.func @imported_graph(%ctx: !hipsr.context, %input: tensor<?x4096xf16>)
    -> tensor<?x4096xf16> {
  "onnx.Return"(%input) : (tensor<?x4096xf16>) -> ()
}

// -----

// A graph with no results returns nothing.
func.func @return_no_operands(%ctx: !hipsr.context) {
  "onnx.Return"() : () -> ()
}
