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
          (only (mlir IR MLIRContext) with-MLIRContext)
          (only (mlir IR Operation)
                mlir::OpOperand::get
                mlir::Operation::emitError
                mlir::Operation::erase
                mlir::Operation::getContext
                mlir::Operation::getName
                mlir::Operation::getNumOperands
                mlir::Operation::setOperand
                mlir::Operation::use_empty?
                mlir::Operation::walk)
          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType
                mlir::isa<BlockArgument>?
                mlir::Value::getUses
                mlir::OpResult::getResultNumber)
          (mlir support array-ref)
          (only (mlir core builder)
                mlir-ir-rewriter-base-create
                mlir-ir-rewriter-base-set-insertion-point
                mlir-ir-rewriter-base-erase-op)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Func IR FuncOps)
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
          (for (rime loop) expand)
          (only (mlir support logging)
                crest::logging::debug crest::logging::info)
          )

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
      (mlir-ir-rewriter-base-set-insertion-point rewriter op)
      (mlir-ir-rewriter-base-create rewriter op "func.return" operands '())
      (mlir-ir-rewriter-base-erase-op rewriter op)
      #t))

  (define (populate-return-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Return"
                            onnx-return->func-return type-converter 1))

  ;;===--------------------------------------------------------------------===;;
  ;; Post-processing: erase dead onnx.NoValue ops
  ;;===--------------------------------------------------------------------===;;
  (define (erase-dead-novalue! module-op)
    (let ((dead '()))
      (mlir::Operation::walk module-op
                             (lambda (op)
                               (when (and (string=? (mlir::Operation::getName op) "onnx.NoValue")
                                          (mlir::Operation::use_empty? op))
                                 (set! dead (cons op dead)))))
      (for-each mlir::Operation::erase dead)))

  ;;===--------------------------------------------------------------------===;;
  ;; Post-processing: rewire placeholder inputs to follow the shape graph
  ;;===--------------------------------------------------------------------===;;
  (define (shape-graph-counterpart value)
    (if (mlir::isa<BlockArgument>? value)
        value
        (let* ((def-op  (mlir::Value::getDefiningOp value))
               (op-name (if (zero? def-op) "" (mlir::Operation::getName def-op))))
          (if (or (string=? op-name "hipsr.placeholder")
                  (string=? op-name "hipsr.constant")
                  (string=? op-name "arith.constant"))
              value
              (let* ((result-idx (mlir::OpResult::getResultNumber value))
                     (num-inits  (mlir-operation-num-dps-inits def-op)))
                (if (>= result-idx num-inits)
                    value
                    (mlir-operation-get-dps-init-operand def-op result-idx)))))))

  (define (rewire-placeholder-inputs! module-op)
    (mlir::Operation::walk module-op
                           (lambda (op)
                             (when (string=? (mlir::Operation::getName op) "hipsr.placeholder")
                               (let loop ((i 1))
                                 (when (< i (mlir::Operation::getNumOperands op))
                                   (let* ((old-val (mlir::OpOperand::get op i))
                                          (new-val (shape-graph-counterpart old-val)))
                                     (unless (eqv? old-val new-val)
                                       (mlir::Operation::setOperand op i new-val)))
                                   (loop (+ i 1))))))))

  ;;===--------------------------------------------------------------------===;;
  ;; Helper: apply conversion then run post-processing
  ;;===--------------------------------------------------------------------===;;
  (define (do-conversion module-op target patterns)
    (crest::logging::debug "Applying full conversion...")
    (let ((success (apply-full-conversion module-op target patterns)))
      (if (= success 1)
          (begin
            (crest::logging::debug "Erasing dead NoValue ops...")
            (erase-dead-novalue! module-op)
            (crest::logging::debug "Rewiring placeholder inputs...")
            (rewire-placeholder-inputs! module-op)
            (crest::logging::info "ONNX to HipSR Conversion (Scheme): Success"))
          (begin
            (mlir::Operation::emitError module-op "onnx-to-hipsr: dialect conversion failed")
            #f))))

  (define (run-pass module-op . args)
    (crest::logging::info "Starting ONNX to HipSR Conversion (Scheme)")
    (let ((ctx (mlir::Operation::getContext module-op)))
      (with-MLIRContext ctx
                        (with-TypeConverter (type-converter)
                                            (hipsr-type-converter-add-device-memory-conversions! type-converter)
                                            (with-ConversionTarget (target ctx)
                                                                   (hipsr-configure-conversion-target! target ctx type-converter)
                                                                   (with-RewritePatternSet (patterns ctx)
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
                                                                                           (do-conversion module-op target patterns)))))))

  ) ;; end library (passes onnx-to-hipsr)
