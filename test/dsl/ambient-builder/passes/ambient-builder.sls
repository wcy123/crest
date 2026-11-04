#!r6rs
;; Test: begin-mlir-code has no builder argument; it uses the ambient current-OpBuilder.
(library (passes ambient-builder)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getOperand
                mlir::Operation::getResult)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch)
                with-RewritePatternSet
                mlir::RewriterBase::replaceOp
                mlir::RewriterBase::setInsertionPoint)
          (only (mlir IR Builders)
                crest::as_ptr<mlir::OpBuilder>
                with-current-OpBuilder)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; No builder parameter: uses the builder that :rewrite :with installed.
  (define (%%emit-pair v ty)
    (begin-mlir-code
        a = test.step_a (v) -> ty
        b = test.step_b (a) -> ty))

  ;; test.one(%v) -> test.step_b(test.step_a(%v))
  (define-rewrite-pattern (%%one op rewriter)
    :if-match
      %out = test.one (%v)
    :then-let
      ([!ty (mlir::Value::getType %v)])
    :rewrite %out :with
      (%%emit-pair %v !ty))

  ;; test.two(%v) -> test.two_out(%v), with the builder supplied by the caller.
  (define (%%two op rw)
    (let* ([bld (crest::as_ptr<mlir::OpBuilder> rw)]
           [v   (mlir::Operation::getOperand op 0)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (mlir::RewriterBase::setInsertionPoint rw op)
      (let ([r (with-current-OpBuilder bld
                 (begin-mlir-code
                     r = test.two_out (v) -> ty))])
        (mlir::RewriterBase::replaceOp rw op r)
        #t)))

  ;; test.three(%v): begin-mlir-code with no builder installed must raise.
  (define (%%three op rw)
    (let* ([bld (crest::as_ptr<mlir::OpBuilder> rw)]
           [v   (mlir::Operation::getOperand op 0)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))]
           [raised? (guard (e [#t #t])
                      (begin-mlir-code
                          r = test.never (v) -> ty)
                      #f)])
      (and raised?
           (begin
             (mlir::RewriterBase::setInsertionPoint rw op)
             (let ([r (with-current-OpBuilder bld
                        (begin-mlir-code
                            r = test.three_ok (v) -> ty))])
               (mlir::RewriterBase::replaceOp rw op r)
               #t)))))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet ps (ctx)
          (add-rewrite-pattern ps "test.one" %%one 10)
          (add-rewrite-pattern ps "test.two" %%two 10)
          (add-rewrite-pattern ps "test.three" %%three 10)
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library
