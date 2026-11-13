#!r6rs
;; Test: a Scheme expression's value can be named inside begin-mlir-code and used by a
;; later op-form: `stepped = (%%step elem ty)`.
(library (passes scheme-expr-binding)
  (export pass-entry-point)
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
                with-current-OpBuilder)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; Emits one op with the ambient builder and returns its result Value.
  (define (%%step v ty)
    (begin-mlir-code
        s = test.step (v) -> ty))

  ;; test.in(%v) -> test.load, test.step and test.use, where test.use takes the
  ;; value of the Scheme expression (%%step elem ty).
  (define (%%in op rw)
    (let* ([bld rw]
           [v   (mlir::Operation::getOperand op 0)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (mlir::RewriterBase::setInsertionPoint rw op)
      (let ([r (with-current-OpBuilder bld
                 (begin-mlir-code
                     elem    = test.load (v) -> ty
                     stepped = (%%step elem ty)
                     next    = test.use (stepped) -> ty))])
        (mlir::RewriterBase::replaceOp rw op r)
        #t)))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet ps (ctx
                                    :rewrite-patterns (("test.in" %%in 10)))
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library
