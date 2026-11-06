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
;; Handle convention: every binding that takes an OpBuilder takes a RAW
;; mlir::OpBuilder* uptr. CrestObject shells (CrestBox<OpBuilder> from
;; atBlockEnd, CrestBox<RewriterBase*> for a pattern's rw) are unwrapped once
;; with crest::as_ptr<mlir::OpBuilder>, or by with-OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Builders)
  (export
    mlir::OpBuilder::atBlockEnd
    mlir::OpBuilder::getListener
    mlir::OpBuilder::create<OperationState>
    mlir::OpBuilder::setInsertionPoint
    crest::as_ptr<mlir::OpBuilder>
    current-OpBuilder
    with-current-OpBuilder
    with-OpBuilder)
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
  ;;                  with-OpBuilder, which also unwraps it
  ;; @see             mlir/IR/Builders.h
  (define mlir::OpBuilder::atBlockEnd
    (case-lambda
     [(block) (%mlir::OpBuilder::atBlockEnd (current-MLIRContext) block 0)]
     [(block listener) (%mlir::OpBuilder::atBlockEnd (current-MLIRContext) block listener)]))

  ;; @brief OpBuilder::getListener — the raw Listener* of a builder, 0 if it has none.
  ;; @param builder  raw OpBuilder* uptr
  (define mlir::OpBuilder::getListener %mlir::OpBuilder::getListener)

  (define mlir::OpBuilder::setInsertionPoint
    %mlir::OpBuilder::setInsertionPoint)

  (define mlir::OpBuilder::create<OperationState>
    %mlir::OpBuilder::create<OperationState>)

  ;; @brief crest::as_ptr<mlir::OpBuilder> — unwrap a builder shell to a raw mlir::OpBuilder*.
  ;; Accepts a CrestBox<OpBuilder> shell or a CrestBox<RewriterBase*> shell (the rewriter
  ;; of a pattern callback). The C++ side upcasts statically, which adjusts the address:
  ;; RewriterBase is polymorphic and its OpBuilder base is not at offset 0. Anything that is
  ;; not a shell (including an already-raw pointer) is an error.
  ;; @param shell  CrestBox<OpBuilder>* or CrestBox<RewriterBase*>* uptr
  ;; @return       raw mlir::OpBuilder* uptr
  (define crest::as_ptr<mlir::OpBuilder> %crest::as_ptr<mlir::OpBuilder>)

  ;; @brief current-OpBuilder — dynamic parameter holding the ambient raw mlir::OpBuilder*
  ;; uptr (never a CrestObject shell), or #f when no builder is active.
  ;; Mirrors current-MLIRContext; see mlir/IR/Builders.h.
  (define current-OpBuilder (make-parameter #f))

  ;; @brief with-current-OpBuilder — install a raw OpBuilder* (or #f) as current-OpBuilder.
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ builder body ...)
       (parameterize ([current-OpBuilder builder]) body ...)]))

  ;; @brief with-OpBuilder — RAII for a builder created by INIT (e.g. atBlockEnd): binds VAR to
  ;; the raw mlir::OpBuilder* for BODY and frees the shell on exit.
  ;; @example
  ;;   (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd block)
  ;;     (mlir::OpBuilder::create<OperationState> builder state))
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ var init body ...)
       (with-CrestObject shell init
         (let ([var (crest::as_ptr<mlir::OpBuilder> shell)])
           body ...))]))

  ) ;; end library (mlir IR Builders)
