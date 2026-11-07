#!r6rs
;; The same conversion with the configure hooks of apply-conversion.
(library (passes declarative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion)
                type-converter-add-conversion
                target-add-legal-dialect
                target-add-illegal-dialect
                target-add-legal-op)
          (crest))

  (define converter-configured? #f)

  (define (%%configure-type-converter! tc)
    (set! converter-configured? #t)
    (type-converter-add-conversion tc (lambda (type) type)))

  (define (%%configure-target! target tc ctx)
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
        (unless (apply-conversion module-op ctx
                                  :mode                    partial
                                  :configure-type-converter %%configure-type-converter!
                                  :configure-target         (lambda (target tc) (%%configure-target! target tc ctx))
                                  :patterns                (("test.a" %%a)))
          (error 'run-pass "conversion failed")))
      (unless converter-configured? (error 'run-pass "converter hook did not run"))))

  ) ;; end library
