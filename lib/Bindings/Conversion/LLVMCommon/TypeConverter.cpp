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
  Sregister_symbol(
      "mlir::LLVMTypeConverter::LLVMTypeConverter",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::LLVMTypeConverter::LLVMTypeConverter",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            new crest::CrestBox<mlir::LLVMTypeConverter>(ctx)));
      });
}

} // namespace crest
