#!r6rs
;; The root of a conversion pattern with an (:optional ...) operand. Its two operands are tensor<4xf32>,
;; which the type converter turns into tensor<?xf32>: the pattern gets the operands in the converted type,
;; as the root with only required operands does (test/dsl/materialization-target).
(library (passes conversion-flex)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::getShape
                mlir::isa<RankedTensorType>?)
          (only (mlir IR BuiltinAttributes)
                mlir::parseAttribute
                mlir::TypeAttr::getValue)
          (only (mlir Dialect Tensor IR) mlir::tensor::CastOp::create)
          (mlir Transforms DialectConversion)
          (crest))

  (define (%%dynamic-tensor-type)
    (mlir::TypeAttr::getValue (mlir::parseAttribute "tensor<?xf32>")))

  (define (%%convert type)
    (and (mlir::isa<RankedTensorType>? type)
         (equal? (mlir::RankedTensorType::getShape type) '(4))
         (%%dynamic-tensor-type)))

  (define (%%materialize builder result-type inputs loc)
    (and (pair? inputs)
         (null? (cdr inputs))
         (mlir::tensor::CastOp::create builder loc result-type (car inputs))))

  (define-conversion-pattern (%%conv op operands-ref rw tc)
    :if-match
      test.conv (%x (:optional %y))
    :rewrite op :with
      test.conv_done (%x %y))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc :conversions ((lambda (type) type)
                                             %%convert)
                            :target-materializations (%%materialize)
                            (with-ConversionTarget target (ctx
                                                           :dynamically-legal (("test.conv" (lambda (op) #f)))
                                                           :unknown-legal (lambda (op) #t))
                              (with-RewritePatternSet patterns (ctx
                                                                :conversion-patterns (("test.conv" %%conv tc 1)))
                                (apply-full-conversion module-op target patterns)))))))

  ) ;; end library
