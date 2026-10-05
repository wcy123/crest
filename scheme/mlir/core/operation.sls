#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core operation) — MLIR Operation primitives.
;;
;; Mirrors mlir/IR/Operation.h. All functions take an Operation* uptr.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core operation)
  (export
    mlir-operation-name
    mlir-operation-get-operands
    mlir-operation-get-context
    mlir-operation-num-operands
    mlir-operation-num-results
    mlir-operation-get-operand
    mlir-operation-get-result
    mlir-operation-get-parent
    mlir-operation-get-operand-value
    mlir-operation-get-result-value
    mlir-operation-get-loc
    mlir-operation-get-block-argument
    mlir-operation-walk
    mlir-operation-get-attribute
    mlir-operation-get-attr
    mlir-operation-set-attribute!
    mlir-operation-has-attr?
    mlir-operation-set-operand
    mlir-operation-use-empty?
    mlir-operation-num-dps-inits
    mlir-operation-get-dps-init-value
    mlir-emit-error!
    mlir-emit-warning!
    mlir-emit-remark!
    mlir-operation-set-f32-attr!
    mlir-operation-set-i64-attr!
    mlir-operation-set-unit-attr!
    mlir-operation-get-integer-attr)

  (import (rnrs)
          (only (chezscheme) foreign-procedure)
          (rename (rime loop) (:with :rime-with))
          (mlir core attribute)
          (mlir support array-ref))

  ;; Return the registered name of the operation (e.g. "onnx.Cast").
  ;; op: Operation* uptr
  ;; Returns: interned string; valid for the lifetime of the operation
  (define mlir-operation-name
    (foreign-procedure "mlir_ir_operation_get_name" (uptr) string))

  ;; Return the MLIRContext that owns the operation.
  ;; op: Operation* uptr
  ;; Returns: MLIRContext* uptr
  (define mlir-operation-get-context
    (foreign-procedure "mlir_ir_operation_get_context" (uptr) uptr))

  ;; Return the number of operands of the operation.
  ;; op: Operation* uptr
  ;; Returns: operand count as iptr (signed platform integer)
  (define mlir-operation-num-operands
    (foreign-procedure "mlir_ir_operation_get_num_operands" (uptr) iptr))

  ;; Return the number of results of the operation.
  ;; op: Operation* uptr
  ;; Returns: result count as iptr
  (define mlir-operation-num-results
    (foreign-procedure "mlir_ir_operation_get_num_results" (uptr) iptr))

  ;; Return the i-th operand as an OpOperand* wrapped in a C-API MlirValue.
  ;; op:    Operation* uptr
  ;; index: 0-based operand index (iptr)
  ;; Returns: C-API value handle uptr; 0 if index out of range
  ;; Note: use mlir-operation-get-operand-value to get the raw Value* opaque ptr
  (define mlir-operation-get-operand
    (foreign-procedure "mlir_ir_operation_get_op_operand" (uptr iptr) uptr))

  ;; Return the i-th result as a C-API MlirValue handle.
  ;; op:    Operation* uptr
  ;; index: 0-based result index (iptr)
  ;; Returns: C-API value handle uptr; 0 if index out of range
  ;; Note: use mlir-operation-get-result-value for the raw Value* opaque ptr
  (define mlir-operation-get-result
    (foreign-procedure "mlir_ir_operation_get_result" (uptr iptr) uptr))

  ;; Return the parent operation, or 0 if at the module root.
  ;; op: Operation* uptr
  ;; Returns: parent Operation* uptr, or 0
  (define mlir-operation-get-parent
    (foreign-procedure "mlir_ir_operation_get_parent_op" (uptr) uptr))

  ;; Return the i-th operand as a raw Value* opaque pointer.
  ;; op:    Operation* uptr
  ;; index: 0-based operand index (int)
  ;; Returns: Value* opaque ptr uptr; 0 if null or out of range
  (define mlir-operation-get-operand-value
    (foreign-procedure "mlir_ir_op_operand_get_value" (uptr int) uptr))

  ;; Return the i-th result as a raw Value* opaque pointer.
  ;; op:    Operation* uptr
  ;; index: 0-based result index (int)
  ;; Returns: Value* opaque ptr uptr; 0 if null or out of range
  (define mlir-operation-get-result-value
    (foreign-procedure "mlir_ir_op_result_get_value" (uptr int) uptr))

  ;; Return the source location of the operation as a Location opaque ptr.
  ;; op: Operation* uptr
  ;; Returns: Location opaque ptr uptr (pass to mlir-emit-error! etc.)
  (define mlir-operation-get-loc
    (foreign-procedure "mlir_ir_operation_get_loc" (uptr) uptr))

  ;; Return the i-th argument of the enclosing func.func, walking up to find it.
  ;; op:    Operation* uptr — any op inside the function
  ;; index: 0-based argument index (int)
  ;; Returns: Value* opaque ptr uptr; 0 if no enclosing func.func or out of range
  (define mlir-operation-get-block-argument
    (foreign-procedure "mlir_ir_block_get_argument" (uptr int) uptr))

  ;; Walk the operation tree in pre-order, calling callback on each op.
  ;; op:       Operation* uptr — root of the walk
  ;; callback: Scheme procedure (lambda (op-uptr) ...) called for each visited op
  ;; The callback is GC-locked for the duration of the walk.
  (define mlir-operation-walk
    (foreign-procedure "mlir_ir_operation_walk" (uptr scheme-object) void))

  ;; Return the named attribute as an opaque Attribute pointer, or 0 if absent.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  ;; Returns: Attribute opaque ptr uptr; 0 if the attribute is not set
  (define mlir-operation-get-attribute
    (foreign-procedure "mlir_operation_get_attribute" (uptr string) uptr))

  ;; Set a named attribute on the operation from an opaque Attribute pointer.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  ;; attr: Attribute opaque ptr uptr (from make-mlir-attribute or mlir-operation-get-attribute)
  (define mlir-operation-set-attribute!
    (foreign-procedure "mlir_operation_set_attribute" (uptr string uptr) void))

  ;; Return #t if the operation has the named attribute, #f otherwise.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  (define (mlir-operation-has-attr? op name)
    (= 1 ((foreign-procedure "mlir_ir_operation_has_attr" (uptr string) int) op name)))

  ;; Typed attribute getters — extract a Scheme value from a named attribute.

  ;; Return the string value of a StringAttr, or "" if absent or wrong type.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  (define %get-string-attr
    (foreign-procedure "mlir_ir_operation_get_string_attr" (uptr string) string))

  ;; Return the integer value of an IntegerAttr, or default-val if absent.
  ;; op:          Operation* uptr
  ;; name:        attribute name string
  ;; default-val: value returned when the attribute is absent (integer-64)
  (define %get-i64-attr
    (foreign-procedure "mlir_ir_operation_get_integer_attr" (uptr string integer-64) integer-64))

  ;; Return a DenseI64ArrayAttr (or ArrayAttr of integers) as a Scheme list of integers.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  ;; Returns: Scheme list of exact integers; '() if absent or wrong type
  (define %get-i64-array-attr
    (foreign-procedure "mlir_ir_operation_get_integer_array_attr" (uptr string) scheme-object))

  ;; Dispatch typed attribute getter by type keyword.
  ;; op:   Operation* uptr
  ;; name: attribute name string
  ;; type: 'string | 'i64 | 'i64-array  (use :string :i64 :i64-array identifier-syntax)
  ;;       also accepts legacy ':string ':i64 ':i64-array (colon-prefix symbols) for compat
  ;; rest: optional default for 'i64 (default 0)
  ;; Raises on unknown type keyword.
  (define (mlir-operation-get-attr op name type . rest)
    (case type
      [(:string string)        (%get-string-attr op name)]
      [(:i64 i64)              (%get-i64-attr op name (if (null? rest) 0 (car rest)))]
      [(:i64-array i64-array)  (%get-i64-array-attr op name)]
      [else (error 'mlir-operation-get-attr "unknown attr type" type)]))

  ;; Get a named IntegerAttr as i64. Returns default-val when absent.
  ;; Convenience alias for the common case — equivalent to (mlir-operation-get-attr op name :i64 default).
  (define mlir-operation-get-integer-attr
    (foreign-procedure "mlir_ir_operation_get_integer_attr" (uptr string integer-64) integer-64))

  ;; Set a named f32 FloatAttr on op.
  (define mlir-operation-set-f32-attr!
    (foreign-procedure "mlir_ir_operation_set_f32_attr" (uptr string double) void))

  ;; Set a named i64 IntegerAttr (signless) on op.
  (define mlir-operation-set-i64-attr!
    (foreign-procedure "mlir_ir_operation_set_i64_attr" (uptr string integer-64) void))

  ;; Set a named UnitAttr on op.
  (define mlir-operation-set-unit-attr!
    (foreign-procedure "mlir_ir_operation_set_unit_attr" (uptr string) void))

  ;; Replace the i-th operand of the operation with a new value.
  ;; op:    Operation* uptr
  ;; index: 0-based operand index (int)
  ;; value: new Value* opaque ptr uptr
  (define mlir-operation-set-operand
    (foreign-procedure "mlir_ir_operation_set_operand" (uptr int uptr) void))

  ;; Return #t if all results of the operation have no uses (op is dead).
  ;; op: Operation* uptr
  (define (mlir-operation-use-empty? op)
    (= 1 ((foreign-procedure "mlir_ir_operation_use_empty" (uptr) int) op)))

  ;; Return the number of DPS (destination-passing style) init operands.
  ;; op: Operation* uptr — must implement DestinationStyleOpInterface
  ;; Returns: 0 if the op does not implement DPS
  (define mlir-operation-num-dps-inits
    (foreign-procedure "mlir_interfaces_dps_get_num_dps_inits" (uptr) int))

  ;; Return the i-th DPS init operand as a Value* opaque ptr.
  ;; op:    Operation* uptr
  ;; index: 0-based init index (int)
  ;; Returns: Value* opaque ptr uptr; 0 if out of range or not a DPS op
  (define mlir-operation-get-dps-init-value
    (foreign-procedure "mlir_interfaces_dps_get_dps_init_value" (uptr int) uptr))

  ;; Emit an error diagnostic attached to op through MLIR's diagnostic engine.
  ;; Falls back to mlir_support_logging_error when op is 0.
  ;; Does not raise a Scheme exception — callers propagate failure explicitly.
  ;; op:  Operation* uptr (or 0 for unattached diagnostic)
  ;; msg: diagnostic message string
  (define mlir-emit-error!
    (foreign-procedure "mlir_ir_operation_emit_error" (uptr string) void))

  ;; Emit a warning diagnostic attached to op. Falls back to mlir_support_logging_warning.
  ;; op:  Operation* uptr (or 0)
  ;; msg: diagnostic message string
  (define mlir-emit-warning!
    (foreign-procedure "mlir_ir_operation_emit_warning" (uptr string) void))

  ;; Emit a remark diagnostic attached to op. Falls back to mlir_support_logging_info.
  ;; op:  Operation* uptr (or 0)
  ;; msg: diagnostic message string
  (define mlir-emit-remark!
    (foreign-procedure "mlir_ir_operation_emit_remark" (uptr string) void))

  ;;===--------------------------------------------------------------------===;;
  ;; mlir-operation-get-operands — bind operands by spec into multiple values.
  ;;
  ;; (mlir-operation-get-operands op 'required 'optional 'variadic ...)
  ;;
  ;; Returns one value per spec entry via (values ...):
  ;;   required → Value uptr
  ;;   optional → Value uptr if present, (if #f #f) absent
  ;;   variadic → list of Value uptrs if non-empty, (if #f #f) if empty
  ;;
  ;; If any optional/variadic in spec, op must have operandSegmentSizes.
  ;; For all-required specs, no attribute read is needed.
  ;;===--------------------------------------------------------------------===;;
  (define %absent (if #f #f))  ; sentinel: absent optional/variadic slot

  (define (mlir-operation-get-operands op . spec)
    (define (read-op i) (mlir-operation-get-operand-value op i))
    (let ([has-flex (loop :initially := #f
                         :for s :in spec
                         :break #t :if (memq s '(optional variadic)))])
      (if (not has-flex)
          ;; All required: verify count matches spec, then bind sequentially.
          (let ([n-spec (length spec)]
                [n-ops  (mlir-operation-num-operands op)])
            (unless (= n-spec n-ops)
              (error 'mlir-operation-get-operands
                     "operand count mismatch: spec expects" n-spec "but op has" n-ops))
            (loop :for i :from 0 :below n-spec
                  :collect (read-op i)))
          ;; Has optional or variadic: use operandSegmentSizes attribute.
          ;; operandSegmentSizes is just a named DenseI32ArrayAttr — no special binding.
          (let ([attr (mlir-operation-get-attribute op "operandSegmentSizes")])
            (unless (and attr (not (zero? attr)))
              (error 'mlir-operation-get-operands
                     "op must have operandSegmentSizes for optional/variadic operands"))
            ;; with-array-ref manages the ref lifecycle.
            (with-array-ref (segs (mlir-attr-as attr :array-ref-i32))
              (let* ([n     (array-ref-size segs)]
                     [n-spec (length spec)]
                     [_      (unless (= n n-spec)
                               (error 'mlir-operation-get-operands
                                      "operandSegmentSizes count mismatch: spec has"
                                      n-spec "segments but attr has" n))]
                     [sizes  (loop :for i :from 0 :below n
                                   :collect (array-ref-at segs i 'i32))]
                     [starts (let loop ([ss sizes] [off 0] [acc '()])
                               (if (null? ss)
                                   (reverse acc)
                                   (loop (cdr ss) (+ off (car ss)) (cons off acc))))])
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
                           (error 'mlir-operation-get-operands
                                  "unknown kind: expected :required/:optional/:variadic"
                                  kind)]))))))))  ; case kind, loop, let* body, with-array-ref, let, if, let, define

) ;; end library (mlir core operation)
