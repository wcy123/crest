/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/MLIRContext.h

#include "MLIRContext.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/MLIRContext.h"
#include <cstdint>

namespace crest {
void registerIRMLIRContextBindings() {
  Sregister_symbol(
      "mlir_ir_mlir_context_allow_unregistered_dialects",
      (void*)+[](uint64_t ctx_ptr, int allow) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->allowUnregisteredDialects(allow != 0);
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_allows_unregistered_dialects",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->allowsUnregisteredDialects()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_enable_multithreading",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->enableMultithreading(
            enable != 0);
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_disable_multithreading",
      (void*)+[](uint64_t ctx_ptr, int disable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->disableMultithreading(
            disable != 0);
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_is_multithreading_enabled",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->isMultithreadingEnabled()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_get_or_load_dialect",
      (void*)+[](uint64_t ctx_ptr, const char* ns) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->getOrLoadDialect(
                ns));
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_load_all_available_dialects",
      (void*)+[](uint64_t ctx_ptr) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->loadAllAvailableDialects();
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_print_op_on_diagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->printOpOnDiagnostic(
            enable != 0);
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_should_print_op_on_diagnostic",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->shouldPrintOpOnDiagnostic()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir_ir_mlir_context_print_stack_trace_on_diagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->printStackTraceOnDiagnostic(enable != 0);
      });
}
} // namespace crest
