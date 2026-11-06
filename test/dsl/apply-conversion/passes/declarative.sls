#!r6rs
;; The same conversion written with the declarative form proposed in plans/08 (G8). apply-conversion
;; does not exist yet, so this library does not compile.
(library (passes declarative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion) add-conversion-pattern)
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
        (apply-conversion module-op ctx
                          :mode              partial
                          :type-converter    (lambda (type) type)
                          :legal-dialects    ("func" "builtin")
                          :illegal-dialects  ("test")
                          :legal-ops         ("test.a_done" "test.b_done" "test.c_done")
                          :dynamically-legal (("test.keep" (lambda (op) #t)))
                          :patterns          (("test.a" %%a)
                                              ("test.b" %%b :no-type-converter))
                          :populate          (lambda (tc patterns)
                                               (add-conversion-pattern patterns "test.c" %%c tc 1))))))

  ) ;; end library
