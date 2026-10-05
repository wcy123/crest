#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects builtin ffi) — raw C bindings for builtin dialect types.
;;
;; % prefix = raw C binding. Prefer (mlir dialects builtin) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects builtin ffi)
  (export
    %mlir::Type::getContext
    %get-index-type
    %get-i64-type
    %get-i1-type
    %type-is-ranked-tensor
    %type-get-element-type
    %type-get-shape
    %type-get-rank
    %ranked-tensor-type-get-encoding
    %type-element-type
    %type-integer-width
    %type-is-unsigned)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::Type::getContext
    (foreign-procedure "mlir_ir_type_get_context" (uptr) uptr))
  (define %get-index-type
    (foreign-procedure "mlir_ir_builtin_types_index_type_get" (uptr) uptr))
  (define %get-i64-type
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i64" (uptr) uptr))
  (define %get-i1-type
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i1" (uptr) uptr))
  (define %type-is-ranked-tensor
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_isa" (uptr) int))
  (define %type-get-element-type
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_element_type" (uptr) uptr))
  (define %type-get-shape
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_shape" (uptr) scheme-object))
  (define %type-get-rank
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_rank" (uptr) int))
  (define %ranked-tensor-type-get-encoding
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_encoding" (uptr) uptr))
  (define %type-element-type
    (foreign-procedure "mlir_type_element_type" (uptr) uptr))
  (define %type-integer-width
    (foreign-procedure "mlir_type_integer_width" (uptr) uptr))
  (define %type-is-unsigned
    (foreign-procedure "mlir_type_is_unsigned" (uptr) int))

) ;; end library (mlir dialects builtin ffi)
