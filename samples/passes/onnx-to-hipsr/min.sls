#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Min → chain of hipsr.min
;;
;; Binary case (N=2): DSL pattern with inline broadcast shape region.
;; N=1: identity (replace with single input).
;; N>2: chain binary hipsr.min ops (plain Scheme).
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr min)
  (export populate-min-patterns)
  (import (except (rnrs (6)) =)

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (mlir support array-ref)
          (only (mlir IR PatternMatch) mlir::RewriterBase::replaceOp mlir::RewriterBase::setInsertionPoint
                conversion-pattern->c)
          (only (crest callback) define-c-callable)
          (only (mlir IR Builders) with-current-OpBuilder)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Tensor IR)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding)
          (only (mlir Dialect Shape IR Shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (only (crest) begin-mlir-code)
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::getResult)
          )

  ;;===--------------------------------------------------------------------===;;
  ;; Binary case — DSL with inline broadcast shape region (identical to equal)
  ;;===--------------------------------------------------------------------===;;

  (define-conversion-pattern (onnx-min-2->hipsr op operands-ref rewriter type-converter)
    :if-match
      %output = onnx.Min (%lhs %rhs)
    :then-let
      ([%ctx        (mlir-get-hipsr-context-arg op)]
       [!out-type   (mlir::Value::getType %output)]
       [!out-device (mlir::RankedTensorType::cloneWithEncoding !out-type (make-hipsr-device-space-attr))]
       [!shape-type (mlir::shape::ShapeType::get)])
    :rewrite %output :with
      placeholder = hipsr.placeholder (%ctx %lhs %rhs)
      (^bb0 ((%ls : !shape-type) (%rs : !shape-type))
            broadcast = shape.broadcast (%ls %rs) -> !shape-type ;
            hipsr.shape_yield (broadcast)) ;
      -> !out-device ;
      result = hipsr.min (%ctx %lhs %rhs placeholder) -> !out-device) ;

  ;;===--------------------------------------------------------------------===;;
  ;; General case — N=1 identity; N>2 chain (binary DSL pattern handles N=2)
  ;;===--------------------------------------------------------------------===;;

  (define (make-binary-min! rewriter loc-op ctx lhs rhs out-type)
    (let ([!shape-type (mlir::shape::ShapeType::get)])
      (mlir::RewriterBase::setInsertionPoint rewriter loc-op)
      (with-current-OpBuilder rewriter
        (begin-mlir-code
            ph = hipsr.placeholder (ctx lhs rhs)
            (^bb0 ((%ls : !shape-type) (%rs : !shape-type))
                  bc = shape.broadcast (%ls %rs) -> !shape-type
                  hipsr.shape_yield (bc))
            -> out-type
            r = hipsr.min (ctx lhs rhs ph) -> out-type))))

  (define (%%min-general op operands-ref rewriter type-converter)
    (let ([n (crest::CArrayRef::size operands-ref)])
      (cond
       [(eqv? n 1)
        (mlir::RewriterBase::replaceOp rewriter op (crest::CArrayRef::at operands-ref 0))
        #t]
       [(> n 2)
        (let* ([ctx      (mlir-get-hipsr-context-arg op)]
               [!base    (mlir::Value::getType (mlir::Operation::getResult op 0))]
               [out-type (mlir::RankedTensorType::cloneWithEncoding !base
                                                                    (make-hipsr-device-space-attr))])
          (let loop ([i 2]
                     [acc (make-binary-min! rewriter op ctx
                                            (crest::CArrayRef::at operands-ref 0)
                                            (crest::CArrayRef::at operands-ref 1)
                                            out-type)])
            (if (eqv? i n)
                (begin (mlir::RewriterBase::replaceOp rewriter op acc) #t)
                (loop (+ i 1)
                      (make-binary-min! rewriter op ctx acc
                                        (crest::CArrayRef::at operands-ref i) out-type)))))]
       [else #f])))

  ;; Made once, when the library is loaded, and kept for the whole program.
  (define-c-callable onnx-min-general->hipsr ((op uptr) (operands uptr) (rewriter uptr) (type-converter uptr)) int
    (if (eq? (%%min-general op operands rewriter type-converter) #t) 1 0))

  (define-c-callable onnx-min-2->hipsr-callable ((op uptr) (operands uptr) (rewriter uptr) (type-converter uptr)) int
    (if (eq? (onnx-min-2->hipsr op operands rewriter type-converter) #t) 1 0))

  (define (populate-min-patterns type-converter patterns ctx)
    ;; DSL pattern for the common binary case (N=2) — inline shape region
    (add-conversion-pattern patterns "onnx.Min" onnx-min-2->hipsr-callable    type-converter 1)
    ;; Scheme fallback for N=1 (identity) and N>2 (chain)
    (add-conversion-pattern patterns "onnx.Min" onnx-min-general->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr min)
