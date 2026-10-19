#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR MLIRContext ffi) — Raw C bindings for mlir::MLIRContext methods.
;;
;; Mirrors mlir/IR/MLIRContext.h.
;; All procedures are prefixed with % to indicate raw/internal FFI.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR MLIRContext ffi)
  (export
    %mlir::MLIRContext::allowUnregisteredDialects
    %mlir::MLIRContext::allowsUnregisteredDialects
    %mlir::MLIRContext::enableMultithreading
    %mlir::MLIRContext::disableMultithreading
    %mlir-context-is-multithreading-enabled
    %mlir::MLIRContext::getOrLoadDialect
    %mlir::MLIRContext::loadAllAvailableDialects
    %mlir::MLIRContext::printOpOnDiagnostic
    %mlir::MLIRContext::shouldPrintOpOnDiagnostic
    %mlir::MLIRContext::printStackTraceOnDiagnostic)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::MLIRContext::allowUnregisteredDialects — enable or disable unregistered dialects.
  ;; @param ctx    MLIRContext* as uptr
  ;; @param allow  int; non-zero = allow, 0 = disallow
  ;; @return       void
  ;; @see          mlir/IR/MLIRContext.h
  ;; @note         Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::allowUnregisteredDialects
    (foreign-procedure "mlir_ir_mlir_context_allow_unregistered_dialects" (uptr int) void))

  ;; @brief mlir::MLIRContext::allowsUnregisteredDialects — query whether unregistered dialects are allowed.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     int; 1 = allowed, 0 = disallowed
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::allowsUnregisteredDialects
    (foreign-procedure "mlir_ir_mlir_context_allows_unregistered_dialects" (uptr) int))

  ;; @brief mlir::MLIRContext::enableMultithreading — enable multithreaded compilation.
  ;; @param ctx    MLIRContext* as uptr
  ;; @param enable int; non-zero = enable, 0 = disable
  ;; @return       void
  ;; @see          mlir/IR/MLIRContext.h
  ;; @note         Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::enableMultithreading
    (foreign-procedure "mlir_ir_mlir_context_enable_multithreading" (uptr int) void))

  ;; @brief mlir::MLIRContext::disableMultithreading — disable multithreaded compilation.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param disable int; non-zero = disable, 0 = enable
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::disableMultithreading
    (foreign-procedure "mlir_ir_mlir_context_disable_multithreading" (uptr int) void))

  ;; @brief mlir::MLIRContext::isMultithreadingEnabled — query whether multithreading is enabled.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     int; 1 = enabled, 0 = disabled
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir-context-is-multithreading-enabled
    (foreign-procedure "mlir_ir_mlir_context_is_multithreading_enabled" (uptr) int))

  ;; @brief mlir::MLIRContext::getOrLoadDialect — load a dialect by namespace and return it.
  ;; @param ctx  MLIRContext* as uptr
  ;; @param ns   Dialect namespace string (e.g. "arith", "func")
  ;; @return     Dialect* as uptr; 0 if namespace is not registered
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Dialect.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::getOrLoadDialect
    (foreign-procedure "mlir_ir_mlir_context_get_or_load_dialect" (uptr string) uptr))

  ;; @brief mlir::MLIRContext::loadAllAvailableDialects — load every statically linked dialect.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::loadAllAvailableDialects
    (foreign-procedure "mlir_ir_mlir_context_load_all_available_dialects" (uptr) void))

  ;; @brief mlir::MLIRContext::printOpOnDiagnostic — control whether ops are printed on diagnostics.
  ;; @param ctx    MLIRContext* as uptr
  ;; @param enable int; non-zero = print, 0 = suppress
  ;; @return       void
  ;; @see          mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note         Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::printOpOnDiagnostic
    (foreign-procedure "mlir_ir_mlir_context_print_op_on_diagnostic" (uptr int) void))

  ;; @brief mlir::MLIRContext::shouldPrintOpOnDiagnostic — query the print-op-on-diagnostic flag.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     int; 1 = will print, 0 = suppressed
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::shouldPrintOpOnDiagnostic
    (foreign-procedure "mlir_ir_mlir_context_should_print_op_on_diagnostic" (uptr) int))

  ;; @brief mlir::MLIRContext::printStackTraceOnDiagnostic — control stack-trace printing on diagnostics.
  ;; @param ctx    MLIRContext* as uptr
  ;; @param enable int; non-zero = print stack trace, 0 = suppress
  ;; @return       void
  ;; @see          mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note         Defined in lib/Bindings/IR/MLIRContext.cpp
  (define %mlir::MLIRContext::printStackTraceOnDiagnostic
    (foreign-procedure "mlir_ir_mlir_context_print_stack_trace_on_diagnostic" (uptr int) void))

  ) ;; end library (mlir IR MLIRContext ffi)
