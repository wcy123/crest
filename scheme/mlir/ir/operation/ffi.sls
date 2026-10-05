#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir operation ffi) — raw C bindings for mlir/IR/Operation.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir operation) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir operation ffi)
  (export
    %get-name
    %get-context
    %get-num-operands
    %get-num-results
    %get-op-operand
    %get-result
    %get-parent-op
    %op-operand-get-value
    %op-result-get-value
    %get-loc
    %walk
    %set-operand
    %use-empty
    %get-string-attr
    %get-integer-attr
    %get-integer-array-attr
    %set-f32-attr
    %set-i64-attr
    %set-unit-attr
    %set-index-attr
    %set-dense-i64-array
    %set-i64-array-attr
    %set-dense-i32-array
    %copy-attr
    %has-attr
    %emit-error
    %emit-warning
    %emit-remark
    %erase)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %get-name
    (foreign-procedure "mlir_ir_operation_get_name" (uptr) string))
  (define %get-context
    (foreign-procedure "mlir_ir_operation_get_context" (uptr) uptr))
  (define %get-num-operands
    (foreign-procedure "mlir_ir_operation_get_num_operands" (uptr) iptr))
  (define %get-num-results
    (foreign-procedure "mlir_ir_operation_get_num_results" (uptr) iptr))
  (define %get-op-operand
    (foreign-procedure "mlir_ir_operation_get_op_operand" (uptr iptr) uptr))
  (define %get-result
    (foreign-procedure "mlir_ir_operation_get_result" (uptr iptr) uptr))
  (define %get-parent-op
    (foreign-procedure "mlir_ir_operation_get_parent_op" (uptr) uptr))
  (define %op-operand-get-value
    (foreign-procedure "mlir_ir_op_operand_get_value" (uptr int) uptr))
  (define %op-result-get-value
    (foreign-procedure "mlir_ir_op_result_get_value" (uptr int) uptr))
  (define %get-loc
    (foreign-procedure "mlir_ir_operation_get_loc" (uptr) uptr))
  (define %walk
    (foreign-procedure "mlir_ir_operation_walk" (uptr scheme-object) void))
  (define %set-operand
    (foreign-procedure "mlir_ir_operation_set_operand" (uptr int uptr) void))
  (define %use-empty
    (foreign-procedure "mlir_ir_operation_use_empty" (uptr) int))
  (define %get-string-attr
    (foreign-procedure "mlir_ir_operation_get_string_attr" (uptr string) string))
  (define %get-integer-attr
    (foreign-procedure "mlir_ir_operation_get_integer_attr"
                       (uptr string integer-64) integer-64))
  (define %get-integer-array-attr
    (foreign-procedure "mlir_ir_operation_get_integer_array_attr"
                       (uptr string) scheme-object))
  (define %set-f32-attr
    (foreign-procedure "mlir_ir_operation_set_f32_attr"
                       (uptr string double) void))
  (define %set-i64-attr
    (foreign-procedure "mlir_ir_operation_set_i64_attr"
                       (uptr string integer-64) void))
  (define %set-unit-attr
    (foreign-procedure "mlir_ir_operation_set_unit_attr" (uptr string) void))
  (define %set-index-attr
    (foreign-procedure "mlir_ir_operation_set_index_attr"
                       (uptr string integer-64) void))
  (define %set-dense-i64-array
    (foreign-procedure "mlir_ir_operation_set_dense_i64_array"
                       (uptr string scheme-object) void))
  (define %set-i64-array-attr
    (foreign-procedure "mlir_ir_operation_set_i64_array_attr"
                       (uptr string scheme-object) void))
  (define %set-dense-i32-array
    (foreign-procedure "mlir_ir_operation_set_dense_i32_array"
                       (uptr string scheme-object) void))
  (define %copy-attr
    (foreign-procedure "mlir_ir_operation_copy_attr"
                       (uptr string uptr string) void))
  (define %has-attr
    (foreign-procedure "mlir_ir_operation_has_attr" (uptr string) int))
  (define %emit-error
    (foreign-procedure "mlir_ir_operation_emit_error" (uptr string) void))
  (define %emit-warning
    (foreign-procedure "mlir_ir_operation_emit_warning" (uptr string) void))
  (define %emit-remark
    (foreign-procedure "mlir_ir_operation_emit_remark" (uptr string) void))
  (define %erase
    (foreign-procedure "mlir_ir_operation_erase" (uptr) void))

) ;; end library (mlir ir operation ffi)
