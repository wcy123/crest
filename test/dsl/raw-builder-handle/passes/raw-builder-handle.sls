;; test.in(%v) -> test.out(%v), built through a raw OpBuilder* unwrapped from the rewriter shell.
(library (passes raw-builder-handle)
  (export run-pass)
  (import (except (rnrs (6)) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getLoc
                mlir::Operation::getOperand
                mlir::Operation::getResult)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet mlir::RewriterBase::replaceOp)
          (only (mlir IR Builders)
                crest::as_ptr<mlir::OpBuilder>
                mlir::OpBuilder::create<OperationState>
                mlir::OpBuilder::setInsertionPoint)
          (only (mlir IR OperationSupport)
                with-OperationState
                mlir::OperationState::addOperands
                mlir::OperationState::addTypes)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  (define (%%pattern op rw)
    (let* ([bld (crest::as_ptr<mlir::OpBuilder> rw)]
           [loc (mlir::Operation::getLoc op)]
           [v   (mlir::Operation::getOperand op 0)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))]
           ;; Unwrapping the raw pointer again must fail; if it does not, the pattern
           ;; is not applied and the CHECK lines fail.
           [rejected? (guard (e [#t #t])
                        (crest::as_ptr<mlir::OpBuilder> bld)
                        #f)])
      (and rejected?
           (begin
             (mlir::OpBuilder::setInsertionPoint bld op)
             (let ([new-op (with-OperationState s (loc "test.out")
                             (mlir::OperationState::addOperands s v)
                             (mlir::OperationState::addTypes s ty)
                             (mlir::OpBuilder::create<OperationState> bld s))])
               (mlir::RewriterBase::replaceOp rw op (mlir::Operation::getResult new-op 0))
               #t)))))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps ctx)
          (add-rewrite-pattern ps "test.in" %%pattern 10)
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library
