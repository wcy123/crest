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

extern "C" {

// MLIRContext::allowUnregisteredDialects(bool allow = true)
void mlir_ir_mlir_context_allow_unregistered_dialects(uint64_t ctx_ptr,
                                                      int allow) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->allowUnregisteredDialects(
      allow != 0);
}

// MLIRContext::allowsUnregisteredDialects()
int mlir_ir_mlir_context_allows_unregistered_dialects(uint64_t ctx_ptr) {
  return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                 ->allowsUnregisteredDialects()
             ? 1
             : 0;
}

// MLIRContext::enableMultithreading(bool enable = true)
void mlir_ir_mlir_context_enable_multithreading(uint64_t ctx_ptr, int enable) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->enableMultithreading(enable !=
                                                                      0);
}

// MLIRContext::disableMultithreading(bool disable = true)
void mlir_ir_mlir_context_disable_multithreading(uint64_t ctx_ptr,
                                                 int disable) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->disableMultithreading(
      disable != 0);
}

// MLIRContext::isMultithreadingEnabled()
int mlir_ir_mlir_context_is_multithreading_enabled(uint64_t ctx_ptr) {
  return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                 ->isMultithreadingEnabled()
             ? 1
             : 0;
}

// MLIRContext::getOrLoadDialect(StringRef)
uint64_t mlir_ir_mlir_context_get_or_load_dialect(uint64_t ctx_ptr,
                                                  const char* ns) {
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->getOrLoadDialect(ns));
}

// MLIRContext::loadAllAvailableDialects()
void mlir_ir_mlir_context_load_all_available_dialects(uint64_t ctx_ptr) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->loadAllAvailableDialects();
}

// MLIRContext::printOpOnDiagnostic(bool enable)
void mlir_ir_mlir_context_print_op_on_diagnostic(uint64_t ctx_ptr, int enable) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->printOpOnDiagnostic(enable !=
                                                                     0);
}

// MLIRContext::shouldPrintOpOnDiagnostic()
int mlir_ir_mlir_context_should_print_op_on_diagnostic(uint64_t ctx_ptr) {
  return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                 ->shouldPrintOpOnDiagnostic()
             ? 1
             : 0;
}

// MLIRContext::printStackTraceOnDiagnostic(bool enable)
void mlir_ir_mlir_context_print_stack_trace_on_diagnostic(uint64_t ctx_ptr,
                                                          int enable) {
  reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->printStackTraceOnDiagnostic(
      enable != 0);
}

} // extern "C"

namespace crest {
void registerIRMLIRContextBindings() {
  Sregister_symbol("mlir_ir_mlir_context_allow_unregistered_dialects",
                   (void*)::mlir_ir_mlir_context_allow_unregistered_dialects);
  Sregister_symbol("mlir_ir_mlir_context_allows_unregistered_dialects",
                   (void*)::mlir_ir_mlir_context_allows_unregistered_dialects);
  Sregister_symbol("mlir_ir_mlir_context_enable_multithreading",
                   (void*)::mlir_ir_mlir_context_enable_multithreading);
  Sregister_symbol("mlir_ir_mlir_context_disable_multithreading",
                   (void*)::mlir_ir_mlir_context_disable_multithreading);
  Sregister_symbol("mlir_ir_mlir_context_is_multithreading_enabled",
                   (void*)::mlir_ir_mlir_context_is_multithreading_enabled);
  Sregister_symbol("mlir_ir_mlir_context_get_or_load_dialect",
                   (void*)::mlir_ir_mlir_context_get_or_load_dialect);
  Sregister_symbol("mlir_ir_mlir_context_load_all_available_dialects",
                   (void*)::mlir_ir_mlir_context_load_all_available_dialects);
  Sregister_symbol("mlir_ir_mlir_context_print_op_on_diagnostic",
                   (void*)::mlir_ir_mlir_context_print_op_on_diagnostic);
  Sregister_symbol("mlir_ir_mlir_context_should_print_op_on_diagnostic",
                   (void*)::mlir_ir_mlir_context_should_print_op_on_diagnostic);
  Sregister_symbol(
      "mlir_ir_mlir_context_print_stack_trace_on_diagnostic",
      (void*)::mlir_ir_mlir_context_print_stack_trace_on_diagnostic);
}
} // namespace crest
