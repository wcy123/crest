#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Builders) — OpBuilder user-visible API.
;;
;; Mirrors mlir/IR/Builders.h OpBuilder.
;;
;; Handle convention: every binding that takes an OpBuilder takes a builder shell:
;; CrestBox<OpBuilder> (from atBlockEnd), CrestBox<RewriterBase*> (a pattern's rw) or a
;; CrestBox<OpBuilder*> that MLIR passes to a callback. Each C++ symbol takes exactly one kind;
;; define-builder-binding (in the ffi library) checks the shell's type and calls the matching
;; one. A rewriter keeps its real type, so rewriter-only operations (replaceOp,
;; inlineRegionBefore, ...) work on the same handle.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Builders)
  (export
    mlir::OpBuilder::atBlockEnd
    mlir::OpBuilder::getListener
    mlir::OpBuilder::create<OperationState>
    mlir::OpBuilder::setInsertionPoint
    mlir::OpBuilder::setInsertionPointToEnd
    current-OpBuilder
    with-current-OpBuilder
    with-OpBuilder
    with-InsertionGuard)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir IR Builders ffi)
          (only (mlir support CrestObject) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; @brief Heap-allocate a CrestBox<mlir::OpBuilder> positioned at end of block.
  ;; Mirrors `static OpBuilder atBlockEnd(Block*, Listener* = nullptr)`.
  ;; @param block     Block* uptr — target block (uses current-MLIRContext for context)
  ;; @param listener  optional raw OpBuilder::Listener* uptr (see mlir::OpBuilder::getListener);
  ;;                  the builder reports its insertions to it. Default: none.
  ;; @return          CrestBox<OpBuilder>* shell uptr — free it via with-CrestObject, or use
  ;;                  with-OpBuilder
  ;; @see             mlir/IR/Builders.h
  (define mlir::OpBuilder::atBlockEnd
    (case-lambda
     [(block) (%mlir::OpBuilder::atBlockEnd (current-MLIRContext) block 0)]
     [(block listener) (%mlir::OpBuilder::atBlockEnd (current-MLIRContext) block listener)]))

  ;; @brief OpBuilder::getListener — the raw Listener* of a builder, 0 if it has none.
  ;; @param builder  builder shell uptr
  (define mlir::OpBuilder::getListener %mlir::OpBuilder::getListener)

  (define mlir::OpBuilder::setInsertionPoint
    %mlir::OpBuilder::setInsertionPoint)

  (define mlir::OpBuilder::setInsertionPointToEnd
    %mlir::OpBuilder::setInsertionPointToEnd)

  (define mlir::OpBuilder::create<OperationState>
    %mlir::OpBuilder::create<OperationState>)

  ;; @brief current-OpBuilder — dynamic parameter holding the builder begin-mlir-code creates
  ;; ops with: a builder shell (CrestBox<OpBuilder>, or the pattern's CrestBox<RewriterBase*>),
  ;; or #f when none is active. It keeps the real object, so rewriter-only operations work on it.
  ;; Mirrors current-MLIRContext; see mlir/IR/Builders.h.
  (define current-OpBuilder (make-parameter #f))

  ;; @brief with-current-OpBuilder — install a builder shell (or #f) as current-OpBuilder.
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ builder body ...)
       (parameterize ([current-OpBuilder builder]) body ...)]))

  ;; @brief with-OpBuilder — RAII for a builder created by INIT (e.g. atBlockEnd): binds VAR to
  ;; the builder shell for BODY and frees it on exit.
  ;; @example
  ;;   (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd block)
  ;;     (mlir::OpBuilder::create<OperationState> builder state))
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ var init body ...)
       (with-CrestObject var init body ...)]))

  ;; @brief with-InsertionGuard — mlir::OpBuilder::InsertionGuard: saves the insertion point of
  ;; BUILDER (a builder shell) and restores it when BODY exits, normally or not.
  ;; @example
  ;;   (with-InsertionGuard guard (builder)
  ;;     (mlir::OpBuilder::setInsertionPointToEnd builder block)
  ;;     ...)
  (define-syntax with-InsertionGuard
    (syntax-rules ()
      [(_ var (builder) body ...)
       (with-CrestObject var (%mlir::OpBuilder::InsertionGuard::InsertionGuard builder)
         body ...)]))

  ) ;; end library (mlir IR Builders)
