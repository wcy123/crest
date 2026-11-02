/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h

#include "TypeConverter.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerConversionLLVMCommonTypeConverterBindings() {
  // mlir::LLVMTypeConverter::LLVMTypeConverter: create an LLVM type converter.
  // (ctx-ptr) → CrestOwned<LLVMTypeConverter>* uptr
  Sregister_symbol(
      "mlir::LLVMTypeConverter::LLVMTypeConverter",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::LLVMTypeConverter::LLVMTypeConverter");
        return reinterpret_cast<uint64_t>(
            new crest::CrestOwned<mlir::LLVMTypeConverter>(ctx));
      });
}

} // namespace crest
