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

  ;; Current MLIRContext* uptr (or #f when unset).
  (define current-mlir-context (make-parameter #f))

  ;; RAII macro: install ctx as current-mlir-context for the duration of body.
  (define-syntax with-mlir-context
    (syntax-rules ()
      [(_ ctx body ...)
       (parameterize ([current-mlir-context ctx]) body ...)]))

  (define (mlir-context-allow-unregistered-dialects ctx allow?)
    (%mlir-context-allow-unregistered-dialects ctx (if allow? 1 0)))
  (define (mlir-context-allows-unregistered-dialects? ctx)
    (not (zero? (%mlir-context-allows-unregistered-dialects ctx))))
  (define (mlir-context-enable-multithreading ctx)
    (%mlir-context-enable-multithreading ctx 1))
  (define (mlir-context-disable-multithreading ctx)
    (%mlir-context-disable-multithreading ctx 1))
  (define (mlir-context-multithreading-enabled? ctx)
    (not (zero? (%mlir-context-is-multithreading-enabled ctx))))
  (define (mlir-context-get-or-load-dialect ctx ns)
    (%mlir-context-get-or-load-dialect ctx ns))
  (define (mlir-context-load-all-available-dialects ctx)
    (%mlir-context-load-all-available-dialects ctx))
  (define (mlir-context-print-op-on-diagnostic ctx enable?)
    (%mlir-context-print-op-on-diagnostic ctx (if enable? 1 0)))
  (define (mlir-context-should-print-op-on-diagnostic? ctx)
    (not (zero? (%mlir-context-should-print-op-on-diagnostic ctx))))
  (define (mlir-context-print-stack-trace-on-diagnostic ctx enable?)
    (%mlir-context-print-stack-trace-on-diagnostic ctx (if enable? 1 0)))
) ;; end library (mlir ir mlir-context)
