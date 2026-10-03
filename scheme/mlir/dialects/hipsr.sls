#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects hipsr) — HipSR-specific dialect helpers.
;;
;; All HipSR-specific C++ functions follow CREST naming conventions so they
;; are discoverable via foreign-entry? without explicit registration:
;;   mlir_make_attr_hipsr_device_space  — make-mlir-attribute ctx :hipsr-device-space val
;;   mlir_make_attr_hipsr_barrier_type  — make-mlir-attribute ctx :hipsr-barrier-type val
;;   mlir_attr_isa_hipsr_device_space   — mlir-attr-isa attr :hipsr-device-space
;;   mlir_type_is_device_tensor         — mlir-type-is-device-tensor type
;;   mlir_tensor_type_in_host_space     — make-mlir-tensor-in-host-space type
;;   mlir_get_hipsr_context_type        — mlir-get-hipsr-context-type ctx
;;   mlir_placeholder_set_barrier_type  — mlir-placeholder-set-barrier-type! op
;;   mlir_hipsr_load_file_map           — mlir-hipsr-load-file-map ctx path
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects hipsr)
  (export
    ;; Type keywords
    :hipsr-device-space
    :hipsr-barrier-type

    ;; Memory space
    hipsr-device-memory-space
    make-hipsr-device-space-attr       ; (ctx) → HipSR MemorySpaceAttr(Device)
    make-hipsr-barrier-type-attr       ; (ctx) → HipSR PlaceholderTypeAttr(Barrier)

    ;; Context convention
    mlir-get-hipsr-context-arg         ; (op) → context Value*

    ;; Type converter configuration
    hipsr-type-converter-add-device-memory-conversions!

    ;; Conversion target configuration
    hipsr-configure-conversion-target!

    ;; Op ancestry predicates
    hipsr-has-compute-ancestor?
    hipsr-has-placeholder-ancestor?

    ;; HipSR-specific type/op helpers
    mlir-type-is-device-tensor
    make-mlir-tensor-in-host-space
    mlir-get-hipsr-context-type
    mlir-placeholder-set-barrier-type!

    ;; HipSR file mapping for external constant data
    mlir-hipsr-load-file-map)

  (import (rnrs)
          (only (chezscheme) foreign-procedure)
          (mlir core ir)
          (mlir core attribute)
          (mlir core conversion)
          (mlir dialects tensor))

  ;;===--------------------------------------------------------------------===;;
  ;; Type keywords — expand to quoted symbols at compile time
  ;; Used with the generic mlir-make-attr / mlir-attr-isa API.
  ;;===--------------------------------------------------------------------===;;
  (define-syntax :hipsr-device-space (identifier-syntax 'hipsr-device-space))
  (define-syntax :hipsr-barrier-type (identifier-syntax 'hipsr-barrier-type))

  ;;===--------------------------------------------------------------------===;;
  ;; HipSR-specific FFI bindings
  ;; These follow CREST conventions and are auto-discovered via foreign-entry?.
  ;;===--------------------------------------------------------------------===;;

  ;; 1 if type is a RankedTensorType with a HipSR device MemorySpaceAttr, 0 otherwise.
  (define mlir-type-is-device-tensor
    (foreign-procedure "mlir_type_is_device_tensor" (uptr) int))

  ;; Clone a RankedTensorType with the HipSR host memory space encoding.
  (define make-mlir-tensor-in-host-space
    (foreign-procedure "mlir_tensor_type_in_host_space" (uptr) uptr))

  ;; Return the !hipsr.context type for the given MLIRContext.
  (define mlir-get-hipsr-context-type
    (foreign-procedure "mlir_get_hipsr_context_type" (uptr) uptr))

  ;; Set the placeholder_type attribute of a hipsr.placeholder op to Barrier.
  (define mlir-placeholder-set-barrier-type!
    (foreign-procedure "mlir_placeholder_set_barrier_type" (uptr) void))

  ;; Memory-map a file via HipsrDialect::getOrLoadFileMap (lazy, cached per dialect).
  (define mlir-hipsr-load-file-map
    (foreign-procedure "mlir_hipsr_load_file_map" (uptr string) uptr))

  ;;===--------------------------------------------------------------------===;;
  ;; Attr construction via the generic mlir-make-attr API.
  ;; The C++ functions mlir_make_attr_hipsr_device_space and
  ;; mlir_make_attr_hipsr_barrier_type are registered via Sregister_symbol
  ;; in lib/Bindings/Dialects/HipSR.cpp, discoverable by foreign-entry?.
  ;;===--------------------------------------------------------------------===;;

  ;; MemorySpace::Device = 1  (from HipsrEnums.td)
  (define hipsr-device-memory-space 1)

  ;; Create a HipSR device MemorySpaceAttr.
  ;; Uses :opaque to parse the MLIR text form:
  ;;   Without HipSR dialect: OpaqueAttr (same mechanism as !hip.context → OpaqueType)
  ;;   With HipSR dialect loaded: real mlir::hipsr::MemorySpaceAttr(Device) automatically
  (define (make-hipsr-device-space-attr ctx)
    (mlir-make-attr ctx :opaque "#hipsr.mem<device>"))

  ;; Create a HipSR PlaceholderTypeAttr(Barrier).
  (define (make-hipsr-barrier-type-attr ctx)
    (mlir-make-attr ctx :opaque "#hipsr.placeholder<barrier>"))

  ;;===--------------------------------------------------------------------===;;
  ;; Context Convention
  ;;===--------------------------------------------------------------------===;;

  ;; By HipSR convention, argument 0 of the nearest func.func is the context.
  (define (mlir-get-hipsr-context-arg op)
    (mlir-operation-get-block-argument op 0))

  ;;===--------------------------------------------------------------------===;;
  ;; Op Ancestry Predicates
  ;;===--------------------------------------------------------------------===;;

  (define (has-ancestor-named? op name)
    (let loop ((parent (mlir-operation-get-parent op)))
      (cond
        ((= 0 parent) #f)
        ((string=? (mlir-operation-name parent) name) #t)
        (else (loop (mlir-operation-get-parent parent))))))

  (define (hipsr-has-compute-ancestor? op)
    (has-ancestor-named? op "hipsr.compute"))

  (define (hipsr-has-placeholder-ancestor? op)
    (has-ancestor-named? op "hipsr.placeholder"))

  ;;===--------------------------------------------------------------------===;;
  ;; Type Converter Configuration
  ;;===--------------------------------------------------------------------===;;

  (define (hipsr-type-converter-add-device-memory-conversions! type-converter)
    ;; Identity: every type is legal as-is (lowest priority)
    (mlir-type-converter-add-conversion type-converter (lambda (t) t))
    ;; Device placement: unencoded ranked tensors of rank > 0 go to device space
    (mlir-type-converter-add-conversion type-converter
      (lambda (type)
        (if (and (= 1 (mlir-type-is-ranked-tensor type))
                 (> (mlir-type-get-rank type) 0)
                 (= 0 (mlir-ranked-tensor-type-get-encoding type)))
            (mlir-ranked-tensor-type-with-encoding type
              (make-hipsr-device-space-attr (mlir-type-get-context type)))
            #f)))
    ;; Source materialization: resolve unrealized casts between ranked tensor types.
    (mlir-type-converter-add-tensor-widening-materialization type-converter))

  ;;===--------------------------------------------------------------------===;;
  ;; Conversion Target Configuration
  ;;===--------------------------------------------------------------------===;;

  (define (hipsr-configure-conversion-target! target ctx type-converter)
    (mlir-conversion-target-add-illegal-dialect target "onnx")
    (mlir-conversion-target-add-legal-op target ctx "onnx.NoValue")
    (mlir-conversion-target-add-legal-dialect target "hipsr")
    (mlir-conversion-target-add-legal-op target ctx "builtin.module")
    (mlir-conversion-target-add-legal-op target ctx "arith.constant")
    (mlir-conversion-target-add-legal-op target ctx "tensor.cast")
    (mlir-conversion-target-add-dynamically-legal-op target ctx "func.func"
      (lambda (op)
        (= 1 (mlir-type-converter-is-signature-legal type-converter op))))
    (mlir-conversion-target-add-dynamically-legal-op target ctx "func.return"
      (lambda (op)
        (= 1 (mlir-type-converter-is-legal type-converter op))))
    (mlir-conversion-target-mark-unknown-ops-dynamically-legal target
      (lambda (op)
        (or (hipsr-has-compute-ancestor? op)
            (hipsr-has-placeholder-ancestor? op)))))

) ;; end library (mlir dialects hipsr)
