#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR OperationSupport) — OperationState public API and RAII.
;;
;; Mirrors mlir/IR/OperationSupport.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR OperationSupport)
  (export
    mlir::OperationState::create
    mlir::OperationState::addOperands
    mlir::OperationState::addTypes
    mlir::OperationState::addRegion
    mlir::OperationState::addAttribute
    crest::isa<CrestOwned<mlir::OperationState>>?
    with-OperationState)
  (import (rnrs)
          (only (mlir support array-ref) with-CrestObject)
          (mlir IR OperationSupport ffi))

  ;; @brief crest::isa<CrestOwned<mlir::OperationState>>? — is this ptr a CrestOwned<mlir::OperationState>?
  (define (crest::isa<CrestOwned<mlir::OperationState>>? ptr)
    (not (zero? (%crest::isa<CrestOwned<mlir::OperationState>> ptr))))

  (define mlir::OperationState::create       %mlir::OperationState::create)
  (define mlir::OperationState::addOperands  %mlir::OperationState::addOperands)
  (define mlir::OperationState::addTypes     %mlir::OperationState::addTypes)
  (define mlir::OperationState::addRegion    %mlir::OperationState::addRegion)
  (define mlir::OperationState::addAttribute %mlir::OperationState::addAttribute)

  ;; @brief with-OperationState — RAII for a heap-allocated mlir::OperationState.
  ;; @param var   identifier bound to the CrestOwned<OperationState>* uptr for BODY
  ;; @param loc   mlir::Location uptr — source-code location attached to the new op
  ;; @param name  string — fully-qualified op name (e.g. "arith.addi")
  ;; @param body  forms evaluated with var in scope; last value is returned
  ;; @note        Destroys the OperationState on exit (normal or non-local) via
  ;;              CrestObject deletor — no explicit destructor binding needed.
  (define-syntax with-OperationState
    (syntax-rules ()
      [(_ (var loc name) body ...)
       (with-CrestObject (var (mlir::OperationState::create loc name))
                         body ...)]))

  ) ;; end library (mlir IR OperationSupport)
