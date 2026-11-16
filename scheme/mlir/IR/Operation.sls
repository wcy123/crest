#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Operation) — Operation inspection, mutation, attr access, walk.
;;
;; Mirrors mlir/IR/Operation.h.
;; Imports raw bindings from (mlir IR Operation ffi); Scheme helpers added here.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Operation)
  (export
    mlir::Operation::getName
    mlir::Operation::getContext
    mlir::Operation::getOperand
    mlir::Operation::getNumOperands
    mlir::Operation::getNumResults
    mlir::Operation::getOpOperand
    mlir::Operation::getResult
    mlir::Operation::getParentOp
    mlir::OpOperand::get
    mlir::OpResult::getOwner
    mlir::Operation::getLoc
    mlir::Operation::getRegion
    mlir::Operation::walk
    mlir::Operation::setOperand
    mlir::Operation::use_empty?
    mlir::Operation::getAttrOfType<StringAttr>
    mlir::Operation::getAttrOfType<IntegerAttr>

    mlir::Operation::hasAttr?
    mlir::Operation::emitError
    mlir::Operation::emitOpError
    mlir::Operation::verify?
    mlir::Operation::emitWarning
    mlir::Operation::emitRemark
    mlir::Operation::dump
    mlir::Operation::print
    mlir::Operation::erase
    mlir::Operation::getAttr
    mlir::Operation::setAttr!
    mlir::Operation::removeAttr
    mlir::Operation::getAttrOfType<FloatAttr>
    mlir::Operation::getAttrDictionary
    mlir::Operation::setAttrs
    mlir::Operation::getBlock
    mlir::Operation::moveBefore
    mlir::Operation::setOperands
    mlir::Operation::getParentOfType<ModuleOp>
    operation-get-operands
    operation-get-converted-operands)
  (import (rnrs)
          (only (crest callback) with-c-callable/lambda)
          (mlir IR Operation ffi)
          (rename (rime loop) (:with :rime-with))
          (only (mlir IR BuiltinAttributes)
                mlir::DenseI32ArrayAttr::asArrayRef
                mlir::DenseI64ArrayAttr::asArrayRef)
          (crest support array-ref))

  ;; @brief mlir::Operation::getName — return the registered op name (e.g. "arith.addi").
  ;; @param op  Operation* uptr
  ;; @return    Interned string; valid for the lifetime of the MLIRContext
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getName          %get-name)

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  ;; @param op  Operation* uptr
  ;; @return    MLIRContext* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getContext       %get-context)

  ;; @brief mlir::Operation::getNumOperands — return the number of operands.
  ;; @param op  Operation* uptr
  ;; @return    Operand count; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getOperand      %mlir::Operation::getOperand)
  (define mlir::Operation::getNumOperands  %get-num-operands)

  ;; @brief mlir::Operation::getNumResults — return the number of results.
  ;; @param op  Operation* uptr
  ;; @return    Result count; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getNumResults   %get-num-results)

  ;; @brief mlir::Operation::getOperand — return the i-th operand as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getOpOperand    %get-op-operand)

  ;; @brief mlir::Operation::getResult — return the i-th result as an opaque Value*.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getResult        %get-result)

  ;; @brief mlir::Operation::getParentOp — return the enclosing operation, or #f.
  ;; @param op  Operation* uptr
  ;; @return    Operation* as uptr; #f if op is null or has no parent op
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define (mlir::Operation::getParentOp op)
    (let ([v (%get-parent-op op)]) (if (zero? v) #f v)))

  ;; @brief mlir_ir_op_operand_get_value — return the i-th operand Value* of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::OpOperand::get        %mlir::OpOperand::get)

  ;; @brief mlir_ir_op_result_get_value — return the i-th result Value* of an op.
  ;; @param op     Operation* uptr
  ;; @param index  0-based result index (int)
  ;; @return       Opaque Value* as uptr; 0 if null or out of range
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::OpResult::getOwner         %mlir::OpResult::getOwner)

  ;; @brief mlir::Operation::getLoc — return the source location attached to this op.
  ;; @param op  Operation* uptr
  ;; @return    Opaque Location* as uptr; 0 if op is null
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getLoc           %mlir::Operation::getLoc)
  (define mlir::Operation::getRegion        %mlir::Operation::getRegion)

  ;; @brief mlir::Operation::walk — walk all nested ops, calling callback for each.
  ;; @param op        Operation* uptr (root of walk)
  ;; @param callback  an expression for a procedure invoked with each Operation* uptr. It answers one of the
  ;;                  constants of (mlir Support WalkResult): advance to go on, skip, or interrupt to stop the
  ;;                  walk (the C++ visitor is WalkResult(Operation*)). The procedure is a C function for the
  ;;                  length of the walk, and released when the walk is over, also on an error. An error of
  ;;                  the procedure is reported as a diagnostic at the Scheme source of the procedure, in
  ;;                  (current-MLIRContext), and the walk is interrupted.
  ;; @return          the WalkResult of the walk, a number: interrupt when a visitor stopped it, else advance
  ;; @see             mlir/IR/Operation.h
  ;; @note            A macro. Defined in lib/Bindings/IR/Operation.cpp
  (define-syntax mlir::Operation::walk
    (syntax-rules ()
      [(_ op callback)
       (with-c-callable/lambda (visit (uptr) walk-result callback)
         (%walk op visit))]))

  ;; @brief mlir::Operation::setOperand — replace the i-th operand with a new value.
  ;; @param op     Operation* uptr
  ;; @param index  0-based operand index (int)
  ;; @param value  New operand Value* as uptr
  ;; @return       void
  ;; @see          mlir/IR/Operation.h
  ;; @note         Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::setOperand       %set-operand)

  ;; @brief mlir::Operation::use_empty — return #t if this op has no uses.
  ;; @param op  Operation* uptr
  ;; @return    boolean; #t = no uses, #f = has uses (or op is null)
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp
  (define (mlir::Operation::use_empty? op)   (= 1 (%use-empty op)))

  ;; @brief mlir::Operation::getAttrOfType<StringAttr> — return a string attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute value string; empty string if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getAttrOfType<StringAttr>   %get-string-attr)

  ;; @brief mlir::Operation::getAttrOfType<IntegerAttr> — return an integer attribute value.
  ;; @param op           Operation* uptr
  ;; @param attr-name    Attribute name (string)
  ;; @param default-val  Value returned when attribute is absent
  ;; @return             Attribute value as integer-64, or default-val
  ;; @see                mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note               Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getAttrOfType<IntegerAttr>  %get-integer-attr)

  ;; @brief mlir::Operation::hasAttr — return #t if the named attribute is present.
  ;; @param op    Operation* uptr
  ;; @param name  Attribute name (string)
  ;; @return      boolean; #t = attribute present, #f = absent or op is null
  ;; @see         mlir/IR/Operation.h
  ;; @note        Defined in lib/Bindings/IR/Operation.cpp
  (define (mlir::Operation::hasAttr? op name) (= 1 (%has-attr op name)))

  ;; @brief mlir::Operation::emitError — emit a compiler error diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Error message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::emitError       %emit-error)

  ;; @brief mlir::Operation::emitOpError — emit an error that names the op ("'dialect.op' op ...").
  ;; @param op   Operation* uptr
  ;; @param msg  Error message (string)
  ;; @see        mlir/IR/Operation.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::emitOpError     %emit-op-error)

  ;; @brief mlir::verify — verify the operation and everything nested in it.
  ;; @param op   Operation* uptr
  ;; @return     #t when it verifies, #f after emitting the diagnostics
  ;; @see        mlir/IR/Verifier.h
  (define (mlir::Operation::verify? op) (= 1 (%verify op)))

  ;; @brief mlir::Operation::emitWarning — emit a compiler warning diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Warning message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::emitWarning     %emit-warning)

  ;; @brief mlir::Operation::emitRemark — emit a compiler remark diagnostic.
  ;; @param op   Operation* uptr (may be null; falls back to logging)
  ;; @param msg  Remark message (string)
  ;; @return     void
  ;; @see        mlir/IR/Operation.h, mlir/IR/Diagnostics.h
  ;; @note       Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::emitRemark      %emit-remark)

  ;; @brief mlir::Operation::dump — print the operation to stderr (debugging aid).
  (define (mlir::Operation::dump op)
    (%mlir::Operation::dump op))

  ;; @brief mlir::Operation::print — return full MLIR textual form as a string (for debugging).
  ;; For debugging only — shows operands, attrs, types, regions in MLIR text format.
  (define mlir::Operation::print              %mlir::Operation::print)

  ;; @brief mlir::Operation::erase — remove and deallocate this operation.
  ;; @param op  Operation* uptr
  ;; @return    void
  ;; @see       mlir/IR/Operation.h
  ;; @note      Defined in lib/Bindings/IR/Operation.cpp; op pointer is invalid after this call
  (define mlir::Operation::erase            %erase)

  ;; @brief mlir::Operation::getAttr — get an attribute as opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           Attribute* as uptr; #f if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  ;; %get-attr returns 0 (null uptr) on absence; normalised to #f here so
  ;; callers can write (when (mlir::Operation::getAttr op name) ...) idiomatically.
  (define (mlir::Operation::getAttr op name)
    (let ([v (%get-attr op name)])
      (if (zero? v) #f v)))

  ;; @brief mlir::Operation::setAttr! — set an attribute from an opaque Attribute*.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @param attr       Attribute* as uptr
  ;; @return           void
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define (mlir::Operation::setAttr! op name attr) (%set-attr op name attr))

  ;; @brief mlir::Operation::removeAttr — remove an attribute and answer it.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           the Attribute* that was removed as uptr, or #f when the op had none
  ;; @see              mlir/IR/Operation.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define (mlir::Operation::removeAttr op name)
    (let ([v (%remove-attr op name)])
      (if (zero? v) #f v)))

  ;; @brief mlir::FloatAttr::getValueAsDouble — get a float attribute value.
  ;; @param op         Operation* uptr
  ;; @param attr-name  Attribute name (string)
  ;; @return           double value; NaN if absent or op is null
  ;; @see              mlir/IR/Operation.h, mlir/IR/BuiltinAttributes.h
  ;; @note             Defined in lib/Bindings/IR/Operation.cpp
  (define mlir::Operation::getAttrOfType<FloatAttr>    %get-float-attr)

  ;; The marker for an absent :optional operand or an empty :variadic group: the value of (if #f #f).
  ;; unbound-value? of (crest pattern-dsl codegen) tests for it.
  (define %%absent (if #f #f))

  ;; @brief %%get-operands — the body of operation-get-operands and operation-get-converted-operands.
  ;; @param op       Operation* uptr. Its attribute operandSegmentSizes gives the number of operands in each
  ;;                 segment, where a segment is a run of consecutive operands.
  ;; @param count    The number of operands in the list that the values are read from.
  ;; @param read-op  A procedure of one argument, i: the operand (a Value uptr) at position i of that list.
  ;; @param spec     A list of symbols, one for each place in the op line of the pattern where operands are
  ;;                 written. A symbol says how many operands the pattern accepts there: :required means
  ;;                 exactly one, :optional zero or one, :variadic zero or more.
  ;; @return         A list with one element for each symbol of spec, or #f when the operands do not fit spec.
  ;; @note           The two callers differ only in the list that count and read-op refer to: the operands
  ;;                 of the op, or the converted operands of a conversion pattern.
  (define (%%get-operands op count read-op spec)
    (define (%%flex-path attr n-spec)
      (let* ([sizes (mlir::DenseI32ArrayAttr::asArrayRef attr)]
             [n     (length sizes)])
        (and (= n n-spec)
             (let* (;; fold-left guarantees left-to-right; map/:rime-with do not.
                    [starts (reverse
                             (car (fold-left (lambda (acc size)
                                               (cons (cons (cdr acc) (car acc))
                                                     (+ (cdr acc) size)))
                                             (cons '() 0)
                                             sizes)))])
               (loop :for symbol :in spec
                     :for start :in starts
                     :for size  :in sizes
                     :collect (case symbol
                                [(:required) (read-op start)]
                                [(:optional) (if (zero? size) %%absent (read-op start))]
                                [(:variadic) (if (zero? size)
                                                 %%absent
                                                 (loop :for i :from start
                                                       :below (+ start size)
                                                       :collect (read-op i)))]
                                [else (error 'operation-get-operands
                                             "unknown symbol in spec: expected :required, :optional or :variadic"
                                             symbol)]))))))
    (let ([n-spec (length spec)]
          [has-flex (loop :initially := #f
                          :for s :in spec
                          :break #t :if (memq s '(:optional :variadic)))])
      (if (not has-flex)
          ;; All required: prefix-match — op must have at least n-spec operands.
          ;; Patterns deliberately list only the operands they care about.
          (and (<= n-spec count)
               (loop :for i :from 0 :below n-spec :collect (read-op i)))
          ;; Has optional/variadic: operandSegmentSizes is mandatory.
          ;; Without it we cannot determine group boundaries — return #f.
          (let ([attr (mlir::Operation::getAttr op "operandSegmentSizes")])
            (and attr (%%flex-path attr n-spec))))))

  ;; @brief operation-get-operands — read the operands of an op as its pattern describes them.
  ;; @param op    Operation* uptr: the op whose operands are read.
  ;; @param spec  A list of symbols, one for each place in the op line of the pattern where operands are
  ;;              written, in order. A symbol says how many operands the pattern accepts there:
  ;;              :required  exactly one operand;
  ;;              :optional  zero or one operand;
  ;;              :variadic  zero or more operands.
  ;;              For the op line `test.conv (%x (:optional %y))` the spec is (:required :optional).
  ;; @return      A list with one element for each symbol of spec, in order:
  ;;              :required → the operand (a Value uptr);
  ;;              :optional → the operand, or the marker %%absent (#<void>) when the pattern's place has none;
  ;;              :variadic → a list of the operands, or %%absent when there are none.
  ;;              #f when the operands do not fit spec: see @note.
  ;; @par Example With operandSegmentSizes = array<i32: 1, 1> and the spec (:required :optional), the first
  ;;              segment has one operand and the second has one operand: the result is (operand0 operand1).
  ;;              With array<i32: 1, 0> the second segment has no operand: the result is (operand0 #<void>).
  ;; @see         mlir/IR/Operation.h, mlir::OpOperand
  ;; @note        A segment is a run of consecutive operands, and the attribute operandSegmentSizes of the
  ;;              op gives the number of operands in each segment, in order. If spec has :optional or
  ;;              :variadic, the op must have that attribute with one size for each symbol of spec, and the
  ;;              i-th symbol describes the i-th segment; otherwise the result is #f. If spec has only
  ;;              :required, the attribute is not read, the i-th symbol describes the i-th operand, and the op
  ;;              must have at least that many operands (a pattern lists only the operands it needs).
  (define (operation-get-operands op . spec)
    (%%get-operands op (mlir::Operation::getNumOperands op)
                    (lambda (i) (mlir::OpOperand::get op i))
                    spec))

  ;; @brief operation-get-converted-operands — operation-get-operands, with the values taken from the
  ;;        converted operands.
  ;; @param op            Operation* uptr: the root op of a conversion pattern. Its operandSegmentSizes give
  ;;                      the segments, as in operation-get-operands.
  ;; @param operands-ref  The converted operands: the operands of op after type conversion, which MLIR gives
  ;;                      to a conversion pattern (a CArrayRef of Value uptrs). op itself still has its original
  ;;                      operands until the rewrite replaces it.
  ;; @param spec          A list of symbols, :required, :optional or :variadic, as for operation-get-operands.
  ;; @return              The same list as operation-get-operands, with the operands taken from operands-ref.
  ;; @note                The segment sizes are those of the original op, so this assumes that the type
  ;;                      converter turns each operand into exactly one operand (docs/manual.md).
  (define (operation-get-converted-operands op operands-ref . spec)
    (%%get-operands op (crest::CArrayRef::size operands-ref)
                    (lambda (i) (crest::CArrayRef::at operands-ref i))
                    spec))

  (define mlir::Operation::getAttrDictionary %mlir::Operation::getAttrDictionary)
  (define mlir::Operation::setAttrs          %mlir::Operation::setAttrs)
  (define mlir::Operation::getBlock          %mlir::Operation::getBlock)
  (define mlir::Operation::moveBefore        %mlir::Operation::moveBefore)
  (define mlir::Operation::setOperands       %mlir::Operation::setOperands)
  (define mlir::Operation::getParentOfType<ModuleOp> %mlir::Operation::getParentOfType<ModuleOp>)

  ) ;; end library (mlir IR Operation)
