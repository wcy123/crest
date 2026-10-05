#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Constant → hipsr.constant (or arith.constant for rank-0 scalars)
;;
;; Two patterns, selected by rank via :where guard:
;;   onnx-constant-scalar→arith — rank-0 → arith.constant (host type)
;;   onnx-constant-tensor→hipsr — rank>0 → hipsr.constant (device type)
;; Both handle inline value and external data (location/offset/size).
;;
;; External data (location/offset/size) is handled via DenseResourceElementsAttr
;; constructed through %mlir::DenseResourceElementsAttr::get.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr constant)
  (export populate-constant-patterns)
  (import (except (rnrs (6)) =)

          (only (mlir ir value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir ir builtin-attributes ffi) %mlir::DenseResourceElementsAttr::get)
          (mlir transforms dialect-conversion)
          (mlir dialects hipsr)
          (mlir dialect tensor ir)
          (crest)
          (only (mlir ir operation)
                mlir::Operation::emitError mlir::Operation::getAttr mlir::Operation::getAttrOfType<IntegerAttr> mlir::Operation::getAttrOfType<StringAttr> mlir::Operation::getContext mlir::Operation::hasAttr?)

          (only (mlir ir builtin-types)
                mlir::RankedTensorType::getRank))

  (define ort-mem-addr-tag "*/_ORT_MEM_ADDR_/*")

  ;; Build a value attr (ElementsAttr) for the constant.
  ;; For inline: reads the "value" attr directly.
  ;; For external: constructs DenseResourceElementsAttr.
  ;; Emits an MLIR diagnostic and raises on error — never returns #f.
  (define (constant-value-attr op ctx !result-type)
    (define (fail msg)
      (mlir::Operation::emitError op msg)
      (error 'onnx-constant msg))
    (cond
      [(mlir::Operation::hasAttr? op "value")
       (mlir::Operation::getAttr op "value")]
      [(mlir::Operation::hasAttr? op "location")
       (let* ([location (mlir::Operation::getAttrOfType<StringAttr> op "location")]
              [offset   (mlir::Operation::getAttrOfType<IntegerAttr> op "offset" 0)]
              [size     (mlir::Operation::getAttrOfType<IntegerAttr> op "size" 0)]
              [r (if (string=? location ort-mem-addr-tag)
                     (%mlir::DenseResourceElementsAttr::get ctx
                       (list !result-type
                             (string-append "mem|0x" (number->string offset 16))
                             offset size))
                     (let ([buf (mlir-hipsr-load-file-map ctx location)])
                       (if (zero? buf)
                           (fail (string-append "cannot memory-map: " location))
                           (%mlir::DenseResourceElementsAttr::get ctx
                             (list !result-type
                                   (string-append "file|" location "|"
                                                  (number->string offset))
                                   (+ buf offset) size)))))])
         (if (zero? r) (fail "cannot build dense resource attr") r))]
      [else
       (fail "onnx.Constant has neither value nor location")]))

  ;; Pattern 1: rank-0 scalar → arith.constant (host result type)
  (define-conversion-pattern (onnx-constant-scalar->arith op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.Constant ()
            :where (zero? (mlir::RankedTensorType::getRank (mlir::Value::getType %output)))
    :then-let
        ([ctx         (mlir::Operation::getContext op)]
         [!out-type   (mlir::Value::getType %output)]
         [$value-attr (constant-value-attr op ctx !out-type)])
    :rewrite %output :with
        (%result = arith.constant () ("value" = $value-attr) -> !out-type))

  ;; Pattern 2: ranked tensor → hipsr.constant (device result type)
  (define-conversion-pattern (onnx-constant-tensor->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.Constant ()
            :where (positive? (mlir::RankedTensorType::getRank (mlir::Value::getType %output)))
    :then-let
        ([ctx         (mlir::Operation::getContext op)]
         [!out-type   (mlir::Value::getType %output)]
         [!out-dev    (crest::RankedTensorType::cloneWithEncoding !out-type (make-hipsr-device-space-attr ctx))]
         [$value-attr (constant-value-attr op ctx !out-dev)])
    :rewrite %output :with
        (%result = hipsr.constant () ("value" = $value-attr) -> !out-dev))

  (define (populate-constant-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Constant"
                                      onnx-constant-scalar->arith type-converter 1)
    (add-conversion-pattern patterns "onnx.Constant"
                                      onnx-constant-tensor->hipsr type-converter 1))

) ;; end library (onnx-to-hipsr constant)
