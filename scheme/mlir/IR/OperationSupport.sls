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
    %mlir::OperationState::create
    %mlir::OperationState::addOperands
    %mlir::OperationState::addTypes
    %mlir::OperationState::addRegion
    %mlir::OperationState::~OperationState
    with-OperationState)
  (import (rnrs)
          (only (mlir support RAII) with-raii)
          (mlir IR OperationSupport ffi))

  ;; @brief with-OperationState — RAII for a heap-allocated mlir::OperationState.
  ;; @param var   identifier bound to the OperationState* uptr for BODY
  ;; @param loc   Location* uptr — source location attached to the new op (used in
  ;;              diagnostics). Obtain via (mlir::Operation::getLoc anchor-op).
  ;;              This controls location metadata only — insertion order is
  ;;              controlled separately, e.g. via mlir::RewriterBase::setInsertionPoint
  ;;              which inserts the new op BEFORE anchor-op.
  ;; @param name  string — fully-qualified op name (e.g. "arith.addi")
  ;; @param body  forms evaluated with var in scope; last value is returned
  ;; @note        Destroys the OperationState on exit (normal or non-local).
  (define-syntax with-OperationState
    (syntax-rules ()
      [(_ (var loc name) body ...)
       (with-raii (var (%mlir::OperationState::create loc name)
                       %mlir::OperationState::~OperationState)
                  body ...)]))

  ) ;; end library (mlir IR OperationSupport)
