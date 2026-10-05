#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-types ffi) — raw C bindings for mlir/IR/BuiltinTypes.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir builtin-types) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-types ffi)
  (export
    %index-type-get
    %integer-type-get-i64
    %integer-type-get-i1
    %ranked-tensor-type-isa
    %ranked-tensor-type-get-rank
    %ranked-tensor-type-get-element-type
    %ranked-tensor-type-get-shape
    %ranked-tensor-type-get-encoding
    %ranked-tensor-type-clone-with-encoding)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %index-type-get
    (foreign-procedure "mlir_ir_builtin_types_index_type_get" (uptr) uptr))

  (define %integer-type-get-i64
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i64" (uptr) uptr))

  (define %integer-type-get-i1
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i1" (uptr) uptr))

  (define %ranked-tensor-type-isa
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_isa" (uptr) int))

  (define %ranked-tensor-type-get-rank
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_rank"
                       (uptr) integer-64))

  (define %ranked-tensor-type-get-element-type
    (foreign-procedure
     "mlir_ir_builtin_types_ranked_tensor_type_get_element_type" (uptr) uptr))

  (define %ranked-tensor-type-get-shape
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_shape"
                       (uptr) scheme-object))

  (define %ranked-tensor-type-get-encoding
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_encoding"
                       (uptr) uptr))

  (define %ranked-tensor-type-clone-with-encoding
    (foreign-procedure
     "mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding"
     (uptr uptr) uptr))

) ;; end library (mlir ir builtin-types ffi)
