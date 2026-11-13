#!r6rs
;; The same conversion with the configure hooks of apply-conversion.
(library (passes declarative)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (crest callback) define-c-callable)
          (only (mlir Transforms DialectConversion)
                type-converter-add-conversion
                target-add-legal-dialect
                target-add-illegal-dialect
                target-add-legal-op)
          (crest))

  (define converter-configured? #f)

  ;; The conversion is made once, when the library is loaded, and kept for the whole program.
  (define-c-callable identity-conversion ((type uptr)) uptr type)

  (define (%%configure-type-converter! tc)
    (set! converter-configured? #t)
    (type-converter-add-conversion tc identity-conversion))

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

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (unless (apply-conversion module-op ctx
                                  :partial-mode
                                  :configure-type-converter %%configure-type-converter!
                                  :configure-target         (lambda (target tc) (%%configure-target! target tc ctx))
                                  :patterns                (("test.a" %%a)))
          (error 'pass-entry-point "conversion failed")))
      (unless converter-configured? (error 'pass-entry-point "converter hook did not run"))))

  ) ;; end library
