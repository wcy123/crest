#!r6rs
;; Test: a source/target materialization callback gets a raw mlir::OpBuilder*.
;; tensor<4xf32> is converted to tensor<?xf32>; the callback materializes tensor.cast.
(library (passes materialization-builder)
  (export run-pass)
  (import (rnrs)
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
          (mlir Transforms DialectConversion))

  ;; A type attribute parsed from text: tensor<?xf32>.
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

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-TypeConverter tc (:conversions ((lambda (type) type)
                                              %%convert)
                                             :source-materializations (%%materialize)
                                             :target-materializations (%%materialize))
          (with-ConversionTarget target (ctx
                                         :dynamically-legal (("func.func" (lambda (op)
                                                                            (eqv? 1 (type-converter-is-signature-legal tc op)))))
                                         :unknown-legal (lambda (op) #t))
            (with-RewritePatternSet patterns (ctx)
              (populate-func-type-conversion patterns tc)
              (apply-full-conversion module-op target patterns)))))))

  ) ;; end library
