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
    make-hipsr-device-space-attr
    make-hipsr-barrier-type-attr
    mlir-get-hipsr-context-arg
    identity-conversion
    device-memory-conversion
    tensor-cast-materialization
    unknown-ops-legal
    hipsr-configure-conversion-target!
    mlir-type-is-device-tensor
    make-mlir-tensor-in-host-space
    mlir-get-hipsr-context-type
    mlir-hipsr-load-file-map)

  (import (rnrs)
          (only (mlir IR Operation)
                mlir::Operation::getName
                mlir::Operation::getParentOp)
          (only (mlir IR Region) mlir::Region::front)
          (mlir Transforms DialectConversion)
          (only (crest callback) crest-make-static-c-callable)
          (mlir Dialect Tensor IR)
          (only (mlir IR Operation) mlir::Operation::getRegion)
          (only (mlir IR Block) mlir::Block::getArgument)

          (only (mlir IR BuiltinAttributes)
                mlir::parseAttribute)
          (only (mlir IR Value) mlir::Value::getType)
          (mlir Dialect Tensor IR)
          (only (mlir Transforms DialectConversion)
                mlir::TypeConverter::addSourceMaterialization
                mlir::TypeConverter::addTargetMaterialization)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding
                mlir::RankedTensorType::getEncoding
                mlir::RankedTensorType::getRank
                mlir::isa<RankedTensorType>?)

          (only (mlir IR Types) mlir::Type::getContext)
          (only (mlir IR MLIRContext) current-MLIRContext)
          )


  ;;===--------------------------------------------------------------------===;;
  ;; HipSR dialect stubs — return safe sentinel values.
  ;; TODO: replace with real bindings once HipSR exposes a proper module.
  ;;===--------------------------------------------------------------------===;;

  (define (mlir-type-is-device-tensor type)   0)   ; stub
  (define (make-mlir-tensor-in-host-space type) type) ; stub — returns type unchanged
  (define (mlir-get-hipsr-context-type ctx)   0)   ; stub
  (define (mlir-hipsr-load-file-map ctx path) 0)   ; stub

  ;;===--------------------------------------------------------------------===;;
  ;; Attr construction — uses the generic :opaque API; no C++ required.
  ;;===--------------------------------------------------------------------===;;

  (define (make-hipsr-device-space-attr)
    (mlir::parseAttribute "#hipsr.mem<device>"))

  (define (make-hipsr-barrier-type-attr)
    (mlir::parseAttribute "#hipsr.placeholder<barrier>"))

  ;;===--------------------------------------------------------------------===;;
  ;; Context convention — HipSR passes argument 0 of func.func as context.
  ;;===--------------------------------------------------------------------===;;

  ;; Walk up the operation tree to find the enclosing func.func, then return
  ;; block argument 0 (the !hipsr.context argument by convention).
  (define (mlir-get-hipsr-context-arg op)
    (let loop ((cur op))
      (cond
       ((not cur) 0)
       ((string=? (mlir::Operation::getName cur) "func.func")
        (let* ((region (mlir::Operation::getRegion cur 0))
               (block  (if (= 0 region) 0 (mlir::Region::front region))))
          (if (= 0 block) 0 (mlir::Block::getArgument block 0))))
       (else (loop (mlir::Operation::getParentOp cur))))))

  ;;===--------------------------------------------------------------------===;;
  ;; Op ancestry predicates
  ;;===--------------------------------------------------------------------===;;

  (define (has-ancestor-named? op name)
    (let loop ((parent (mlir::Operation::getParentOp op)))
      (cond
       ((not parent) #f)
       ((string=? (mlir::Operation::getName parent) name) #t)
       (else (loop (mlir::Operation::getParentOp parent))))))

  (define (hipsr-has-compute-ancestor? op)
    (has-ancestor-named? op "hipsr.compute"))

  (define (hipsr-has-placeholder-ancestor? op)
    (has-ancestor-named? op "hipsr.placeholder"))

  ;;===--------------------------------------------------------------------===;;
  ;; Type converter configuration
  ;;===--------------------------------------------------------------------===;;

  ;; These callbacks use no state of a run: they are made once, when the library is loaded.

  ;; Bridge a #hipsr.mem<device> tensor to a plain tensor (or vice versa)
  ;; at conversion boundaries using tensor.cast.
  (define tensor-cast-materialization
    (crest-make-static-c-callable
     (uptr uptr uptr uptr uptr)
     (materialization->c
      (lambda (builder result-type inputs loc)
        (if (not (and (pair? inputs) (null? (cdr inputs))))
            #f
            (let* ([input      (car inputs)]
                   [input-type (mlir::Value::getType input)])
              (if (not (and (mlir::isa<RankedTensorType>? input-type)
                            (mlir::isa<RankedTensorType>? result-type)
                            (= 1 (mlir::tensor::CastOp::areCastCompatible
                                  input-type result-type))))
                  #f
                  (mlir::tensor::CastOp::create builder loc result-type input))))))))

  (define identity-conversion
    (crest-make-static-c-callable (uptr) (type-conversion->c (lambda (t) t))))

  (define device-memory-conversion
    (crest-make-static-c-callable
     (uptr)
     (type-conversion->c
      (lambda (type)
        (if (and (mlir::isa<RankedTensorType>? type)
                 (> (mlir::RankedTensorType::getRank type) 0)
                 (= 0 (mlir::RankedTensorType::getEncoding type)))
            (mlir::RankedTensorType::cloneWithEncoding type
                                                       (mlir::parseAttribute (mlir::Type::getContext type)
                                                                             "#hipsr.mem<device>"))
            #f)))))

  ;;===--------------------------------------------------------------------===;;
  ;; Conversion target configuration
  ;;===--------------------------------------------------------------------===;;

  (define unknown-ops-legal
    (crest-make-static-c-callable
     (uptr)
     (legality->c (lambda (op)
                    (or (hipsr-has-compute-ancestor? op)
                        (hipsr-has-placeholder-ancestor? op))))))

  (define (hipsr-configure-conversion-target! target ctx)
    (target-add-illegal-dialect target "onnx")
    (target-add-legal-op target ctx "onnx.NoValue")
    (target-add-legal-dialect target "hipsr")
    (target-add-legal-op target ctx "builtin.module")
    (target-add-legal-op target ctx "arith.constant")
    (target-add-legal-op target ctx "tensor.cast"))

  ) ;; end library (mlir dialects hipsr)
