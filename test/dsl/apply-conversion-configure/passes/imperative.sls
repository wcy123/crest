#!r6rs
;; The control: the low-level API, with the two setup helpers called by hand.
(library (passes imperative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (mlir Transforms DialectConversion)
          (crest))

  (define converter-configured? #f)

  (define (%%configure-type-converter! tc)
    (set! converter-configured? #t)
    (type-converter-add-conversion tc (lambda (type) type)))

  (define (%%configure-target! target ctx tc)
    (target-add-legal-dialect target "func")
    (target-add-legal-dialect target "builtin")
    (target-add-illegal-dialect target "test")
    (target-add-legal-op target ctx "test.a_done"))

  (define-conversion-pattern (%%a op operands-ref rw tc)
    :if-match
      test.a ()
    :rewrite op :with
      test.a_done ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc ()
          (%%configure-type-converter! tc)
          (with-ConversionTarget target (ctx)
            (%%configure-target! target ctx tc)
            (with-RewritePatternSet patterns (ctx)
              (add-conversion-pattern patterns "test.a" %%a tc 1)
              (unless (eqv? 1 (mlir::applyPartialConversion module-op target patterns))
                (error 'run-pass "conversion failed"))))))
      (unless converter-configured? (error 'run-pass "converter hook did not run"))))

  ) ;; end library
