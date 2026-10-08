#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Operation.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Operation ffi) — raw C bindings for mlir/IR/Operation.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR Operation) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Operation ffi)
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
    %mlir::Operation::getLoc
    %mlir::Operation::getRegion
    %walk
    %set-operand
    %use-empty
    %get-string-attr
    %get-integer-attr

    %has-attr
    %emit-error
    %emit-warning
    %emit-remark
    %erase
    %get-attr
    %set-attr
    %get-float-attr
    %mlir::Operation::getAttrDictionary
    %mlir::Operation::setAttrs)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Operation::getName — return the registered op name (e.g. "arith.addi").
  ;; @param op  Operation* uptr
  ;; @return    Interned C string; valid for the lifetime of the MLIRContext
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-name
    (foreign-procedure "mlir::Operation::getName" (uptr) string))

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  ;; @param op  Operation* uptr
  ;; @return    MLIRContext* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-context
    (foreign-procedure "mlir::Operation::getContext" (uptr) uptr))

  ;; @brief mlir::Operation::getNumOperands — return the number of operands.
  ;; @param op  Operation* uptr
  ;; @return    Operand count as iptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-num-operands
    (foreign-procedure "mlir::Operation::getNumOperands" (uptr) iptr))

  ;; @brief mlir::Operation::getNumResults — return the number of results.
  ;; @param op  Operation* uptr
  ;; @return    Result count as iptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-num-results
    (foreign-procedure "mlir::Operation::getNumResults" (uptr) iptr))

  ;; @brief mlir::Operation::getOperand — return the i-th operand as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (iptr)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %get-op-operand
    (foreign-procedure "mlir::Operation::getOpOperand" (uptr iptr) uptr))

  ;; @brief mlir::Operation::getResult — return the i-th result as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (iptr)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %get-result
    (foreign-procedure "mlir::Operation::getResult" (uptr iptr) uptr))

  ;; @brief mlir::Operation::getParentOp — return the enclosing operation, or null.
  ;; @param op  Operation* uptr
  ;; @return    Operation* as uptr; 0 if op is null or there is no parent op
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %get-parent-op
    (foreign-procedure "mlir::Operation::getParentOp" (uptr) uptr))

  ;; @brief mlir_ir_op_operand_get_value — return the i-th operand value of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %mlir::OpOperand::get
    (foreign-procedure "mlir::OpOperand::get" (uptr int) uptr))

  ;; @brief mlir_ir_op_result_get_value — return the i-th result value of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (int)
  ;; @return       Opaque Value* as uptr; 0 if op is null or index out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %mlir::OpResult::getOwner
    (foreign-procedure "mlir::OpResult::getOwner" (uptr int) uptr))

  ;; @brief mlir::Operation::getLoc — return the source location attached to this op.
  ;; @param op  Operation* uptr
  ;; @return    Opaque Location* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %mlir::Operation::getLoc
    (foreign-procedure "mlir::Operation::getLoc" (uptr) uptr))

  (define %mlir::Operation::getRegion
    (foreign-procedure "mlir::Operation::getRegion" (uptr int) uptr))

  ;; @brief mlir::Operation::walk — walk all nested ops, calling callback for each.
  ;; @param op        Operation* uptr (root of walk)
  ;; @param callback  Scheme callable (scheme-object) invoked with each Operation* uptr
  ;; @return          void
  ;; @see             mlir/IR/Operation.h
  ;; @note            Defined in lib/Bindings/IR/Operation.cpp; callback is GC-rooted internally
  (define %walk
    (foreign-procedure "mlir::Operation::walk" (uptr scheme-object) void))

  ;; @brief mlir::Operation::setOperand — replace the i-th operand with a new value.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @param value  New operand Value* as uptr
  ;; @return       void
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define %set-operand
    (foreign-procedure "mlir::Operation::setOperand" (uptr int uptr) void))

  ;; @brief mlir::Operation::use_empty — return 1 if this op has no uses, 0 otherwise.
  ;; @param op  Operation* uptr
  ;; @return    int; 1 = no uses, 0 = has uses (or op is null)
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define %use-empty
    (foreign-procedure "mlir::Operation::use_empty" (uptr) int))

  ;; @brief mlir::Operation::getAttrOfType<StringAttr> — return a string attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute value string; empty string if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-string-attr
    (foreign-procedure "mlir::Operation::getAttrOfType<StringAttr>" (uptr string) string))

  ;; @brief mlir::Operation::getAttrOfType<IntegerAttr> — return an integer attribute value.
  ;; @param op           Operation* uptr
  ;; @param attr-name    Attribute name (string)
  ;; @param default-val  Value returned when attribute is absent (integer-64)
  ;; @return             Attribute value as integer-64, or default-val
  ;; @see                mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note               Defined in lib/Bindings/IR/Operation.cpp
  (define %get-integer-attr
    (foreign-procedure "mlir::Operation::getAttrOfType<IntegerAttr>"
                       (uptr string integer-64) integer-64))

  ;; @brief mlir::Operation::hasAttr — test whether an attribute is present.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           int; 1 = attribute present, 0 = absent or op is null
  ;; @see              mlir/IR/Operation.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %has-attr
    (foreign-procedure "mlir::Operation::hasAttr" (uptr string) int))

  ;; @brief mlir::Operation::emitError — emit a compiler error diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Error message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-error
    (foreign-procedure "mlir::Operation::emitError" (uptr string) void))

  ;; @brief mlir::Operation::emitWarning — emit a compiler warning diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Warning message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-warning
    (foreign-procedure "mlir::Operation::emitWarning" (uptr string) void))

  ;; @brief mlir::Operation::emitRemark — emit a compiler remark diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Remark message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define %emit-remark
    (foreign-procedure "mlir::Operation::emitRemark" (uptr string) void))

  ;; @brief mlir::Operation::erase — remove and deallocate this operation.
  ;; @param op  Operation* uptr
  ;; @return    void
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp; op pointer is invalid after this call
  (define %erase
    (foreign-procedure "mlir::Operation::erase" (uptr) void))

  ;; @brief mlir::Operation::getAttr — get an attribute as opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute* as uptr; 0 if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-attr
    (foreign-procedure "mlir::Operation::getAttr"
                       (uptr string) uptr))

  ;; @brief mlir::Operation::setAttr! — set an attribute from an opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @param attr       Attribute* as uptr
  ;; @return           void
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %set-attr
    (foreign-procedure "mlir::Operation::setAttr"
                       (uptr string uptr) void))

  ;; @brief mlir::FloatAttr::getValueAsDouble — get a float attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           double value; NaN if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define %get-float-attr
    (foreign-procedure "mlir::Operation::getAttrOfType<FloatAttr>"
                       (uptr string) double))

  ;; @brief mlir::Operation::getAttrDictionary — return all attributes as a DictionaryAttr.
  ;; @param op  Operation* uptr
  ;; @return    DictionaryAttr opaque ptr as uptr
  ;; @see       mlir/IR/Operation.h
  (define %mlir::Operation::getAttrDictionary
    (foreign-procedure "mlir::Operation::getAttrDictionary" (uptr) uptr))

  ;; @brief mlir::Operation::setAttrs — replace all attributes with those in dict.
  ;; @param op    Operation* uptr
  ;; @param dict  DictionaryAttr opaque ptr as uptr
  ;; @return      void
  ;; @see         mlir/IR/Operation.h
  (define %mlir::Operation::setAttrs
    (foreign-procedure "mlir::Operation::setAttrs" (uptr uptr) void))

  ) ;; end library (mlir IR Operation ffi)
