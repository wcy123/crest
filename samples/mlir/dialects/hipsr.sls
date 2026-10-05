#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects hipsr) — HipSR dialect helpers.
;;
;; When the real HipSR C++ dialect is loaded (hip-ep build), it registers
;; mlir_type_is_device_tensor etc. via crest_register_extra_bindings().
;; This library uses foreign-entry? to call real implementations when present,
;; and falls back to safe Scheme-level stubs otherwise.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects hipsr)
  (export
    :hipsr-device-space
    :hipsr-barrier-type
    hipsr-device-memory-space
    make-hipsr-device-space-attr
    make-hipsr-barrier-type-attr
    mlir-get-hipsr-context-arg
    hipsr-type-converter-add-device-memory-conversions!
    hipsr-configure-conversion-target!
    hipsr-has-compute-ancestor?
    hipsr-has-placeholder-ancestor?
    mlir-type-is-device-tensor
    make-mlir-tensor-in-host-space
    mlir-get-hipsr-context-type
    mlir-placeholder-set-barrier-type!
    mlir-hipsr-load-file-map)

  (import (rnrs)
          (only (chezscheme) foreign-entry? foreign-procedure)
          (only (mlir ir operation)
                mlir::Operation::getName
                mlir::Operation::getParentOp)
          (only (mlir ir region) mlir::Region::front)
          (mlir dialects builtin)
          (only (mlir ir builtin-attributes ffi) %mlir::parseAttribute)
          (mlir transforms dialect-conversion)
          (mlir dialects tensor)
          (only (crest util)
                type-converter-add-tensor-widening-materialization)
          (only (mlir core builder) mlir-op-get-region mlir-block-get-argument)

          (only (mlir ir builtin-types)
                mlir::RankedTensorType::getEncoding)

          (only (mlir ir type) mlir::Type::getContext)
  )

  (define-syntax :hipsr-device-space (identifier-syntax 'hipsr-device-space))
  (define-syntax :hipsr-barrier-type (identifier-syntax 'hipsr-barrier-type))

  ;; MemorySpace::Device = 1 (from HipsrEnums.td)
  (define hipsr-device-memory-space 1)

  ;;===--------------------------------------------------------------------===;;
  ;; C++ functions — called via foreign-entry? when HipSR dialect is loaded,
  ;; otherwise Scheme-level stubs return safe sentinel values.
  ;;===--------------------------------------------------------------------===;;

  ;; 1 if type has a HipSR device MemorySpaceAttr, 0 otherwise.
  (define (mlir-type-is-device-tensor type)
    (if (foreign-entry? "mlir_type_is_device_tensor")
        ((foreign-procedure "mlir_type_is_device_tensor" (uptr) int) type)
        0))

  ;; Clone a RankedTensorType with the HipSR host memory space encoding.
  ;; Returns the type unchanged when HipSR dialect is not loaded.
  (define (make-mlir-tensor-in-host-space type)
    (if (foreign-entry? "mlir_tensor_type_in_host_space")
        ((foreign-procedure "mlir_tensor_type_in_host_space" (uptr) uptr) type)
        type))

  ;; Return the !hipsr.context type. Returns 0 when HipSR dialect not loaded.
  (define (mlir-get-hipsr-context-type ctx)
    (if (foreign-entry? "mlir_get_hipsr_context_type")
        ((foreign-procedure "mlir_get_hipsr_context_type" (uptr) uptr) ctx)
        0))

  ;; Set placeholder_type attr to Barrier. No-op when HipSR dialect not loaded.
  (define (mlir-placeholder-set-barrier-type! op)
    (when (foreign-entry? "mlir_placeholder_set_barrier_type")
      ((foreign-procedure "mlir_placeholder_set_barrier_type" (uptr) void) op)))

  ;; Memory-map a file. Returns 0 when HipSR dialect not loaded.
  (define (mlir-hipsr-load-file-map ctx path)
    (if (foreign-entry? "mlir_hipsr_load_file_map")
        ((foreign-procedure "mlir_hipsr_load_file_map" (uptr string) uptr) ctx path)
        0))

  ;;===--------------------------------------------------------------------===;;
  ;; Attr construction — uses the generic :opaque API; no C++ required.
  ;;===--------------------------------------------------------------------===;;

  (define (make-hipsr-device-space-attr ctx)
    (%mlir::parseAttribute ctx "#hipsr.mem<device>"))

  (define (make-hipsr-barrier-type-attr ctx)
    (%mlir::parseAttribute ctx "#hipsr.placeholder<barrier>"))

  ;;===--------------------------------------------------------------------===;;
  ;; Context convention — HipSR passes argument 0 of func.func as context.
  ;;===--------------------------------------------------------------------===;;

  ;; Walk up the operation tree to find the enclosing func.func, then return
  ;; block argument 0 (the !hipsr.context argument by convention).
  (define (mlir-get-hipsr-context-arg op)
    (let loop ((cur op))
      (cond
        ((= 0 cur) 0)
        ((string=? (mlir::Operation::getName cur) "func.func")
         (let* ((region (mlir-op-get-region cur 0))
                (block  (if (= 0 region) 0 (mlir::Region::front region))))
           (if (= 0 block) 0 (mlir-block-get-argument block 0))))
        (else (loop (mlir::Operation::getParentOp cur))))))

  ;;===--------------------------------------------------------------------===;;
  ;; Op ancestry predicates
  ;;===--------------------------------------------------------------------===;;

  (define (has-ancestor-named? op name)
    (let loop ((parent (mlir::Operation::getParentOp op)))
      (cond
        ((= 0 parent) #f)
        ((string=? (mlir::Operation::getName parent) name) #t)
        (else (loop (mlir::Operation::getParentOp parent))))))

  (define (hipsr-has-compute-ancestor? op)
    (has-ancestor-named? op "hipsr.compute"))

  (define (hipsr-has-placeholder-ancestor? op)
    (has-ancestor-named? op "hipsr.placeholder"))

  ;;===--------------------------------------------------------------------===;;
  ;; Type converter configuration
  ;;===--------------------------------------------------------------------===;;

  (define (hipsr-type-converter-add-device-memory-conversions! type-converter)
    (type-converter-add-conversion type-converter (lambda (t) t))
    (type-converter-add-conversion type-converter
      (lambda (type)
        (if (and (= 1 (mlir-type-is-ranked-tensor type))
                 (> (mlir-ranked-tensor-type-get-rank type) 0)
                 (= 0 (mlir-mlir::RankedTensorType::getEncoding type)))
          (mlir-ranked-tensor-type-with-encoding type
              (make-hipsr-device-space-attr (mlir::Type::getContext type)))
            #f)))
    (type-converter-add-tensor-widening-materialization type-converter))

  ;;===--------------------------------------------------------------------===;;
  ;; Conversion target configuration
  ;;===--------------------------------------------------------------------===;;

  (define (hipsr-configure-conversion-target! target ctx type-converter)
    (target-add-illegal-dialect target "onnx")
    (target-add-legal-op target ctx "onnx.NoValue")
    (target-add-legal-dialect target "hipsr")
    (target-add-legal-op target ctx "builtin.module")
    (target-add-legal-op target ctx "arith.constant")
    (target-add-legal-op target ctx "tensor.cast")
    (target-add-dynamically-legal-op target ctx "func.func"
      (lambda (op)
        (= 1 (type-converter-is-signature-legal type-converter op))))
    (target-add-dynamically-legal-op target ctx "func.return"
      (lambda (op)
        (= 1 (type-converter-is-legal type-converter op))))
    (target-mark-unknown-ops-dynamically-legal target
      (lambda (op)
        (or (hipsr-has-compute-ancestor? op)
            (hipsr-has-placeholder-ancestor? op)))))

) ;; end library (mlir dialects hipsr)
