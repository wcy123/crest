#!r6rs
;; Two patterns for test.a: one makes test.wrap with a region and a block, the other makes test.wrap
;; without a region. test.bad has no pattern and is illegal, so the conversion fails and rolls back.
(library (passes blocks)
  (export convert-with-block convert-without-block)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  (define-conversion-pattern (%%with-block op operands-ref rw tc)
    :if-match
      test.a ()
    :rewrite op :with
      test.wrap ()
      (^body () test.inner ()))

  (define-conversion-pattern (%%without-block op operands-ref rw tc)
    :if-match
      test.a ()
    :rewrite op :with
      test.wrap ())

  (define (%%convert module-op pattern)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
                          :mode partial
                          :legal-ops ("test.wrap" "test.inner")
                          :dynamically-legal (("test.a" (lambda (op) #f))
                                              ("test.bad" (lambda (op) #f)))
                          :patterns (("test.a" pattern))))))

  (define (convert-with-block module-op) (%%convert module-op %%with-block))
  (define (convert-without-block module-op) (%%convert module-op %%without-block))

  ) ;; end library
