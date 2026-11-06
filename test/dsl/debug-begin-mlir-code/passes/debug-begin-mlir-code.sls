#!r6rs
;; Test: CREST_DEBUG_BEGIN_MLIR_CODE appends every begin-mlir-code expansion in a
;; library to one file. This library has two forms.
(library (passes debug-begin-mlir-code)
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
                with-current-OpBuilder)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; First form.
  (define (%%emit-a v ty)
    (begin-mlir-code
        a = test.a (v) -> ty))

  ;; test.in(%v) -> test.b(test.a(%v)); the second begin-mlir-code form is here.
  (define (%%in op rw)
    (let* ([bld rw]
           [v   (mlir::Operation::getOperand op 0)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (mlir::RewriterBase::setInsertionPoint rw op)
      (let ([r (with-current-OpBuilder bld
                 (let ([a (%%emit-a v ty)])
                   (begin-mlir-code
                       b = test.b (a) -> ty)))])
        (mlir::RewriterBase::replaceOp rw op r)
        #t)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet ps (ctx)
          (add-rewrite-pattern ps "test.in" %%in 10)
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library
