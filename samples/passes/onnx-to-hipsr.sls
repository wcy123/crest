#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; ONNX to HipSR Conversion — Scheme Implementation
;;
;; Orchestrates the dialect conversion using MLIR framework primitives.
;; All patterns are implemented in Scheme using the CREST DDR framework;
;; no dialect-specific C++ populate functions are required.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr)
  (export run-pass)
  (import (rnrs (6))
          (rename (only (mlir ir operation)
                            mlir::OpOperand::get
                            operation-emit-error!
                            mlir::Operation::getContext
                            mlir::Operation::getName
                            mlir::Operation::getNumOperands
                            mlir::Operation::setOperand
                            operation-use-empty?
                            mlir::Operation::walk)
                      (mlir::OpOperand::get mlir-operation-get-operand-value)
                      (operation-emit-error! mlir-emit-error!)
                      (mlir::Operation::getContext mlir-mlir::Operation::getContext)
                      (mlir::Operation::getName mlir-operation-name)
                      (mlir::Operation::getNumOperands mlir-operation-num-operands)
                      (mlir::Operation::setOperand mlir-mlir::Operation::setOperand)
                      (operation-use-empty? mlir-operation-use-empty?)
                      (mlir::Operation::walk mlir-mlir::Operation::walk))
          (rename (mlir ir value)
            (get-defining-op   mlir-mlir::Value::getDefiningOp)
            (get-type          mlir-mlir::Value::getType)
            (block-argument?   mlir-value-is-block-argument?)
            (num-uses          mlir-mlir::Value::getUses))
          (rename (mlir ir op-result)
            (mlir::OpResult::getResultNumber mlir-value-mlir::OpResult::getResultNumber))
          (mlir support array-ref)
          (only (mlir core builder) mlir-build-op mlir-set-insertion-point-before mlir-erase-op mlir-op-erase)
          (mlir transforms dialect-conversion)
          (rename (mlir ir value)
            (get-defining-op   mlir-mlir::Value::getDefiningOp)
            (get-type          mlir-mlir::Value::getType)
            (block-argument?   mlir-value-is-block-argument?)
            (num-uses          mlir-mlir::Value::getUses))
          (rename (mlir ir op-result)
            (mlir::OpResult::getResultNumber mlir-value-mlir::OpResult::getResultNumber))
          (mlir dialects hipsr)
          (mlir dialects func)
          (mlir support logging)
          (passes onnx-to-hipsr cast)
          (passes onnx-to-hipsr scatter-nd)
          (passes onnx-to-hipsr equal)
          (passes onnx-to-hipsr matmul)
          (passes onnx-to-hipsr min)
          (passes onnx-to-hipsr transpose)
          (passes onnx-to-hipsr gather)
          (passes onnx-to-hipsr expand)
          (passes onnx-to-hipsr constant)
          (passes onnx-to-hipsr shape)
          (only (chezscheme) foreign-procedure)
          (for (rime loop) expand))

  ;; DPS (DestinationPassing-Style) interface helpers.
  ;; These were in (mlir core operation) and are now defined here directly.
  (define mlir-operation-num-dps-inits
    (foreign-procedure "mlir_interfaces_dps_get_num_dps_inits" (uptr) int))
  (define mlir-operation-get-dps-init-operand
    (foreign-procedure "mlir_interfaces_dps_get_dps_init_operand" (uptr int) uptr))

  ;; Populate return-conversion patterns in Scheme.
  ;; onnx.Return → func.return, forwarding the (already type-converted) operands.
  (define (onnx-return->func-return op operands-ref rewriter type-converter)
    (let ((operands (loop :for i :from 0 :below (array-ref-size operands-ref)
                         :collect (array-ref-at operands-ref i))))
      (mlir-set-insertion-point-before rewriter op)
      (mlir-build-op rewriter op "func.return" operands '())
      (mlir-erase-op rewriter op)
      #t))

  (define (populate-return-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Return"
                                      onnx-return->func-return type-converter 1))

  ;;===--------------------------------------------------------------------===;;
  ;; Post-processing: erase dead onnx.NoValue ops
  ;;===--------------------------------------------------------------------===;;
  (define (erase-dead-novalue! module-op)
    (let ((dead '()))
      (mlir-mlir::Operation::walk module-op
        (lambda (op)
          (when (and (string=? (mlir-operation-name op) "onnx.NoValue")
                     (mlir-operation-use-empty? op))
            (set! dead (cons op dead)))))
      (for-each mlir-op-erase dead)))

  ;;===--------------------------------------------------------------------===;;
  ;; Post-processing: rewire placeholder inputs to follow the shape graph
  ;;===--------------------------------------------------------------------===;;
  (define (shape-graph-counterpart value)
    (if (mlir-value-is-block-argument? value)
        value
        (let* ((def-op  (mlir-mlir::Value::getDefiningOp value))
               (op-name (if (zero? def-op) "" (mlir-operation-name def-op))))
          (if (or (string=? op-name "hipsr.placeholder")
                  (string=? op-name "hipsr.constant")
                  (string=? op-name "arith.constant"))
              value
              (let* ((result-idx (mlir-value-mlir::OpResult::getResultNumber value))
                     (num-inits  (mlir-operation-num-dps-inits def-op)))
                (if (>= result-idx num-inits)
                    value
                    (mlir-operation-get-dps-init-operand def-op result-idx)))))))

  (define (rewire-placeholder-inputs! module-op)
    (mlir-mlir::Operation::walk module-op
      (lambda (op)
        (when (string=? (mlir-operation-name op) "hipsr.placeholder")
          (let loop ((i 1))
            (when (< i (mlir-operation-num-operands op))
              (let* ((old-val (mlir-operation-get-operand-value op i))
                     (new-val (shape-graph-counterpart old-val)))
                (unless (eqv? old-val new-val)
                  (mlir-mlir::Operation::setOperand op i new-val)))
              (loop (+ i 1))))))))

  ;;===--------------------------------------------------------------------===;;
  ;; Helper: apply conversion then run post-processing
  ;;===--------------------------------------------------------------------===;;
  (define (do-conversion module-op target patterns)
    (mlir-log-debug "Applying full conversion...")
    (let ((success (apply-full-conversion module-op target patterns)))
      (if (= success 1)
          (begin
            (mlir-log-debug "Erasing dead NoValue ops...")
            (erase-dead-novalue! module-op)
            (mlir-log-debug "Rewiring placeholder inputs...")
            (rewire-placeholder-inputs! module-op)
            (mlir-log-info "ONNX to HipSR Conversion (Scheme): Success"))
          (begin
            (mlir-emit-error! module-op "onnx-to-hipsr: dialect conversion failed")
            #f))))

  (define (run-pass module-op . args)
    (mlir-log-info "Starting ONNX to HipSR Conversion (Scheme)")
    (let ((ctx (mlir-mlir::Operation::getContext module-op)))
      (with-type-converter (type-converter)
        (hipsr-type-converter-add-device-memory-conversions! type-converter)
        (with-conversion-target (target ctx)
          (hipsr-configure-conversion-target! target ctx type-converter)
          (with-pattern-set (patterns ctx)
            ;; Scheme DSL patterns
            (populate-cast-patterns       type-converter patterns ctx)
            (populate-scatter-nd-patterns type-converter patterns ctx)
            (populate-equal-patterns      type-converter patterns ctx)
            (populate-matmul-patterns     type-converter patterns ctx)
            (populate-min-patterns        type-converter patterns ctx)
            (populate-transpose-patterns  type-converter patterns ctx)
            (populate-gather-patterns     type-converter patterns ctx)
            (populate-expand-patterns     type-converter patterns ctx)
            (populate-constant-patterns   type-converter patterns ctx)
            (populate-shape-patterns      type-converter patterns ctx)
            ;; Infrastructure patterns
            (populate-return-patterns type-converter patterns ctx)
            (mlir-populate-func-type-conversion-pattern patterns type-converter)
            (do-conversion module-op target patterns))))))

) ;; end library (passes onnx-to-hipsr)
