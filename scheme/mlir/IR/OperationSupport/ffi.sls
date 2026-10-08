#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR OperationSupport ffi) — Raw C bindings for mlir::OperationState.
;;
;; Mirrors mlir/IR/OperationSupport.h.
;; All procedures are prefixed with % to indicate raw/internal FFI.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR OperationSupport ffi)
  (export
    %mlir::OperationState::create
    %mlir::OperationState::addOperands
    %mlir::OperationState::addTypes
    %mlir::OperationState::addRegion
    %crest::isa<CrestOwned<mlir::OperationState>>
    %operation-state-create
    %operation-state-add-operands          ;; canonical: mlir::OperationState::addOperands
    %operation-state-add-operand           ;; backward-compat alias
    %operation-state-add-types             ;; canonical: mlir::OperationState::addTypes
    %operation-state-add-result-type       ;; backward-compat alias
    %operation-state-add-region)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::OperationState constructor — heap-allocate a CrestOwned<OperationState>.
  ;; @param loc-ptr   Location opaque ptr as uptr
  ;; @param name      Registered MLIR op name string (e.g. "arith.constant")
  ;; @return          CrestOwned<OperationState>* as uptr — freed via with-CrestObject
  ;; @see             mlir/IR/OperationSupport.h
  (define %operation-state-create
    (foreign-procedure "mlir::OperationState::create" (uptr string) uptr))

  ;; @brief mlir::OperationState::addOperands — add a single operand Value to the state.
  (define %operation-state-add-operands
    (foreign-procedure "mlir::OperationState::addOperands" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-operands.
  (define %operation-state-add-operand %operation-state-add-operands)

  ;; @brief mlir::OperationState::addTypes — add a single result Type to the state.
  (define %operation-state-add-types
    (foreign-procedure "mlir::OperationState::addTypes" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-types.
  (define %operation-state-add-result-type %operation-state-add-types)

  ;; @brief mlir::OperationState::addRegion — add one empty region to the state.
  (define %operation-state-add-region
    (foreign-procedure "mlir::OperationState::addRegion" (uptr) void))

  ;; @brief Type predicate — is this ptr a CrestOwned<mlir::OperationState>?
  (define %crest::isa<CrestOwned<mlir::OperationState>>
    (foreign-procedure "crest::isa<CrestOwned<mlir::OperationState>>" (uptr) int))

  (define %mlir::OperationState::create        %operation-state-create)
  (define %mlir::OperationState::addOperands   %operation-state-add-operands)
  (define %mlir::OperationState::addTypes      %operation-state-add-types)
  (define %mlir::OperationState::addRegion     %operation-state-add-region)

  ) ;; end library (mlir IR OperationSupport ffi)
