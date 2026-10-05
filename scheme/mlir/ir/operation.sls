#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir operation) — Operation inspection, mutation, attr access, walk.
;;
;; Mirrors mlir/IR/Operation.h.
;; Imports raw bindings from (mlir ir operation ffi); Scheme helpers added here.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir operation)
  (export
    operation-get-name
    operation-get-context
    operation-get-num-operands
    operation-get-num-results
    operation-get-op-operand
    operation-get-result
    operation-get-parent-op
    op-operand-get-value
    op-result-get-value
    operation-get-loc
    operation-walk
    operation-set-operand
    operation-use-empty?
    operation-get-string-attr
    operation-get-integer-attr
    operation-get-integer-array-attr
    operation-set-f32-attr!
    operation-set-i64-attr!
    operation-set-unit-attr!
    operation-set-index-attr!
    operation-set-dense-i64-array!
    operation-set-i64-array-attr!
    operation-set-dense-i32-array!
    operation-copy-attr!
    operation-has-attr?
    operation-emit-error!
    operation-emit-warning!
    operation-emit-remark!
    operation-erase!
    operation-get-attr
    operation-set-attr!
    operation-get-float-attr
    operation-get-operands)
  (import (rnrs)
          (mlir ir operation ffi)
          (rename (rime loop) (:with :rime-with))
          (only (mlir ir builtin-attributes) dense-i32-array-attr-as-array-ref)
          (mlir support array-ref))

  ;; @brief mlir::Operation::getName — return the registered op name (e.g. "arith.addi").
  ;; @param op  Operation* uptr
  ;; @return    Interned string; valid for the lifetime of the MLIRContext
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-name          %get-name)

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  ;; @param op  Operation* uptr
  ;; @return    MLIRContext* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-context       %get-context)

  ;; @brief mlir::Operation::getNumOperands — return the number of operands.
  ;; @param op  Operation* uptr
  ;; @return    Operand count; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-num-operands  %get-num-operands)

  ;; @brief mlir::Operation::getNumResults — return the number of results.
  ;; @param op  Operation* uptr
  ;; @return    Result count; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-num-results   %get-num-results)

  ;; @brief mlir::Operation::getOperand — return the i-th operand as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-op-operand    %get-op-operand)

  ;; @brief mlir::Operation::getResult — return the i-th result as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-result        %get-result)

  ;; @brief mlir::Operation::getParentOp — return the enclosing operation, or null.
  ;; @param op  Operation* uptr
  ;; @return    Operation* as uptr; 0 if op is null or has no parent op
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-parent-op     %get-parent-op)

  ;; @brief mlir_ir_op_operand_get_value — return the i-th operand Value* of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define op-operand-get-value        %op-operand-get-value)

  ;; @brief mlir_ir_op_result_get_value — return the i-th result Value* of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (int)
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define op-result-get-value         %op-result-get-value)

  ;; @brief mlir::Operation::getLoc — return the source location attached to this op.
  ;; @param op  Operation* uptr
  ;; @return    Opaque Location* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-loc           %get-loc)

  ;; @brief mlir::Operation::walk — walk all nested ops, calling callback for each.
  ;; @param op        Operation* uptr (root of walk)
  ;; @param callback  Scheme callable invoked with each Operation* uptr
  ;; @return          void
  ;; @see             mlir/IR/Operation.h
  ;; @note            Defined in lib/Bindings/IR/Operation.cpp; callback is GC-rooted internally
  (define operation-walk              %walk)

  ;; @brief mlir::Operation::setOperand — replace the i-th operand with a new value.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @param value  New operand Value* as uptr
  ;; @return       void
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-operand       %set-operand)

  ;; @brief mlir::Operation::use_empty — return #t if this op has no uses.
  ;; @param op  Operation* uptr
  ;; @return    boolean; #t = no uses, #f = has uses (or op is null)
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define (operation-use-empty? op)   (= 1 (%use-empty op)))

  ;; @brief mlir::Operation::getAttrOfType<StringAttr> — return a string attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute value string; empty string if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-string-attr   %get-string-attr)

  ;; @brief mlir::Operation::getAttrOfType<IntegerAttr> — return an integer attribute value.
  ;; @param op           Operation* uptr
  ;; @param attr-name    Attribute name (string)
  ;; @param default-val  Value returned when attribute is absent
  ;; @return             Attribute value as integer-64, or default-val
  ;; @see                mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note               Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-integer-attr  %get-integer-attr)

  ;; @brief mlir::Operation — return a DenseI64ArrayAttr or ArrayAttr as a Scheme list.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Scheme list of integers; '() if absent, wrong type, or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp; tries DenseI64ArrayAttr first
  (define operation-get-integer-array-attr %get-integer-array-attr)

  ;; @brief mlir::Operation::setAttr — set a Float32 attribute.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Float value (double, truncated to f32 internally)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-f32-attr!     %set-f32-attr)

  ;; @brief mlir::Operation::setAttr — set an i64 IntegerAttr.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Integer value (integer-64)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-i64-attr!     %set-i64-attr)

  ;; @brief mlir::Operation::setAttr — set a UnitAttr (presence-only flag).
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-unit-attr!    %set-unit-attr)

  ;; @brief mlir::Operation::setAttr — set an IndexType IntegerAttr.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @param value Index value (integer-64)
  ;; @return      void
  ;; @see         mlir/IR/Operation.h, mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-index-attr!   %set-index-attr)

  ;; @brief mlir::Operation::setAttr — set a DenseI64ArrayAttr from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-dense-i64-array! %set-dense-i64-array)

  ;; @brief mlir::Operation::setAttr — set an ArrayAttr of i64 IntegerAttrs from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp; use operation-set-dense-i64-array! for dense form
  (define operation-set-i64-array-attr!  %set-i64-array-attr)

  ;; @brief mlir::Operation::setAttr — set a DenseI32ArrayAttr from a Scheme list.
  ;; @param op          Operation* uptr
  ;; @param name        Attribute name (string)
  ;; @param values-list Scheme list of integers (truncated to i32)
  ;; @return            void
  ;; @see               mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note              Defined in lib/Bindings/IR/Operation.cpp
  (define operation-set-dense-i32-array! %set-dense-i32-array)

  ;; @brief mlir::Operation::setAttr — copy an attribute from src-op to dst-op.
  ;; @param dst-op    Destination Operation* uptr
  ;; @param dst-name  Attribute name on the destination (string)
  ;; @param src-op    Source Operation* uptr
  ;; @param src-name  Attribute name on the source (string)
  ;; @return          void; no-op if either op is null or src attr is absent
  ;; @see             mlir/IR/Operation.h
  ;; @note            Defined in lib/Bindings/IR/Operation.cpp
  (define operation-copy-attr!        %copy-attr)

  ;; @brief mlir::Operation::hasAttr — return #t if the named attribute is present.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @return      boolean; #t = attribute present, #f = absent or op is null
  ;; @see         mlir/IR/Operation.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define (operation-has-attr? op name) (= 1 (%has-attr op name)))

  ;; @brief mlir::Operation::emitError — emit a compiler error diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Error message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define operation-emit-error!       %emit-error)

  ;; @brief mlir::Operation::emitWarning — emit a compiler warning diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Warning message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define operation-emit-warning!     %emit-warning)

  ;; @brief mlir::Operation::emitRemark — emit a compiler remark diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Remark message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define operation-emit-remark!      %emit-remark)

  ;; @brief mlir::Operation::erase — remove and deallocate this operation.
  ;; @param op  Operation* uptr
  ;; @return    void
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp; op pointer is invalid after this call
  (define operation-erase!            %erase)

  ;; @brief mlir::Operation::getAttr — get an attribute as opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute* as uptr; 0 if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-attr          %get-attr)

  ;; @brief mlir::Operation::setAttr — set an attribute from an opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @param attr       Attribute* as uptr
  ;; @return           void
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define (operation-set-attr! op name attr) (%set-attr op name attr))

  ;; @brief mlir::FloatAttr::getValueAsDouble — get a float attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           double value; NaN if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define operation-get-float-attr    %get-float-attr)

  ;;===--------------------------------------------------------------------===;;
  ;; operation-get-operands — bind operands by spec into a list of values.
  ;;
  ;; (operation-get-operands op 'required 'optional 'variadic ...)
  ;;
  ;; Returns a list with one element per spec entry:
  ;;   required → Value uptr
  ;;   optional → Value uptr if present, (if #f #f) if absent
  ;;   variadic → list of Value uptrs if non-empty, (if #f #f) if empty
  ;;
  ;; If any optional/variadic in spec, op must have operandSegmentSizes.
  ;; For all-required specs, no attribute read is needed.
  ;;===--------------------------------------------------------------------===;;
  (define %absent (if #f #f))  ; sentinel: absent optional/variadic slot

  (define (operation-get-operands op . spec)
    (define (read-op i) (op-operand-get-value op i))
    (let ([has-flex (loop :initially := #f
                         :for s :in spec
                         :break #t :if (memq s '(optional variadic)))])
      (if (not has-flex)
          ;; All required: verify count matches spec, then bind sequentially.
          (let ([n-spec (length spec)]
                [n-ops  (operation-get-num-operands op)])
            (unless (= n-spec n-ops)
              (error 'operation-get-operands
                     "operand count mismatch: spec expects" n-spec "but op has" n-ops))
            (loop :for i :from 0 :below n-spec
                  :collect (read-op i)))
          ;; Has optional or variadic: use operandSegmentSizes attribute.
          (let ([attr (operation-get-attr op "operandSegmentSizes")])
            (unless (and attr (not (zero? attr)))
              (error 'operation-get-operands
                     "op must have operandSegmentSizes for optional/variadic operands"))
            ;; with-array-ref manages the ref lifecycle.
            (with-array-ref (segs (dense-i32-array-attr-as-array-ref attr))
              (let* ([n     (array-ref-size segs)]
                     [n-spec (length spec)]
                     [_      (unless (= n n-spec)
                               (error 'operation-get-operands
                                      "operandSegmentSizes count mismatch: spec has"
                                      n-spec "segments but attr has" n))]
                     [sizes  (loop :for i :from 0 :below n
                                   :collect (array-ref-at segs i 'i32))]
                     [starts (let lp ([ss sizes] [off 0] [acc '()])
                               (if (null? ss)
                                   (reverse acc)
                                   (lp (cdr ss) (+ off (car ss)) (cons off acc))))])
                (loop :for kind  :in spec
                        :for start :in starts
                        :for size  :in sizes
                        :collect
                        (case kind
                          [(:required)
                           (read-op start)]
                          [(:optional)
                           (if (zero? size) %absent (read-op start))]
                          [(:variadic)
                           (if (zero? size)
                               %absent
                               (loop :for i :from start :below (+ start size)
                                     :collect (read-op i)))]
                          [else
                           (error 'operation-get-operands
                                  "unknown kind: expected :required/:optional/:variadic"
                                  kind)]))))))))

) ;; end library (mlir ir operation)
