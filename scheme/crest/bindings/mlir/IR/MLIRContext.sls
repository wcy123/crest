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
;;===----------------------------------------------------------------------===;;

(library (mlir IR MLIRContext)
  (export
    current-MLIRContext
    with-current-MLIRContext
    define-ctx-optional
    mlir::MLIRContext::new
    mlir::MLIRContext::allowUnregisteredDialects
    mlir::MLIRContext::allowsUnregisteredDialects?
    mlir::MLIRContext::enableMultithreading
    mlir::MLIRContext::disableMultithreading
    mlir::MLIRContext::isMultithreadingEnabled?
    mlir::MLIRContext::getOrLoadDialect
    mlir::MLIRContext::loadAllAvailableDialects
    mlir::MLIRContext::printOpOnDiagnostic
    mlir::MLIRContext::shouldPrintOpOnDiagnostic?
    mlir::MLIRContext::printStackTraceOnDiagnostic
    mlir::parseSourceFile)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir IR MLIRContext ffi))

  (define mlir::MLIRContext::new
    (case-lambda
     [()         (%mlir::MLIRContext::new)]
     [(registry) (%mlir::MLIRContext::new/registry registry)]))

  (define current-MLIRContext (make-parameter #f))

  (define-syntax with-current-MLIRContext
    (syntax-rules ()
      [(_ ctx body ...)
       (parameterize ([current-MLIRContext ctx]) body ...)]))

  (define (mlir::MLIRContext::allowUnregisteredDialects ctx allow?)
    (%mlir::MLIRContext::allowUnregisteredDialects ctx (if allow? 1 0)))

  (define (mlir::MLIRContext::allowsUnregisteredDialects? ctx)
    (not (zero? (%mlir::MLIRContext::allowsUnregisteredDialects ctx))))

  (define (mlir::MLIRContext::enableMultithreading ctx)
    (%mlir::MLIRContext::enableMultithreading ctx 1))

  (define (mlir::MLIRContext::disableMultithreading ctx)
    (%mlir::MLIRContext::disableMultithreading ctx 1))

  (define (mlir::MLIRContext::isMultithreadingEnabled? ctx)
    (not (zero? (%mlir::MLIRContext::isMultithreadingEnabled ctx))))

  (define (mlir::MLIRContext::getOrLoadDialect ctx ns)
    (%mlir::MLIRContext::getOrLoadDialect ctx ns))

  (define (mlir::MLIRContext::loadAllAvailableDialects ctx)
    (%mlir::MLIRContext::loadAllAvailableDialects ctx))

  (define (mlir::MLIRContext::printOpOnDiagnostic ctx enable?)
    (%mlir::MLIRContext::printOpOnDiagnostic ctx (if enable? 1 0)))

  (define (mlir::MLIRContext::shouldPrintOpOnDiagnostic? ctx)
    (not (zero? (%mlir::MLIRContext::shouldPrintOpOnDiagnostic ctx))))

  (define (mlir::MLIRContext::printStackTraceOnDiagnostic ctx enable?)
    (%mlir::MLIRContext::printStackTraceOnDiagnostic ctx (if enable? 1 0)))

  ;; Zero-extra-arg form uses current-MLIRContext; one-or-more-arg form
  ;; forwards the first argument as the context.
  (define-syntax define-ctx-optional
    (syntax-rules ()
      [(_ name raw arg ...)
       (define name
         (case-lambda
          [(arg ...)     (raw (current-MLIRContext) arg ...)]
          [(ctx arg ...) (raw ctx arg ...)]))]))

  (define (mlir::parseSourceFile ctx filename)
    (%mlir::parseSourceFile ctx filename))

  ) ;; end library (mlir IR MLIRContext)
