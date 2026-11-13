#!r6rs
;; The same conversion written with apply-conversion.
(library (passes declarative)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (crest callback) define-c-callable)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion) add-conversion-pattern with-TypeConverter)
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

  (define-c-callable %%c-callable ((op uptr) (operands uptr) (rewriter uptr) (type-converter uptr)) int
    (if (eq? (%%c op operands rewriter type-converter) #t) 1 0))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
                          :partial-mode
                          :converter         (with-TypeConverter type-converter
                                               :conversions ((lambda (type) type)))
                          :legal-dialects    ("func" "builtin")
                          :illegal-dialects  ("test")
                          :legal-ops         ("test.a_done" "test.b_done" "test.c_done")
                          :dynamically-legal (("test.keep" (lambda (op) #t)))
                          :patterns          (("test.a" %%a)
                                              ("test.b" %%b :no-type-converter))
                          :populate          (lambda (tc patterns)
                                               (add-conversion-pattern patterns "test.c" %%c-callable tc 1))))))

  ) ;; end library
