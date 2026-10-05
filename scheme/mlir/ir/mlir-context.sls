#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir mlir-context) — Public API for mlir::MLIRContext.
;;
;; Mirrors mlir/IR/MLIRContext.h.
;; Provides the ambient context parameter (current-mlir-context,
;; with-mlir-context) and clean wrappers around the raw FFI bindings.
;;
;; Usage:
;;   (with-mlir-context ctx
;;     (mlir-context-load-all-available-dialects ctx)
;;     (mlir-context-allow-unregistered-dialects ctx #t))
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir mlir-context)
  (export
    current-mlir-context
    with-mlir-context
    mlir-context-allow-unregistered-dialects
    mlir-context-allows-unregistered-dialects?
    mlir-context-enable-multithreading
    mlir-context-disable-multithreading
    mlir-context-multithreading-enabled?
    mlir-context-get-or-load-dialect
    mlir-context-load-all-available-dialects
    mlir-context-print-op-on-diagnostic
    mlir-context-should-print-op-on-diagnostic?
    mlir-context-print-stack-trace-on-diagnostic)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir ir mlir-context ffi))

  ;; @brief current-mlir-context — dynamic parameter holding the ambient MLIRContext* uptr.
  ;; @return  MLIRContext* as uptr, or #f when no context is installed
  ;; @see     with-mlir-context, mlir/IR/MLIRContext.h
  ;; @note    Set via (parameterize ([current-mlir-context ctx]) ...) or with-mlir-context
  (define current-mlir-context (make-parameter #f))

  ;; @brief with-mlir-context — RAII macro: install ctx as current-mlir-context for body forms.
  ;; @param ctx   MLIRContext* uptr to bind as the ambient context
  ;; @param body  One or more expressions evaluated with current-mlir-context = ctx
  ;; @return      Value of the last body expression
  ;; @see         current-mlir-context, mlir/IR/MLIRContext.h
  ;; @note        Implemented via parameterize; the previous value is restored on exit (normal or exception)
  (define-syntax with-mlir-context
    (syntax-rules ()
      [(_ ctx body ...)
       (parameterize ([current-mlir-context ctx]) body ...)]))

  ;; @brief mlir::MLIRContext::allowUnregisteredDialects — enable or disable unregistered dialects.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param allow?  boolean; #t = allow, #f = disallow
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-allow-unregistered-dialects ctx allow?)
    (%mlir-context-allow-unregistered-dialects ctx (if allow? 1 0)))

  ;; @brief mlir::MLIRContext::allowsUnregisteredDialects — query whether unregistered dialects are allowed.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = allowed, #f = disallowed
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-allows-unregistered-dialects? ctx)
    (not (zero? (%mlir-context-allows-unregistered-dialects ctx))))

  ;; @brief mlir::MLIRContext::enableMultithreading — enable multithreaded compilation.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp; passes enable=1 to the C binding
  (define (mlir-context-enable-multithreading ctx)
    (%mlir-context-enable-multithreading ctx 1))

  ;; @brief mlir::MLIRContext::disableMultithreading — disable multithreaded compilation.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp; passes disable=1 to the C binding
  (define (mlir-context-disable-multithreading ctx)
    (%mlir-context-disable-multithreading ctx 1))

  ;; @brief mlir::MLIRContext::isMultithreadingEnabled — query whether multithreading is enabled.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = enabled, #f = disabled
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-multithreading-enabled? ctx)
    (not (zero? (%mlir-context-is-multithreading-enabled ctx))))

  ;; @brief mlir::MLIRContext::getOrLoadDialect — load a dialect by namespace and return it.
  ;; @param ctx  MLIRContext* as uptr
  ;; @param ns   Dialect namespace string (e.g. "arith", "func")
  ;; @return     Dialect* as uptr; 0 if namespace is not registered
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Dialect.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-get-or-load-dialect ctx ns)
    (%mlir-context-get-or-load-dialect ctx ns))

  ;; @brief mlir::MLIRContext::loadAllAvailableDialects — load every statically linked dialect.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-load-all-available-dialects ctx)
    (%mlir-context-load-all-available-dialects ctx))

  ;; @brief mlir::MLIRContext::printOpOnDiagnostic — control whether ops are printed on diagnostics.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param enable? boolean; #t = print, #f = suppress
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-print-op-on-diagnostic ctx enable?)
    (%mlir-context-print-op-on-diagnostic ctx (if enable? 1 0)))

  ;; @brief mlir::MLIRContext::shouldPrintOpOnDiagnostic — query the print-op-on-diagnostic flag.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = will print, #f = suppressed
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-should-print-op-on-diagnostic? ctx)
    (not (zero? (%mlir-context-should-print-op-on-diagnostic ctx))))

  ;; @brief mlir::MLIRContext::printStackTraceOnDiagnostic — control stack-trace printing on diagnostics.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param enable? boolean; #t = print stack trace, #f = suppress
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir-context-print-stack-trace-on-diagnostic ctx enable?)
    (%mlir-context-print-stack-trace-on-diagnostic ctx (if enable? 1 0)))

) ;; end library (mlir ir mlir-context)
