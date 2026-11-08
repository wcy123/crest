// mlir::FloatAttr::get<f64> (and so the `:f64` shorthand of an op-form) takes the context from
// with-MLIRContext as well as the raw pointer that MLIR hands to a pass. It used to crash with
// "invalid memory reference": it was the one binding in BuiltinAttributes.cpp that cast its context
// argument instead of going through crest::as_ptr.
//
// RUN: %scheme-mlir %S/float-attr-owned-context.sls | FileCheck %s

// CHECK: 1.5
// CHECK: 2.25
