#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR MLIRContext) — Public API for mlir::MLIRContext.
;;
;; Mirrors mlir/IR/MLIRContext.h.
;; Provides the ambient context parameter (current-MLIRContext,
;; with-current-MLIRContext) and clean wrappers around the raw FFI bindings.
;;
;; Usage:
;;   (with-current-MLIRContext ctx
;;     (mlir::MLIRContext::loadAllAvailableDialects ctx)
;;     (mlir::MLIRContext::allowUnregisteredDialects ctx #t))
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR MLIRContext)
  (export
    current-MLIRContext
    with-current-MLIRContext
    define-ctx-optional
    mlir::MLIRContext::allowUnregisteredDialects
    mlir::MLIRContext::allowsUnregisteredDialects?
    mlir::MLIRContext::enableMultithreading
    mlir::MLIRContext::disableMultithreading
    mlir::MLIRContext::isMultithreadingEnabled?
    mlir::MLIRContext::getOrLoadDialect
    mlir::MLIRContext::loadAllAvailableDialects
    mlir::MLIRContext::printOpOnDiagnostic
    mlir::MLIRContext::shouldPrintOpOnDiagnostic?
    mlir::MLIRContext::printStackTraceOnDiagnostic)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir IR MLIRContext ffi))

  ;; @brief current-MLIRContext — dynamic parameter holding the ambient MLIRContext* uptr.
  ;; @return  MLIRContext* as uptr, or #f when no context is installed
  ;; @see     with-current-MLIRContext, mlir/IR/MLIRContext.h
  ;; @note    Set via (parameterize ([current-MLIRContext ctx]) ...) or with-current-MLIRContext
  (define current-MLIRContext (make-parameter #f))

  ;; @brief with-current-MLIRContext — RAII macro: install ctx as current-MLIRContext for body forms.
  ;; @param ctx   MLIRContext* uptr to bind as the ambient context
  ;; @param body  One or more expressions evaluated with current-MLIRContext = ctx
  ;; @return      Value of the last body expression
  ;; @see         current-MLIRContext, mlir/IR/MLIRContext.h
  ;; @note        Implemented via parameterize; the previous value is restored on exit (normal or exception)
  (define-syntax with-current-MLIRContext
    (syntax-rules ()
      [(_ ctx body ...)
       (parameterize ([current-MLIRContext ctx]) body ...)]))

  ;; @brief mlir::MLIRContext::allowUnregisteredDialects — enable or disable unregistered dialects.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param allow?  boolean; #t = allow, #f = disallow
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::allowUnregisteredDialects ctx allow?)
    (%mlir::MLIRContext::allowUnregisteredDialects ctx (if allow? 1 0)))

  ;; @brief mlir::MLIRContext::allowsUnregisteredDialects — query whether unregistered dialects are allowed.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = allowed, #f = disallowed
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::allowsUnregisteredDialects? ctx)
    (not (zero? (%mlir::MLIRContext::allowsUnregisteredDialects ctx))))

  ;; @brief mlir::MLIRContext::enableMultithreading — enable multithreaded compilation.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp; passes enable=1 to the C binding
  (define (mlir::MLIRContext::enableMultithreading ctx)
    (%mlir::MLIRContext::enableMultithreading ctx 1))

  ;; @brief mlir::MLIRContext::disableMultithreading — disable multithreaded compilation.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp; passes disable=1 to the C binding
  (define (mlir::MLIRContext::disableMultithreading ctx)
    (%mlir::MLIRContext::disableMultithreading ctx 1))

  ;; @brief mlir::MLIRContext::isMultithreadingEnabled — query whether multithreading is enabled.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = enabled, #f = disabled
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::isMultithreadingEnabled? ctx)
    (not (zero? (%mlir-context-is-multithreading-enabled ctx))))

  ;; @brief mlir::MLIRContext::getOrLoadDialect — load a dialect by namespace and return it.
  ;; @param ctx  MLIRContext* as uptr
  ;; @param ns   Dialect namespace string (e.g. "arith", "func")
  ;; @return     Dialect* as uptr; 0 if namespace is not registered
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Dialect.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::getOrLoadDialect ctx ns)
    (%mlir::MLIRContext::getOrLoadDialect ctx ns))

  ;; @brief mlir::MLIRContext::loadAllAvailableDialects — load every statically linked dialect.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     void
  ;; @see        mlir/IR/MLIRContext.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::loadAllAvailableDialects ctx)
    (%mlir::MLIRContext::loadAllAvailableDialects ctx))

  ;; @brief mlir::MLIRContext::printOpOnDiagnostic — control whether ops are printed on diagnostics.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param enable? boolean; #t = print, #f = suppress
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::printOpOnDiagnostic ctx enable?)
    (%mlir::MLIRContext::printOpOnDiagnostic ctx (if enable? 1 0)))

  ;; @brief mlir::MLIRContext::shouldPrintOpOnDiagnostic — query the print-op-on-diagnostic flag.
  ;; @param ctx  MLIRContext* as uptr
  ;; @return     boolean; #t = will print, #f = suppressed
  ;; @see        mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::shouldPrintOpOnDiagnostic? ctx)
    (not (zero? (%mlir::MLIRContext::shouldPrintOpOnDiagnostic ctx))))

  ;; @brief mlir::MLIRContext::printStackTraceOnDiagnostic — control stack-trace printing on diagnostics.
  ;; @param ctx     MLIRContext* as uptr
  ;; @param enable? boolean; #t = print stack trace, #f = suppress
  ;; @return        void
  ;; @see           mlir/IR/MLIRContext.h, mlir/IR/Diagnostics.h
  ;; @note          Defined in lib/Bindings/IR/MLIRContext.cpp
  (define (mlir::MLIRContext::printStackTraceOnDiagnostic ctx enable?)
    (%mlir::MLIRContext::printStackTraceOnDiagnostic ctx (if enable? 1 0)))

  ;; @brief define-ctx-optional — define a function whose first argument is an
  ;; optional MLIRContext*.  The zero-extra-arg form uses current-MLIRContext;
  ;; the one-or-more-arg form forwards the first argument as the context.
  ;;
  ;; Usage:
  ;;   (define-ctx-optional mlir::IndexType::get %mlir::IndexType::get)
  ;;   (define-ctx-optional mlir::IntegerAttr::get<i64> %mlir::IntegerAttr::get<i64> value)
  (define-syntax define-ctx-optional
    (syntax-rules ()
      [(_ name raw arg ...)
       (define name
         (case-lambda
          [(arg ...)     (raw (current-MLIRContext) arg ...)]
          [(ctx arg ...) (raw ctx arg ...)]))]))

  ) ;; end library (mlir IR MLIRContext)
