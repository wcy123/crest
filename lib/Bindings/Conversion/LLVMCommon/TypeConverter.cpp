/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h

#include "TypeConverter.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerConversionLLVMCommonTypeConverterBindings() {
  // mlir::LLVMTypeConverter::LLVMTypeConverter: create an LLVM type converter.
  // (ctx-ptr) → CrestBox<LLVMTypeConverter>* uptr
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-LLVMTypeConverter, which frees it after its body; a box that is never
  // freed leaks.
  register_binding(
      "mlir::LLVMTypeConverter::LLVMTypeConverter",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx,
                  crest::as_ptr<mlir::MLIRContext>(
                      ctx_ptr, "mlir::LLVMTypeConverter::LLVMTypeConverter"));
        return reinterpret_cast<uint64_t>(
            new crest::CrestBox<mlir::LLVMTypeConverter>(ctx));
      });
}

} // namespace crest
