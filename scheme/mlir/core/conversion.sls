#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core conversion) — backward-compatibility shim.
;;
;; The canonical library has moved to (mlir transforms dialect-conversion).
;; This shim re-exports the original names so existing code continues to work.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core conversion)

  (export
    mlir-create-type-converter
    mlir-destroy-type-converter
    mlir-type-converter-add-conversion
    mlir-type-converter-add-tensor-widening-materialization
    mlir-type-converter-is-legal-type
    mlir-type-converter-is-legal
    mlir-type-converter-is-signature-legal
    mlir-create-conversion-target
    mlir-destroy-conversion-target
    mlir-conversion-target-add-illegal-dialect
    mlir-conversion-target-add-legal-dialect
    mlir-conversion-target-add-legal-op
    mlir-conversion-target-add-dynamically-legal-op
    mlir-conversion-target-mark-unknown-ops-dynamically-legal
    mlir-create-rewrite-pattern-set
    mlir-destroy-rewrite-pattern-set
    mlir-apply-full-conversion
    mlir-register-conversion-pattern
    mlir-register-rewrite-pattern
    with-type-converter
    with-conversion-target
    with-rewrite-pattern-set)

  (import (rnrs)
          (mlir transforms dialect-conversion)
          (mlir core ir))  ; for with-raii

  (define mlir-create-type-converter           type-converter-create)
  (define mlir-destroy-type-converter          type-converter-destroy)
  (define mlir-type-converter-add-conversion   type-converter-add-conversion)
  (define mlir-type-converter-add-tensor-widening-materialization
    type-converter-add-tensor-widening-materialization)
  (define mlir-type-converter-is-legal-type    type-converter-is-legal-type)
  (define mlir-type-converter-is-legal         type-converter-is-legal)
  (define mlir-type-converter-is-signature-legal type-converter-is-signature-legal)
  (define mlir-create-conversion-target        target-create)
  (define mlir-destroy-conversion-target       target-destroy)
  (define mlir-conversion-target-add-illegal-dialect target-add-illegal-dialect)
  (define mlir-conversion-target-add-legal-dialect   target-add-legal-dialect)
  (define mlir-conversion-target-add-legal-op        target-add-legal-op)
  (define mlir-conversion-target-add-dynamically-legal-op
    target-add-dynamically-legal-op)
  (define mlir-conversion-target-mark-unknown-ops-dynamically-legal
    target-mark-unknown-ops-dynamically-legal)
  (define mlir-create-rewrite-pattern-set      pattern-set-create)
  (define mlir-destroy-rewrite-pattern-set     pattern-set-destroy)
  (define mlir-apply-full-conversion           apply-full-conversion)
  (define mlir-register-conversion-pattern     add-conversion-pattern)
  (define mlir-register-rewrite-pattern        add-rewrite-pattern)

  (define-syntax with-rewrite-pattern-set
    (syntax-rules ()
      [(_ (var ctx) body ...)
       (with-pattern-set (var ctx) body ...)]))

) ;; end library (mlir core conversion)
