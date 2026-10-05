#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir transforms dialect-conversion) — MLIR Dialect Conversion Framework.
;;
;; Mirrors mlir/Transforms/DialectConversion.h: TypeConverter, ConversionTarget,
;; RewritePatternSet, applyFullConversion, and Scheme-pattern registration.
;;
;; Raw C bindings with % prefix live in (mlir transforms dialect-conversion ffi).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir transforms dialect-conversion)

  (export
    type-converter-create
    type-converter-destroy
    type-converter-add-conversion
    type-converter-add-tensor-widening-materialization
    type-converter-is-legal-type
    type-converter-is-legal
    type-converter-is-signature-legal
    target-create
    target-destroy
    target-add-illegal-dialect
    target-add-legal-dialect
    target-add-legal-op
    target-add-dynamically-legal-op
    target-mark-unknown-ops-dynamically-legal
    target-add-legal-common-ops
    target-add-dynamically-legal-func
    pattern-set-create
    pattern-set-destroy
    apply-full-conversion
    add-conversion-pattern
    add-rewrite-pattern
    populate-func-type-conversion
    with-type-converter
    with-conversion-target
    with-pattern-set)

  (import (rnrs)
          (mlir transforms dialect-conversion ffi)
          (only (mlir core builder) with-raii))

  (define type-converter-create
    %type-converter-create)
  (define type-converter-destroy
    %type-converter-destroy)
  (define type-converter-add-conversion
    %type-converter-add-conversion)
  (define type-converter-add-tensor-widening-materialization
    %type-converter-add-tensor-widening-materialization)
  (define type-converter-is-legal-type
    %type-converter-is-legal-type)
  (define type-converter-is-legal
    %type-converter-is-legal)
  (define type-converter-is-signature-legal
    %type-converter-is-signature-legal)
  (define target-create
    %target-create)
  (define target-destroy
    %target-destroy)
  (define target-add-illegal-dialect
    %target-add-illegal-dialect)
  (define target-add-legal-dialect
    %target-add-legal-dialect)
  (define target-add-legal-op
    %target-add-legal-op)
  (define target-add-dynamically-legal-op
    %target-add-dynamically-legal-op)
  (define target-mark-unknown-ops-dynamically-legal
    %target-mark-unknown-ops-dynamically-legal)
  (define target-add-legal-common-ops
    %target-add-legal-common-ops)
  (define target-add-dynamically-legal-func
    %target-add-dynamically-legal-func)
  (define pattern-set-create
    %pattern-set-create)
  (define pattern-set-destroy
    %pattern-set-destroy)
  (define apply-full-conversion
    %apply-full-conversion)
  (define add-conversion-pattern
    %add-conversion-pattern)
  (define add-rewrite-pattern
    %add-rewrite-pattern)
  (define populate-func-type-conversion
    %populate-func-type-conversion)

  (define-syntax with-type-converter
    (syntax-rules ()
      [(_ (var) body ...)
       (with-raii (var (type-converter-create) type-converter-destroy)
         body ...)]))

  (define-syntax with-conversion-target
    (syntax-rules ()
      [(_ (var ctx) body ...)
       (with-raii (var (target-create ctx) target-destroy)
         body ...)]))

  (define-syntax with-pattern-set
    (syntax-rules ()
      [(_ (var ctx) body ...)
       (with-raii (var (pattern-set-create ctx) pattern-set-destroy)
         body ...)]))

) ;; end library (mlir transforms dialect-conversion)
