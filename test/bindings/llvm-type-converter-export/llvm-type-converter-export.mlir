// The constructor of LLVMTypeConverter answers a heap box that only with-LLVMTypeConverter frees, so
// (mlir Conversion LLVMCommon TypeConverter) exports the macro and not the constructor.
//
// RUN: %scheme-mlir %S/macro.sls | %FileCheck %s --check-prefix=MACRO
// RUN: not %scheme-mlir %S/raw.sls 2>&1 | %FileCheck %s --check-prefix=RAW

// MACRO: converter: made
// RAW-NOT: imported the raw constructor
// RAW: mlir::LLVMTypeConverter::LLVMTypeConverter

module {}
