#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir transforms dialect-conversion ffi) — Raw C bindings.
;;
;; All names carry a % prefix to signal "raw C binding". Users import
;; (mlir transforms dialect-conversion) for clean names.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir transforms dialect-conversion ffi)

  (export
    %type-converter-create
    %type-converter-destroy
    %type-converter-add-conversion
    %type-converter-add-tensor-widening-materialization
    %type-converter-is-legal-type
    %type-converter-is-legal
    %type-converter-is-signature-legal
    %target-create
    %target-destroy
    %target-add-illegal-dialect
    %target-add-legal-dialect
    %target-add-legal-op
    %target-add-dynamically-legal-op
    %target-mark-unknown-ops-dynamically-legal
    %target-add-legal-common-ops
    %target-add-dynamically-legal-func
    %pattern-set-create
    %pattern-set-destroy
    %apply-full-conversion
    %add-conversion-pattern
    %add-rewrite-pattern
    %populate-func-type-conversion)

  (import (chezscheme))

  (define %type-converter-create
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_create"
                       () uptr))
  (define %type-converter-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_destroy"
                       (uptr) void))
  (define %type-converter-add-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_add_conversion"
                       (uptr scheme-object) void))
  (define %type-converter-add-tensor-widening-materialization
    (foreign-procedure
     "mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_materialization"
     (uptr) void))
  (define %type-converter-is-legal-type
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_legal_type"
                       (uptr uptr) int))
  (define %type-converter-is-legal
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_legal"
                       (uptr uptr) int))
  (define %type-converter-is-signature-legal
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_signature_legal"
                       (uptr uptr) int))
  (define %target-create
    (foreign-procedure "mlir_transforms_dialect_conversion_target_create"
                       (uptr) uptr))
  (define %target-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_target_destroy"
                       (uptr) void))
  (define %target-add-illegal-dialect
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_illegal_dialect"
                       (uptr string) void))
  (define %target-add-legal-dialect
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_legal_dialect"
                       (uptr string) void))
  (define %target-add-legal-op
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_legal_op"
                       (uptr uptr string) void))
  (define %target-add-dynamically-legal-op
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_dynamically_legal_op"
                       (uptr uptr string scheme-object) void))
  (define %target-mark-unknown-ops-dynamically-legal
    (foreign-procedure
     "mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal"
     (uptr scheme-object) void))
  (define %target-add-legal-common-ops
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_legal_common_ops"
                       (uptr) void))
  (define %target-add-dynamically-legal-func
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_dynamically_legal_func"
                       (uptr uptr) void))
  (define %pattern-set-create
    (foreign-procedure "mlir_transforms_dialect_conversion_pattern_set_create"
                       (uptr) uptr))
  (define %pattern-set-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_pattern_set_destroy"
                       (uptr) void))
  (define %apply-full-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_apply_full_conversion"
                       (uptr uptr uptr) int))
  (define %add-conversion-pattern
    (foreign-procedure "mlir_transforms_dialect_conversion_add_conversion_pattern"
                       (uptr string scheme-object uptr int) void))
  (define %add-rewrite-pattern
    (foreign-procedure "mlir_transforms_dialect_conversion_add_rewrite_pattern"
                       (uptr string scheme-object int) void))
  (define %populate-func-type-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_populate_func_type_conversion"
                       (uptr uptr) void))

) ;; end library (mlir transforms dialect-conversion ffi)
