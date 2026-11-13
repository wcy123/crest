#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR PatternMatch) — RewriterBase user-visible API.
;;
;; Mirrors mlir/IR/PatternMatch.h RewriterBase.
;; Re-exports clean names from (mlir IR PatternMatch ffi).
;; Also provides RAII macros.
;;
;; The pattern's rewriter is a CrestBox<RewriterBase*> shell passed explicitly to
;; these bindings (replaceOp, eraseOp, setInsertionPoint, ...). The OpBuilder bindings and
;; the DSL accept the same shell.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR PatternMatch)
  (export
    ;; Clean-name re-exports from ffi
    mlir-create-operation
    mlir::RewriterBase::setInsertionPoint
    mlir::RewriterBase::setInsertionPointToEnd
    mlir::RewriterBase::setInsertionPointToStart
    mlir::RewriterBase::createBlock
    mlir::RewriterBase::replaceOp
    mlir::RewriterBase::eraseOp
    mlir::RewriterBase::create<OperationState>
    mlir::RewriterBase::inlineRegionBefore
    ;; Type predicates
    crest::isa<CrestBox<mlir::RewriterBase*>>?
    crest::isa<CrestBox<mlir::RewritePatternSet>>?
    ;; Adapters: a friendly procedure to one with the C types
    rewrite-pattern->c
    conversion-pattern->c
    ;; RAII macros
    with-RewritePatternSet)

  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (for (mlir Transforms DialectConversion options) expand)
          (only (crest callback) with-c-callable/lambda)
          (mlir support with)
          (only (mlir Transforms DialectConversion ffi)
                %add-conversion-pattern
                %add-conversion-pattern/ctx
                %add-rewrite-pattern)
          (only (mlir support CrestObject) with-CrestObject)
          (only (chezscheme) void)
          (only (mlir IR PatternMatch ffi)
                %mlir::RewriterBase::setInsertionPoint
                %mlir::RewriterBase::setInsertionPointToEnd
                %mlir::RewriterBase::setInsertionPointToStart
                %mlir::RewriterBase::createBlock
                %mlir::RewriterBase::replaceOp
                %mlir::RewriterBase::eraseOp
                %mlir::RewriterBase::create<OperationState>
                %mlir::RewriterBase::inlineRegionBefore
                %mlir::RewritePatternSet::RewritePatternSet
                %crest::isa<CrestBox<mlir::RewriterBase*>>
                %crest::isa<CrestBox<mlir::RewritePatternSet>>)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location) mlir::UnknownLoc::get)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getLoc)
          (only (mlir IR OperationSupport)
                mlir::OperationState::addOperands
                mlir::OperationState::addTypes
                mlir::OperationState::addRegion
                with-OperationState))

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  (define mlir-Operation::getContext mlir::Operation::getContext)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move IP to before op.
  (define mlir::RewriterBase::setInsertionPoint    %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPointToEnd %mlir::RewriterBase::setInsertionPointToEnd)
  (define mlir::RewriterBase::setInsertionPointToStart %mlir::RewriterBase::setInsertionPointToStart)

  ;; @brief mlir::RewriterBase::createBlock — append a new block to region.
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)

  ;; @brief mlir::RewriterBase::replaceOp — replace op with new values and erase it.
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)

  ;; @brief mlir::RewriterBase::eraseOp — erase op and all uses (must be dead).
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  (define mlir::RewriterBase::create<OperationState> %mlir::RewriterBase::create<OperationState>)

  ;; @brief mlir::RewriterBase::inlineRegionBefore — move all blocks of a region to the front of
  ;; another region. Rewriter-only: rw must be the pattern's CrestBox<RewriterBase*> shell.
  ;; @param rw    rewriter shell
  ;; @param src   Region* uptr; empty afterwards
  ;; @param dest  Region* uptr
  (define mlir::RewriterBase::inlineRegionBefore %mlir::RewriterBase::inlineRegionBefore)
  ;; Not exported: it answers a heap object that only with-RewritePatternSet frees (a raw call leaks it).
  (define mlir::RewritePatternSet::RewritePatternSet  %mlir::RewritePatternSet::RewritePatternSet)

  ;; @brief crest::isa<CrestBox<mlir::RewriterBase*>>? — is this ptr the pattern's rewriter shell?
  (define (crest::isa<CrestBox<mlir::RewriterBase*>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::RewriterBase*>> ptr))))

  ;; @brief crest::isa<CrestBox<mlir::RewritePatternSet>>? — is this ptr a CrestBox<mlir::RewritePatternSet>?
  (define (crest::isa<CrestBox<mlir::RewritePatternSet>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::RewritePatternSet>> ptr))))

  ;; @brief Create an op via a RewriterBase*.
  ;; (rw name operands types)                     — UnknownLoc, 0 regions
  ;; (rw name operands types nregions)            — UnknownLoc, N regions
  ;; (rw name operands types source-loc nregions) — explicit mlir::Location
  ;;
  ;; NOTE: rw is a CrestBox<RewriterBase*>*; %mlir::RewriterBase::create<OperationState>
  ;; extracts ->ptr internally. RewriterBase introduces the first vtable, so its
  ;; subobject offset differs from OpBuilder — these bindings are NOT interchangeable.
  (define mlir-create-operation
    (let ([build (lambda (rw name operands types source-loc nregions)
                   (with-OperationState state (source-loc name)
                     (for-each (lambda (v) (mlir::OperationState::addOperands state v)) operands)
                     (for-each (lambda (t) (mlir::OperationState::addTypes state t)) types)
                     (let loop ([i 0])
                       (when (< i nregions)
                         (mlir::OperationState::addRegion state)
                         (loop (+ i 1))))
                     (mlir::RewriterBase::create<OperationState> rw state)))])
      (case-lambda
       [(rw name operands types)
        (build rw name operands types (mlir::UnknownLoc::get) 0)]
       [(rw name operands types nregions)
        (build rw name operands types (mlir::UnknownLoc::get) nregions)]
       [(rw name operands types source-loc nregions)
        (build rw name operands types source-loc nregions)])))

  ;; A rewrite pattern (op rewriter) → #t when it rewrote the op; only #t succeeds. The procedure
  ;; with the C types: (op rewriter) → 1 or 0, every argument an address (uptr).
  (define (rewrite-pattern->c proc)
    (lambda (op rewriter) (if (eq? (proc op rewriter) #t) 1 0)))

  ;; A conversion pattern (op operands-ref rewriter type-converter) → #t when it rewrote the op; only
  ;; #t succeeds. The C types: (op operands rewriter type-converter) → 1 or 0, all uptr.
  (define (conversion-pattern->c proc)
    (lambda (op operands rewriter type-converter)
      (if (eq? (proc op operands rewriter type-converter) #t) 1 0)))

  ;; @brief with-RewritePatternSet — RAII for a heap-allocated RewritePatternSet.
  ;; @param var  identifier bound to the CrestBox<RewritePatternSet>* uptr for BODY
  ;; @param ctx  MLIRContext* uptr (optional, first; defaults to current-MLIRContext)
  ;; The options give the patterns as ordinary procedures. Each is a C function for the length of
  ;; BODY, released after the set is freed, so the set can be applied inside BODY:
  ;;   :rewrite-patterns        ((op-name proc [benefit]) ...)          proc (op rewriter) → #t
  ;;   :conversion-patterns     ((op-name proc type-converter [benefit]) ...)
  ;;                                          proc (op operands rewriter type-converter) → #t
  ;;   :conversion-patterns/ctx ((op-name proc [benefit]) ...)   the same without a type converter:
  ;;                                          the operands are the original ones
  ;; The benefit is 1 when it is not given.
  ;; @example
  ;;   (with-RewritePatternSet patterns (ctx :rewrite-patterns (("test.src" %%lower 10)))
  ;;     (mlir::applyPatternsGreedily module patterns))
  (define-syntax with-RewritePatternSet
    (lambda (stx)
      (define (parts entry low high usage)
        (let ([l (syntax->list entry)])
          (unless (and l (<= low (length l) high))
            (syntax-violation 'with-RewritePatternSet usage stx entry))
          l))
      (define (benefit-of l position)
        (if (> (length l) position) (list-ref l position) #'1))
      (syntax-case stx ()
        [(_ var (argument ...) body ...)
         (let* ([arguments (syntax->list #'(argument ...))]
                [has-context? (and (pair? arguments) (not (conversion-keyword? (car arguments))))]
                [options (conversion-options
                          'with-RewritePatternSet stx
                          (if has-context? (cdr arguments) arguments)
                          '(:rewrite-patterns :conversion-patterns :conversion-patterns/ctx))]
                [rewrite (map (lambda (e) (parts e 2 3 "a :rewrite-patterns entry is (op-name proc [benefit])"))
                              (conversion-option-list options ':rewrite-patterns))]
                [conversion (map (lambda (e)
                                   (parts e 3 4 "a :conversion-patterns entry is (op-name proc type-converter [benefit])"))
                                 (conversion-option-list options ':conversion-patterns))]
                [plain (map (lambda (e)
                              (parts e 2 3 "a :conversion-patterns/ctx entry is (op-name proc [benefit])"))
                            (conversion-option-list options ':conversion-patterns/ctx))])
           (with-syntax ([context-expression (if has-context? (car arguments) #'(current-MLIRContext))]
                         [(rewrite-name ...) (map car rewrite)]
                         [(rewrite-proc ...) (map cadr rewrite)]
                         [(rewrite-benefit ...) (map (lambda (l) (benefit-of l 2)) rewrite)]
                         [(conversion-name ...) (map car conversion)]
                         [(conversion-proc ...) (map cadr conversion)]
                         [(conversion-converter ...) (map caddr conversion)]
                         [(conversion-benefit ...) (map (lambda (l) (benefit-of l 3)) conversion)]
                         [(plain-name ...) (map car plain)]
                         [(plain-proc ...) (map cadr plain)]
                         [(plain-benefit ...) (map (lambda (l) (benefit-of l 2)) plain)])
             (with-syntax ([(rewrite-callable ...) (generate-temporaries #'(rewrite-name ...))]
                           [(conversion-callable ...) (generate-temporaries #'(conversion-name ...))]
                           [(plain-callable ...) (generate-temporaries #'(plain-name ...))])
               #'(let ([context context-expression])
                   (with*
                       ((with-c-callable/lambda (rewrite-callable (uptr uptr) int (rewrite-pattern->c rewrite-proc))) ...
                        (with-c-callable/lambda (conversion-callable (uptr uptr uptr uptr) int
                                                                     (conversion-pattern->c conversion-proc))) ...
                                                                     (with-c-callable/lambda (plain-callable (uptr uptr uptr uptr) int
                                                                                                             (conversion-pattern->c plain-proc))) ...)
                     (with-CrestObject var (mlir::RewritePatternSet::RewritePatternSet context)
                       (%add-rewrite-pattern var rewrite-name rewrite-callable rewrite-benefit) ...
                       (%add-conversion-pattern var conversion-name conversion-callable
                                                conversion-converter conversion-benefit) ...
                                                (%add-conversion-pattern/ctx var plain-name plain-callable plain-benefit) ...
                                                body ...))))))])))

  ) ;; end library (mlir IR PatternMatch)
