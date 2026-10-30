#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR DialectRegistry) — Public API for mlir::DialectRegistry.
;;
;; Mirrors mlir/IR/DialectRegistry.h.
;; Provides dialect registry construction, Scheme dialect insertion, and
;; MLIRContext creation from a registry. Use with-DialectRegistry to manage
;; registry lifetime — the registry can be freed once the MLIRContext is built.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR DialectRegistry)
  (export mlir::DialectRegistry::new
          mlir::DialectRegistry::insert
          with-DialectRegistry
          with-MLIRContext)
  (import (rnrs)
          (mlir IR DialectRegistry ffi)
          (mlir IR MLIRContext ffi)
          (mlir support RAII))

  (define mlir::DialectRegistry::new
    %mlir::DialectRegistry::new)

  (define mlir::DialectRegistry::insert
    %mlir::DialectRegistry::insert)

  (define %%crest-object-delete %CrestObject::delete)

  ;; RAII macro: binds REG to a fresh DialectRegistry for BODY, then frees it.
  ;; The registry can be freed after the MLIRContext is created from it.
  (define-syntax with-DialectRegistry
    (syntax-rules ()
      [(_ (reg) body ...)
       (with-raii (reg (mlir::DialectRegistry::new) %%crest-object-delete)
         body ...)]))

  ;; RAII macro: binds CTX to a new MLIRContext created from REG, then frees
  ;; it on exit. The context owns all ops and dialects built inside BODY.
  (define-syntax with-MLIRContext
    (syntax-rules ()
      [(_ (ctx reg) body ...)
       (with-raii (ctx (%mlir::MLIRContext::new/registry reg) %%crest-object-delete)
         body ...)]))

  ) ;; end library (mlir IR DialectRegistry)
