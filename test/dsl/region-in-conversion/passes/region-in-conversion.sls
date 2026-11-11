#!r6rs
;; Test: ops created in a region body by begin-mlir-code inside a conversion pattern are
;; legalized by the conversion driver.
;;
;;   test.src   -->  test.wrapper { ^bb0: test.inner }
;;   test.inner -->  test.done
(library (passes region-in-conversion)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (mlir Transforms DialectConversion)
          (crest))

  (define-conversion-pattern (%%wrap op operands-ref rw tc)
    :if-match
      test.src ()
    :rewrite op :with
      test.wrapper ()
      (^bb0 ()
            test.inner ()))

  (define-conversion-pattern (%%inner->done op operands-ref rw tc)
    :if-match
      test.inner ()
    :rewrite op :with
      test.done ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-ConversionTarget target (ctx
                                       :dynamically-legal (("test.src" (lambda (op) #f))
                                                           ("test.inner" (lambda (op) #f)))
                                       :unknown-legal (lambda (op) #t))
          (with-RewritePatternSet patterns (ctx
                                            :conversion-patterns/ctx (("test.src" %%wrap 1)
                                                                      ("test.inner" %%inner->done 1)))
            (apply-full-conversion module-op target patterns))))))

  ) ;; end library
