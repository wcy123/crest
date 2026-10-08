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
    %mlir::RewriterBase::setInsertionPoint          ;; canonical: mlir::RewriterBase::setInsertionPoint(op)
    %mlir::RewriterBase::setInsertionPoint-before   ;; backward-compat alias
    %mlir::RewriterBase::setInsertionPoint-to-end
    %mlir::RewriterBase::createBlock
    %mlir::RewriterBase::replaceOp
    %mlir::RewriterBase::eraseOp
    %mlir::RewriterBase::create<OperationState>
    %mlir::RewritePatternSet::RewritePatternSet
    %crest::isa<CrestOwned<mlir::RewritePatternSet>>
    %crest::isa<CrestRef<mlir::RewriterBase>>)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::RewriterBase::setInsertionPoint
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point"
                       (uptr uptr) void))

  (define %mlir::RewriterBase::setInsertionPoint-before
    %mlir::RewriterBase::setInsertionPoint)

  (define %mlir::RewriterBase::setInsertionPoint-to-end
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_to_end"
                       (uptr uptr) void))

  (define %mlir::RewriterBase::createBlock
    (foreign-procedure "mlir_ir_rewriter_base_create_block"
                       (uptr uptr scheme-object) uptr))

  (define %mlir::RewriterBase::replaceOp
    (foreign-procedure "mlir_ir_rewriter_base_replace_op"
                       (uptr uptr uptr) int))

  (define %mlir::RewriterBase::eraseOp
    (foreign-procedure "mlir_ir_rewriter_base_erase_op"
                       (uptr uptr) int))

  ;; Accepts CrestRef<RewriterBase>* and CrestOwned<OperationState>*; extracts
  ;; inner pointers in C++. See lib/Bindings/IR/PatternMatch.cpp.
  (define %mlir::RewriterBase::create<OperationState>
    (foreign-procedure "mlir::RewriterBase::create<OperationState>" (uptr uptr) uptr))

  ;; @brief mlir::RewritePatternSet constructor — heap-allocate a CrestOwned pattern set.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     CrestOwned<RewritePatternSet>* uptr — freed via with-CrestObject
  (define %mlir::RewritePatternSet::RewritePatternSet
    (foreign-procedure "mlir::RewritePatternSet::RewritePatternSet" (uptr) uptr))

  ;; @brief Type predicates via CrestObject::isa<T>.
  (define %crest::isa<CrestOwned<mlir::RewritePatternSet>>
    (foreign-procedure "crest::isa<CrestOwned<mlir::RewritePatternSet>>" (uptr) int))

  (define %crest::isa<CrestRef<mlir::RewriterBase>>
    (foreign-procedure "crest::isa<CrestRef<mlir::RewriterBase>>" (uptr) int))

  ) ;; end library (mlir IR PatternMatch ffi)
