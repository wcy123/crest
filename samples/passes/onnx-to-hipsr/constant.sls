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
;; constructed through %DenseResourceElementsAttr:get.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr constant)
  (export populate-constant-patterns)
  (import (except (rnrs (6)) =)
          (rename (only (mlir ir operation)
                       operation-emit-error!
                       mlir::Operation::getAttr
                       mlir::Operation::getContext
                       mlir::Operation::getAttrOfType<IntegerAttr>
                       mlir::Operation::getAttrOfType<StringAttr>
                       operation-has-attr?)
                 (operation-emit-error!   mlir-emit-error!)
                 (mlir::Operation::getAttr      mlir-operation-get-attribute)
                 (mlir::Operation::getContext   mlir-mlir::Operation::getContext)
                 (mlir::Operation::getAttrOfType<IntegerAttr> mlir-mlir::Operation::getAttrOfType<IntegerAttr>)
                 (mlir::Operation::getAttrOfType<StringAttr>  mlir-mlir::Operation::getAttrOfType<StringAttr>)
                 (operation-has-attr?     mlir-operation-has-attr?))
          (rename (mlir ir value)
            (get-type          mlir-mlir::Value::getType))
          (only (mlir ir builtin-attributes ffi) %DenseResourceElementsAttr:get)
          (mlir dialects builtin)
          (mlir transforms dialect-conversion)
          (mlir dialects hipsr)
          (mlir dialects tensor)
          (crest))

  (define ort-mem-addr-tag "*/_ORT_MEM_ADDR_/*")

  ;; Build a value attr (ElementsAttr) for the constant.
  ;; For inline: reads the "value" attr directly.
  ;; For external: constructs DenseResourceElementsAttr.
  ;; Emits an MLIR diagnostic and raises on error — never returns #f.
  (define (constant-value-attr op ctx !result-type)
    (define (fail msg)
      (mlir-emit-error! op msg)
      (error 'onnx-constant msg))
    (cond
      [(mlir-operation-has-attr? op "value")
       (mlir-operation-get-attribute op "value")]
      [(mlir-operation-has-attr? op "location")
       (let* ([location (mlir-mlir::Operation::getAttrOfType<StringAttr> op "location")]
              [offset   (mlir-mlir::Operation::getAttrOfType<IntegerAttr> op "offset" 0)]
              [size     (mlir-mlir::Operation::getAttrOfType<IntegerAttr> op "size" 0)]
              [r (if (string=? location ort-mem-addr-tag)
                     (%DenseResourceElementsAttr:get ctx
                       (list !result-type
                             (string-append "mem|0x" (number->string offset 16))
                             offset size))
                     (let ([buf (mlir-hipsr-load-file-map ctx location)])
                       (if (zero? buf)
                           (fail (string-append "cannot memory-map: " location))
                           (%DenseResourceElementsAttr:get ctx
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
            :where (zero? (mlir-type-get-rank (mlir-mlir::Value::getType %output)))
    :then-let
        ([ctx         (mlir-mlir::Operation::getContext op)]
         [!out-type   (mlir-mlir::Value::getType %output)]
         [$value-attr (constant-value-attr op ctx !out-type)])
    :rewrite %output :with
        (%result = arith.constant () ("value" = $value-attr) -> !out-type))

  ;; Pattern 2: ranked tensor → hipsr.constant (device result type)
  (define-conversion-pattern (onnx-constant-tensor->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.Constant ()
            :where (positive? (mlir-type-get-rank (mlir-mlir::Value::getType %output)))
    :then-let
        ([ctx         (mlir-mlir::Operation::getContext op)]
         [!out-type   (mlir-mlir::Value::getType %output)]
         [!out-dev    (mlir-ranked-tensor-type-with-encoding !out-type (make-hipsr-device-space-attr ctx))]
         [$value-attr (constant-value-attr op ctx !out-dev)])
    :rewrite %output :with
        (%result = hipsr.constant () ("value" = $value-attr) -> !out-dev))

  (define (populate-constant-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Constant"
                                      onnx-constant-scalar->arith type-converter 1)
    (add-conversion-pattern patterns "onnx.Constant"
                                      onnx-constant-tensor->hipsr type-converter 1))

) ;; end library (onnx-to-hipsr constant)
