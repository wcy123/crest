#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-attributes ffi) — raw C bindings for mlir/IR/BuiltinAttributes.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir builtin-attributes) for normal use.
;; Old generic dispatch (mlir-make-attr, mlir-attr-isa, etc.) lives in
;; (mlir core attribute) for backward compatibility.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-attributes ffi)
  (export
    %integer-attr-get-i64
    %integer-attr-get-index
    %float-attr-get-f32
    %dense-i32-array-attr-get
    %dense-i64-array-attr-get
    %parse
    %dense-resource-elements-attr-get
    %integer-attr-isa
    %float-attr-isa
    %string-attr-isa
    %dense-i32-array-attr-isa
    %dense-elements-attr-isa
    %dense-elements-attr-is-splat
    %float32-attr-isa
    %integer-attr-get-value
    %float-attr-get-value
    %float32-attr-get-value
    %dense-i32-array-attr-as-array-ref
    %dense-fp-elements-attr-splat-value
    %dense-int-elements-attr-splat-value
    %dense-i32-array-attr-to-list)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %integer-attr-get-i64
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_i64"
                       (uptr scheme-object) uptr))
  (define %integer-attr-get-index
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_index"
                       (uptr scheme-object) uptr))
  (define %float-attr-get-f32
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_get_f32"
                       (uptr scheme-object) uptr))
  (define %dense-i32-array-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_get"
                       (uptr scheme-object) uptr))
  (define %dense-i64-array-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i64_array_attr_get"
                       (uptr scheme-object) uptr))
  (define %parse
    (foreign-procedure "mlir_ir_builtin_attributes_parse"
                       (uptr scheme-object) uptr))
  (define %dense-resource-elements-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_resource_elements_attr_get"
                       (uptr scheme-object) uptr))
  (define %integer-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_isa" (uptr) int))
  (define %float-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_isa" (uptr) int))
  (define %string-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_string_attr_isa" (uptr) int))
  (define %dense-i32-array-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_isa"
                       (uptr) int))
  (define %dense-elements-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_dense_elements_attr_isa"
                       (uptr) int))
  (define %dense-elements-attr-is-splat
    (foreign-procedure "mlir_ir_builtin_attributes_dense_elements_attr_is_splat"
                       (uptr) int))
  (define %float32-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_float32_attr_isa" (uptr) int))
  (define %integer-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_value"
                       (uptr) scheme-object))
  (define %float-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_get_value"
                       (uptr) scheme-object))
  (define %float32-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_float32_attr_get_value"
                       (uptr) scheme-object))
  (define %dense-i32-array-attr-as-array-ref
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref"
                       (uptr) uptr))
  (define %dense-fp-elements-attr-splat-value
    (foreign-procedure "mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value"
                       (uptr) scheme-object))
  (define %dense-int-elements-attr-splat-value
    (foreign-procedure "mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value"
                       (uptr) scheme-object))
  (define %dense-i32-array-attr-to-list
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_to_list"
                       (uptr) scheme-object))

) ;; end library (mlir ir builtin-attributes ffi)
