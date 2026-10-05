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
    %mlir::OpOperand::get
    %mlir::OpResult::getOwner
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
    %erase
    %get-attr
    %set-attr
    %get-float-attr)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Operation::getName — return the registered op name (e.g. "arith.addi").
  ;; @param op  Operation* uptr
  ;; @return    Interned C string; valid for the lifetime of the MLIRContext
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-name
    (foreign-procedure "mlir_ir_operation_get_name" (uptr) string))

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  ;; @param op  Operation* uptr
  ;; @return    MLIRContext* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-context
    (foreign-procedure "mlir_ir_operation_get_context" (uptr) uptr))

  ;; @brief mlir::Operation::getNumOperands — return the number of operands.
  ;; @param op  Operation* uptr
  ;; @return    Operand count as iptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-num-operands
    (foreign-procedure "mlir_ir_operation_get_num_operands" (uptr) iptr))

  ;; @brief mlir::Operation::getNumResults — return the number of results.
  ;; @param op  Operation* uptr
  ;; @return    Result count as iptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-num-results
    (foreign-procedure "mlir_ir_operation_get_num_results" (uptr) iptr))

  ;; @brief mlir::Operation::getOperand — return the i-th operand as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (iptr)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %get-op-operand
    (foreign-procedure "mlir_ir_operation_get_op_operand" (uptr iptr) uptr))

  ;; @brief mlir::Operation::getResult — return the i-th result as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (iptr)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %get-result
    (foreign-procedure "mlir_ir_operation_get_result" (uptr iptr) uptr))

  ;; @brief mlir::Operation::getParentOp — return the enclosing operation, or null.
  ;; @param op  Operation* uptr
  ;; @return    Operation* as uptr; 0 if op is null or there is no parent op
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-parent-op
    (foreign-procedure "mlir_ir_operation_get_parent_op" (uptr) uptr))

  ;; @brief mlir_ir_op_operand_get_value — return the i-th operand value of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %mlir::OpOperand::get
    (foreign-procedure "mlir_ir_op_operand_get_value" (uptr int) uptr))

  ;; @brief mlir_ir_op_result_get_value — return the i-th result value of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (int)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %mlir::OpResult::getOwner
    (foreign-procedure "mlir_ir_op_result_get_value" (uptr int) uptr))

  ;; @brief mlir::Operation::getLoc — return the source location attached to this op.
  ;; @param op  Operation* uptr
  ;; @return    Opaque Location* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-loc
    (foreign-procedure "mlir_ir_operation_get_loc" (uptr) uptr))

  ;; @brief mlir::Operation::walk — walk all nested ops, calling callback for each.
  ;; @param op        Operation* uptr (root of walk)
  ;; @param callback  Scheme callable (scheme-object) invoked with each Operation* uptr
  ;; @return          void
  ;; @see             mlir/IR/Operation.h
  ;; @note            Defined in lib/Bindings/IR/Operation.cpp; callback is GC-rooted internally
  (define %walk
    (foreign-procedure "mlir_ir_operation_walk" (uptr scheme-object) void))

  ;; @brief mlir::Operation::setOperand — replace the i-th operand with a new value.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @param value  New operand Value* as uptr
  ;; @return       void
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %set-operand
    (foreign-procedure "mlir_ir_operation_set_operand" (uptr int uptr) void))

  ;; @brief mlir::Operation::use_empty — return 1 if this op has no uses, 0 otherwise.
  ;; @param op  Operation* uptr
  ;; @return    int; 1 = no uses, 0 = has uses (or op is null)
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %use-empty
    (foreign-procedure "mlir_ir_operation_use_empty" (uptr) int))

  ;; @brief mlir::Operation::getAttrOfType<StringAttr> — return a string attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute value string; empty string if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-string-attr
    (foreign-procedure "mlir_ir_operation_get_string_attr" (uptr string) string))

  ;; @brief mlir::Operation::getAttrOfType<IntegerAttr> — return an integer attribute value.
  ;; @param op           Operation* uptr
  ;; @param attr-name    Attribute name (string)
  ;; @param default-val  Value returned when attribute is absent (integer-64)
  ;; @return             Attribute value as integer-64, or default-val
  ;; @see                mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note               Defined in lib/Bindings/IR/Operation.cpp
  (define %get-integer-attr
    (foreign-procedure "mlir_ir_operation_get_integer_attr"
                       (uptr string integer-64) integer-64))

  ;; @brief mlir::Operation — return a DenseI64ArrayAttr or ArrayAttr as a Scheme list.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Scheme list of integers; '() if absent, wrong type, or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp; tries DenseI64ArrayAttr first, then ArrayAttr
  (define %get-integer-array-attr
    (foreign-procedure "mlir_ir_operation_get_integer_array_attr"
                       (uptr string) scheme-object))

  ;; @brief mlir::Operation::setAttr — set a Float32 attribute.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Float value (double, truncated to f32 internally)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define %set-f32-attr
    (foreign-procedure "mlir_ir_operation_set_f32_attr"
                       (uptr string double) void))

  ;; @brief mlir::Operation::setAttr — set an i64 IntegerAttr.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Integer value (integer-64)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define %set-i64-attr
    (foreign-procedure "mlir_ir_operation_set_i64_attr"
                       (uptr string integer-64) void))

  ;; @brief mlir::Operation::setAttr — set a UnitAttr (presence-only flag).
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define %set-unit-attr
    (foreign-procedure "mlir_ir_operation_set_unit_attr" (uptr string) void))

  ;; @brief mlir::Operation::setAttr — set an IndexType IntegerAttr.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Index value (integer-64)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define %set-index-attr
    (foreign-procedure "mlir_ir_operation_set_index_attr"
                       (uptr string integer-64) void))

  ;; @brief mlir::Operation::setAttr — set a DenseI64ArrayAttr from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp
  (define %set-dense-i64-array
    (foreign-procedure "mlir_ir_operation_set_dense_i64_array"
                       (uptr string scheme-object) void))

  ;; @brief mlir::Operation::setAttr — set an ArrayAttr of i64 IntegerAttrs from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp; use %set-dense-i64-array for dense form
  (define %set-i64-array-attr
    (foreign-procedure "mlir_ir_operation_set_i64_array_attr"
                       (uptr string scheme-object) void))

  ;; @brief mlir::Operation::setAttr — set a DenseI32ArrayAttr from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers (truncated to i32)
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp
  (define %set-dense-i32-array
    (foreign-procedure "mlir_ir_operation_set_dense_i32_array"
                       (uptr string scheme-object) void))

  ;; @brief mlir::Operation::setAttr — copy an attribute from src-op to dst-op.
  ;; @param dst-op    Destination Operation* uptr
  ;; @param dst-name  Attribute name on the destination (string)
  ;; @param src-op    Source Operation* uptr
  ;; @param src-name  Attribute name on the source (string)
  ;; @return          void; no-op if either op is null or src attr is absent
  ;; @see             mlir/IR/Operation.h
  ;; @note            Defined in lib/Bindings/IR/Operation.cpp
  (define %copy-attr
    (foreign-procedure "mlir_ir_operation_copy_attr"
                       (uptr string uptr string) void))

  ;; @brief mlir::Operation::hasAttr — test whether an attribute is present.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           int; 1 = attribute present, 0 = absent or op is null
  ;; @see              mlir/IR/Operation.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %has-attr
    (foreign-procedure "mlir_ir_operation_has_attr" (uptr string) int))

  ;; @brief mlir::Operation::emitError — emit a compiler error diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Error message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-error
    (foreign-procedure "mlir_ir_operation_emit_error" (uptr string) void))

  ;; @brief mlir::Operation::emitWarning — emit a compiler warning diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Warning message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-warning
    (foreign-procedure "mlir_ir_operation_emit_warning" (uptr string) void))

  ;; @brief mlir::Operation::emitRemark — emit a compiler remark diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Remark message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-remark
    (foreign-procedure "mlir_ir_operation_emit_remark" (uptr string) void))

  ;; @brief mlir::Operation::erase — remove and deallocate this operation.
  ;; @param op  Operation* uptr
  ;; @return    void
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp; op pointer is invalid after this call
  (define %erase
    (foreign-procedure "mlir_ir_operation_erase" (uptr) void))

  ;; @brief mlir::Operation::getAttr — get an attribute as opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute* as uptr; 0 if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-attr
    (foreign-procedure "mlir_ir_operation_get_attr"
                       (uptr string) uptr))

  ;; @brief mlir::Operation::setAttr — set an attribute from an opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @param attr       Attribute* as uptr
  ;; @return           void
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %set-attr
    (foreign-procedure "mlir_ir_operation_set_attr"
                       (uptr string uptr) void))

  ;; @brief mlir::FloatAttr::getValueAsDouble — get a float attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           double value; NaN if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-float-attr
    (foreign-procedure "mlir_ir_operation_get_float_attr"
                       (uptr string) double))

) ;; end library (mlir ir operation ffi)
