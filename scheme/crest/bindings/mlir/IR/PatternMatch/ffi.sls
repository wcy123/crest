#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/PatternMatch.h (RewriterBase),
;;         mlir/IR/Builders.h (setInsertionPoint, createBlock — inherited from OpBuilder).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR PatternMatch ffi) — raw C bindings for mlir/IR/PatternMatch.h RewriterBase.
;;
;; % prefix = raw C binding. Prefer (mlir IR PatternMatch) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR PatternMatch ffi)
  (export
    %mlir::RewriterBase::setInsertionPoint
    %mlir::RewriterBase::setInsertionPointToEnd
    %mlir::RewriterBase::setInsertionPointToStart
    %mlir::RewriterBase::createBlock
    %mlir::RewriterBase::replaceOp
    %mlir::RewriterBase::eraseOp
    %mlir::RewriterBase::create<OperationState>
    %mlir::RewriterBase::inlineRegionBefore
    %crest::isa<CrestBox<mlir::RewriterBase*>>
    %mlir::RewritePatternSet::RewritePatternSet
    %crest::isa<CrestBox<mlir::RewritePatternSet>>)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  (define %mlir::RewriterBase::setInsertionPoint
    (crest-foreign-procedure "mlir::RewriterBase::setInsertionPoint"
                             (uptr uptr) void))

  (define %mlir::RewriterBase::setInsertionPointToEnd
    (crest-foreign-procedure "mlir::RewriterBase::setInsertionPointToEnd"
                             (uptr uptr) void))

  (define %mlir::RewriterBase::setInsertionPointToStart
    (crest-foreign-procedure "mlir::RewriterBase::setInsertionPointToStart"
                             (uptr uptr) void))

  (define %mlir::RewriterBase::createBlock
    (crest-foreign-procedure "mlir::RewriterBase::createBlock"
                             (uptr uptr scheme-object) uptr))

  (define %mlir::RewriterBase::replaceOp
    (crest-foreign-procedure "mlir::RewriterBase::replaceOp"
                             (uptr uptr uptr) int))

  (define %mlir::RewriterBase::eraseOp
    (crest-foreign-procedure "mlir::RewriterBase::eraseOp"
                             (uptr uptr) int))

  ;; Accepts CrestBox<RewriterBase*>* and CrestBox<OperationState>*; extracts
  ;; inner pointers in C++. See lib/Bindings/IR/PatternMatch.cpp.
  (define %mlir::RewriterBase::create<OperationState>
    (crest-foreign-procedure "mlir::RewriterBase::create<OperationState>" (uptr uptr) uptr))

  ;; @brief Move all blocks of a region to the front of another.
  ;; @param rw    CrestBox<RewriterBase*>* uptr — rewriter-only, a plain builder is an error
  ;; @param src   Region* uptr, left empty
  ;; @param dest  Region* uptr
  (define %mlir::RewriterBase::inlineRegionBefore
    (crest-foreign-procedure "mlir::RewriterBase::inlineRegionBefore" (uptr uptr uptr) void))

  ;; @brief Is this ptr a CrestBox<RewriterBase*> shell? 1 or 0.
  (define %crest::isa<CrestBox<mlir::RewriterBase*>>
    (crest-foreign-procedure "crest::isa<CrestBox<mlir::RewriterBase*>>" (uptr) int))

  ;; @brief mlir::RewritePatternSet constructor — heap-allocate a CrestBox pattern set.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     CrestBox<RewritePatternSet>* uptr — freed via with-CrestObject
  (define %mlir::RewritePatternSet::RewritePatternSet
    (crest-foreign-procedure "mlir::RewritePatternSet::RewritePatternSet" (uptr) uptr))

  ;; @brief Type predicates via CrestObject::isa<T>.
  (define %crest::isa<CrestBox<mlir::RewritePatternSet>>
    (crest-foreign-procedure "crest::isa<CrestBox<mlir::RewritePatternSet>>" (uptr) int))

  ) ;; end library (mlir IR PatternMatch ffi)
