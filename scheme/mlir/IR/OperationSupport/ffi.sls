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
    %mlir::OperationState::addAttribute
    %mlir::NamedAttrList::get
    %mlir::NamedAttrList::append
    %mlir::NamedAttrList::set
    %mlir::OperationName::getContext
    %crest::isa<CrestBox<mlir::OperationState>>
    %operation-state-create
    %operation-state-add-operands          ;; canonical: mlir::OperationState::addOperands
    %operation-state-add-operand           ;; backward-compat alias
    %operation-state-add-types             ;; canonical: mlir::OperationState::addTypes
    %operation-state-add-result-type       ;; backward-compat alias
    %operation-state-add-region
    %operation-state-add-attribute)
  (import (rnrs)
          (crest support foreign) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::OperationState constructor — heap-allocate a CrestBox<OperationState>.
  ;; @param loc-ptr   Location opaque ptr as uptr
  ;; @param name      Registered MLIR op name string (e.g. "arith.constant")
  ;; @return          CrestBox<OperationState>* as uptr — freed via with-CrestObject
  ;; @see             mlir/IR/OperationSupport.h
  (define %operation-state-create
    (crest-foreign-procedure "mlir::OperationState::create" (uptr string) uptr))

  ;; @brief mlir::OperationState::addOperands — add a single operand Value to the state.
  (define %operation-state-add-operands
    (crest-foreign-procedure "mlir::OperationState::addOperands" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-operands.
  (define %operation-state-add-operand %operation-state-add-operands)

  ;; @brief mlir::OperationState::addTypes — add a single result Type to the state.
  (define %operation-state-add-types
    (crest-foreign-procedure "mlir::OperationState::addTypes" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-types.
  (define %operation-state-add-result-type %operation-state-add-types)

  ;; @brief mlir::OperationState::addRegion — add one region; returns Region* uptr.
  (define %operation-state-add-region
    (crest-foreign-procedure "mlir::OperationState::addRegion" (uptr) uptr))

  ;; @brief mlir::OperationState::addAttribute — set an attribute before create.
  (define %operation-state-add-attribute
    (crest-foreign-procedure "mlir::OperationState::addAttribute" (uptr string uptr) void))

  ;; @brief Type predicate — is this ptr a CrestBox<mlir::OperationState>?
  (define %crest::isa<CrestBox<mlir::OperationState>>
    (crest-foreign-procedure "crest::isa<CrestBox<mlir::OperationState>>" (uptr) int))

  ;; (uptr list) (string name) -> uptr: the attribute of that name in the list, 0 if it has none.
  (define %mlir::NamedAttrList::get
    (crest-foreign-procedure "mlir::NamedAttrList::get" (uptr string) uptr))

  ;; (uptr list) (string name) (uptr attribute) -> void: add an attribute that the list does not have.
  (define %mlir::NamedAttrList::append
    (crest-foreign-procedure "mlir::NamedAttrList::append" (uptr string uptr) void))

  ;; (uptr list) (string name) (uptr attribute) -> void: replace the attribute of that name, or add it.
  (define %mlir::NamedAttrList::set
    (crest-foreign-procedure "mlir::NamedAttrList::set" (uptr string uptr) void))

  ;; (uptr name) -> uptr: the MLIRContext of an OperationName.
  (define %mlir::OperationName::getContext
    (crest-foreign-procedure "mlir::OperationName::getContext" (uptr) uptr))

  (define %mlir::OperationState::create        %operation-state-create)
  (define %mlir::OperationState::addOperands   %operation-state-add-operands)
  (define %mlir::OperationState::addTypes      %operation-state-add-types)
  (define %mlir::OperationState::addRegion     %operation-state-add-region)
  (define %mlir::OperationState::addAttribute  %operation-state-add-attribute)

  ) ;; end library (mlir IR OperationSupport ffi)
