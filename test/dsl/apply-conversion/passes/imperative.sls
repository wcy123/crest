#!r6rs
;; The control: a partial conversion registered with the low-level API, as every conversion
;; pass does today (compare %%toy-to-affine-lower! in samples/toy/ch5/lower-to-affine.sls).
;;
;;   test.a      -->  test.a_done   pattern with the type converter
;;   test.b      -->  test.b_done   pattern without the type converter (original operand types)
;;   test.c      -->  test.c_done   pattern registered by hand, as a populate hook does
;;   test.keep                      dynamically legal: kept
;;   other.x                        a dialect the target does not mention: kept (partial mode)
(library (passes imperative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (mlir Transforms DialectConversion)
          (crest))

  (define-conversion-pattern (%%a op operands-ref rw tc)
    :if-match
      test.a ()
    :rewrite op :with
      test.a_done ())

  (define-conversion-pattern (%%b op operands-ref rw tc)
    :if-match
      test.b ()
    :rewrite op :with
      test.b_done ())

  (define-conversion-pattern (%%c op operands-ref rw tc)
    :if-match
      test.c ()
    :rewrite op :with
      test.c_done ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc (:conversions ((lambda (type) type)))
          (with-ConversionTarget target (ctx
                                         :dynamically-legal (("test.keep" (lambda (op) #t))))
            (target-add-legal-dialect target "func")
            (target-add-legal-dialect target "builtin")
            (target-add-illegal-dialect target "test")
            (target-add-legal-op target ctx "test.a_done")
            (target-add-legal-op target ctx "test.b_done")
            (target-add-legal-op target ctx "test.c_done")
            (with-RewritePatternSet patterns (ctx
                                              :conversion-patterns (("test.a" %%a tc 1)
                                                                    ("test.c" %%c tc 1))
                                              :conversion-patterns/ctx (("test.b" %%b 1)))
              (eqv? 1 (mlir::applyPartialConversion module-op target patterns))))))))

  ) ;; end library
