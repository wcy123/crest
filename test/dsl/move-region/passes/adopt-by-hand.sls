#!r6rs
;; Control: moving a region into a new op by hand, the only way today. test.src is replaced by
;; test.dst, and the body of test.src is moved into it (the same block, with its argument and
;; its ops), as a function-like lowering does with inlineRegionBefore.
(library (passes adopt-by-hand)
  (export pass-entry-point)
  (import (only (crest pass) define-pass-entry-point)
          (rnrs)
          (only (mlir IR Operation) mlir::Operation::getContext mlir::Operation::getLoc
                mlir::Operation::getRegion)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR OperationSupport) with-OperationState mlir::OperationState::addRegion)
          (only (mlir IR Builders) mlir::OpBuilder::create<OperationState>)
          (only (mlir IR PatternMatch) with-RewritePatternSet mlir::RewriterBase::setInsertionPoint
                mlir::RewriterBase::eraseOp mlir::RewriterBase::inlineRegionBefore)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  (define (%%adopt op rw)
    (mlir::RewriterBase::setInsertionPoint rw op)
    (let ([new-op (with-OperationState state ((mlir::Operation::getLoc op) "test.dst")
                    (mlir::OperationState::addRegion state)
                    (mlir::OpBuilder::create<OperationState>
                     rw state))])
      (mlir::RewriterBase::inlineRegionBefore rw
                                              (mlir::Operation::getRegion op 0)
                                              (mlir::Operation::getRegion new-op 0))
      (mlir::RewriterBase::eraseOp rw op)
      #t))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%adopt 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library
