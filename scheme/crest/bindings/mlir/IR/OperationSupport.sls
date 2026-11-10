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
    mlir::NamedAttrList::get
    mlir::NamedAttrList::append
    mlir::NamedAttrList::set
    mlir::OperationName::getContext
    crest::isa<CrestBox<mlir::OperationState>>?
    with-OperationState)
  (import (rnrs)
          (only (mlir support CrestObject) with-CrestObject)
          (mlir IR OperationSupport ffi))

  ;; @brief crest::isa<CrestBox<mlir::OperationState>>? — is this ptr a CrestBox<mlir::OperationState>?
  (define (crest::isa<CrestBox<mlir::OperationState>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::OperationState>> ptr))))

  (define mlir::OperationState::create       %mlir::OperationState::create)
  (define mlir::OperationState::addOperands  %mlir::OperationState::addOperands)
  (define mlir::OperationState::addTypes     %mlir::OperationState::addTypes)
  (define mlir::OperationState::addRegion    %mlir::OperationState::addRegion)
  (define mlir::OperationState::addAttribute %mlir::OperationState::addAttribute)

  ;; The NamedAttrList that the :populate-default-attrs of an op gets, and the OperationName.
  (define mlir::NamedAttrList::get %mlir::NamedAttrList::get)
  (define mlir::NamedAttrList::append %mlir::NamedAttrList::append)
  (define mlir::NamedAttrList::set %mlir::NamedAttrList::set)
  (define mlir::OperationName::getContext %mlir::OperationName::getContext)

  ;; @brief with-OperationState — RAII for a heap-allocated mlir::OperationState.
  ;; @param var   identifier bound to the CrestBox<OperationState>* uptr for BODY
  ;; @param loc   mlir::Location uptr — source-code location attached to the new op
  ;; @param name  string — fully-qualified op name (e.g. "arith.addi")
  ;; @param body  forms evaluated with var in scope; last value is returned
  ;; @note        Destroys the OperationState on exit (normal or non-local) via
  ;;              CrestObject deletor — no explicit destructor binding needed.
  (define-syntax with-OperationState
    (lambda (stx)
      (syntax-case stx ()
        [(_ var (loc name) body ...)
         (identifier? #'var)
         #'(with-CrestObject var (mlir::OperationState::create loc name)
             body ...)])))

  ) ;; end library (mlir IR OperationSupport)
