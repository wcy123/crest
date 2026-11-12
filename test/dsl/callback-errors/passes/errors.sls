#!r6rs
;; Callbacks that raise: each scenario runs one kind of callback whose procedure raises (error 'callback "boom").
;; The error must come out of the binding that ran the callback, in Scheme, with its message.
(library (passes errors)
  (export walk-raises legality-raises pattern-raises conversion-raises modify-raises)
  (import (except (rnrs) =)
          (only (mlir IR Operation)
                mlir::Operation::getContext mlir::Operation::walk
                mlir::Operation::getAttr mlir::Operation::setAttr!)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (mlir support with)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR BuiltinAttributes) mlir::UnitAttr::get)
          (only (mlir IR BuiltinTypes) mlir::IndexType::get)
          (mlir Transforms DialectConversion)
          (crest))

  (define (boom . ignored) (error 'callback "boom"))

  ;; a walk whose visitor raises
  (define (walk-raises module-op)
    (mlir::Operation::walk module-op boom))

  (define-conversion-pattern (%%convert op operands-ref rw tc)
    :if-match
      test.a ()
    :rewrite op :with
      test.a_done ())

  ;; a legality check that raises
  (define (legality-raises module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with* ((with-current-MLIRContext ctx)
              (with-TypeConverter type-converter)
              (with-ConversionTarget target (ctx :dynamically-legal (("test.a" boom))))
              (with-RewritePatternSet patterns (ctx :conversion-patterns (("test.a" %%convert type-converter 1)))))
        (mlir::applyPartialConversion module-op target patterns))))

  ;; a conversion pattern that raises
  (define (pattern-raises module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with* ((with-current-MLIRContext ctx)
              (with-TypeConverter type-converter)
              (with-ConversionTarget target (ctx :dynamically-legal (("test.a" (lambda (op) #f)))))
              (with-RewritePatternSet patterns (ctx :conversion-patterns (("test.a" boom type-converter 1)))))
        (mlir::applyPartialConversion module-op target patterns))))

  ;; a type conversion that raises: asking the converter whether a type is legal runs its conversions
  (define (conversion-raises module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter type-converter :conversions (boom)
                            (type-converter-is-legal-type type-converter (mlir::IndexType::get ctx))))))

  ;; a modifyOpInPlace thunk that raises, inside a greedy rewrite
  (define-rewrite-pattern (%%modify op rewriter)
    :if-match
      test.rw ()
    :rewrite op :with
      test.rw_done ())

  (define (modify-raises module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
                        :patterns (("test.rw" (lambda (op rewriter)
                                                (mlir::RewriterBase::modifyOpInPlace rewriter op boom)
                                                #t) 1))))))

  ) ;; end library
