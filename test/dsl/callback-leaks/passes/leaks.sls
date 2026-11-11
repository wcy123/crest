#!r6rs
;; The per-run callbacks of the conversion and pattern APIs, one procedure per way of using them.
;; Each takes the module to rewrite. test/dsl/callback-leaks/driver.sls runs them many times and checks
;; that none of them leaves a C function (a locked code object) behind.
(library (passes leaks)
  (export conversion-full conversion-partial unused-sets rewrite-greedy modify-in-place)
  (import (except (rnrs) =)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getAttr
                mlir::Operation::setAttr!)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR BuiltinAttributes) mlir::UnitAttr::get)
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

  (define-rewrite-pattern (%%rw op rewriter)
    :if-match
      test.rw ()
    :rewrite op :with
      test.rw_done ())

  (define (%%mark op rewriter)
    (let ([marked (mlir::Operation::getAttr op "marked")])
      (and (or (not marked) (eqv? marked 0))
           (begin
             (mlir::RewriterBase::modifyOpInPlace
              rewriter op
              (lambda () (mlir::Operation::setAttr! op "marked" (mlir::UnitAttr::get))))
             #t))))

  ;; Every kind of callback of a conversion: a type conversion, both materializations, a pattern with
  ;; and one without the type converter, a legality check of an op, and one of all the other ops.
  (define (%%register! ctx tc target patterns)
    (type-converter-add-conversion tc (lambda (type) type))
    (mlir::TypeConverter::addSourceMaterialization tc (lambda (builder type inputs loc) #f))
    (mlir::TypeConverter::addTargetMaterialization tc (lambda (builder type inputs loc) #f))
    (target-add-legal-dialect target "func")
    (target-add-legal-dialect target "builtin")
    (target-add-legal-op target ctx "test.a_done")
    (target-add-legal-op target ctx "test.b_done")
    (target-add-dynamically-legal-op target ctx "test.a" (lambda (op) #f))
    (target-add-dynamically-legal-op target ctx "test.b" (lambda (op) #f))
    (target-mark-unknown-ops-dynamically-legal target (lambda (op) #t))
    (add-conversion-pattern patterns "test.a" %%a tc 1)
    (add-conversion-pattern/ctx patterns "test.b" %%b 1))

  (define (conversion-full module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc ()
          (with-ConversionTarget target (ctx)
            (with-RewritePatternSet patterns (ctx)
              (%%register! ctx tc target patterns)
              (apply-full-conversion module-op target patterns)))))))

  (define (conversion-partial module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc ()
          (with-ConversionTarget target (ctx)
            (with-RewritePatternSet patterns (ctx)
              (%%register! ctx tc target patterns)
              (mlir::applyPartialConversion module-op target patterns)))))))

  ;; Registered and never applied: the callbacks are released when the three objects are freed.
  (define (unused-sets module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc ()
          (with-ConversionTarget target (ctx)
            (with-RewritePatternSet patterns (ctx)
              (%%register! ctx tc target patterns)
              (add-rewrite-pattern patterns "test.rw" (lambda (op rewriter) #f) 1)))))))

  (define (rewrite-greedy module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("test.rw" %%rw 1))))))

  (define (modify-in-place module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("test.mark" %%mark 1))))))

  ) ;; end library
