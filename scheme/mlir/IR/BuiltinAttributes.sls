#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR BuiltinAttributes) — MLIR builtin attribute bindings.
;;
;; Mirrors mlir/IR/BuiltinAttributes.h.
;; Imports raw C bindings from (mlir IR BuiltinAttributes ffi) and re-exports
;; under clean names following the C++ naming convention:
;;   mlir::ClassName::methodName[<Specialization>]
;;
;; Scheme identifier mapping:
;;   ::  →  :      (class/namespace separator)
;;   <>  →  /      (template specialization)
;;
;; This is the canonical attribute API.  The old generic dispatch
;; (mlir-make-attr, mlir-attr-isa, etc.) in (mlir core attribute) has been removed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR BuiltinAttributes)
  (export
    mlir::IntegerAttr::get<i64>
    mlir::IntegerAttr::get<index>
    mlir::FloatAttr::get<f32>
    mlir::UnitAttr::get
    mlir::DenseI32ArrayAttr::get
    mlir::DenseI64ArrayAttr::get
    mlir::DenseI64ArrayAttr::intoArrayRef
    mlir::parseAttribute
    mlir::DenseResourceElementsAttr::get
    mlir::isa<IntegerAttr>
    mlir::isa<FloatAttr>
    mlir::isa<StringAttr>
    mlir::isa<DenseI32ArrayAttr>
    mlir::isa<DenseElementsAttr>
    mlir::DenseElementsAttr::isSplat
    mlir::isa<FloatAttr.f32>
    mlir::IntegerAttr::getValue
    mlir::FloatAttr::getValueAsDouble
    mlir::FloatAttr::getValueAsDouble.f32
    mlir::DenseI32ArrayAttr::intoArrayRef
    mlir::DenseElementsAttr::getSplatValue<APFloat>
    mlir::DenseElementsAttr::getSplatValue<APInt>
    mlir::DenseI32ArrayAttr::toVector
    mlir::DenseI64ArrayAttr::toVector
    )
  (import (rnrs)
          (mlir IR BuiltinAttributes ffi)
          (mlir IR MLIRContext))

  ;; Constructors — use current-MLIRContext so callers only pass the value.

  ;; @brief mlir::IntegerAttr::get — wrap an int64 integer as an mlir::IntegerAttr (i64 type).
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme exact integer mapped to int64_t
  ;; @return       mlir::IntegerAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::IntegerAttr::get<i64> %mlir::IntegerAttr::get<i64> value)

  ;; @brief mlir::IntegerAttr::get — wrap an integer as an mlir::IntegerAttr (index type).
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme exact integer mapped to int64_t
  ;; @return       mlir::IntegerAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::IntegerAttr::get<index> %mlir::IntegerAttr::get<index> value)

  ;; @brief mlir::FloatAttr::get — wrap a float as an mlir::FloatAttr (f32 type).
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme real number truncated to float32 precision
  ;; @return       mlir::FloatAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::FloatAttr::get<f32> %mlir::FloatAttr::get<f32> value)

  ;; @brief mlir::UnitAttr::get — create a presence-only boolean flag.
  ;;
  ;; Design rationale: UnitAttr encodes a boolean as attribute presence/absence.
  ;; An operation HAVING the attribute means "true"; NOT having it means "false".
  ;; The attribute carries no value — only existence matters.
  ;;
  ;; This avoids storing redundant `= true` in the IR. In MLIR textual format,
  ;; UnitAttr prints as just the name with no value:
  ;;   {packed_int4}         ; UnitAttr — "packed" is true
  ;; compared to a boolean IntegerAttr:
  ;;   {packed_int4 = true}  ; IntegerAttr<i1> — "packed" is true (more verbose)
  ;;
  ;; Example usage: `packed_int4` on hip.qadd marks packed 4-bit weight encoding.
  ;; Check presence with mlir::Operation::hasAttr?, not mlir::Operation::getAttr.
  ;;
  ;; @param ctx  mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     mlir::UnitAttr opaque pointer uptr
  ;;             Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see        mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::UnitAttr::get %mlir::UnitAttr::get)

  ;; @brief mlir::DenseI32ArrayAttr::get — pack a Scheme list or vector into a mlir::DenseI32ArrayAttr.
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme list or vector of fixnums (each truncated to int32_t)
  ;; @return       mlir::DenseI32ArrayAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::DenseI32ArrayAttr::get %mlir::DenseI32ArrayAttr::get value)

  ;; @brief mlir::DenseI64ArrayAttr::get — pack a Scheme list or vector into a mlir::DenseI64ArrayAttr.
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme list or vector of exact integers (each coerced to int64_t)
  ;; @return       mlir::DenseI64ArrayAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::DenseI64ArrayAttr::get %mlir::DenseI64ArrayAttr::get value)

  ;; @brief mlir::parseAttribute — parse MLIR textual syntax into an mlir::Attribute.
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme string with MLIR attribute syntax (e.g. "#hip.mem<device>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises Scheme error if parse fails
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/AsmParser/AsmParser.h
  (define-ctx-optional mlir::parseAttribute %mlir::parseAttribute value)

  ;; @brief mlir::DenseResourceElementsAttr::get — construct a resource-backed dense elements attr.
  ;; @param ctx    mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param value  Scheme list of (mlir::RankedTensorType* uptr  key-string
  ;;                               data-addr-integer  data-size-integer)
  ;; @return       mlir::DenseResourceElementsAttr opaque pointer uptr
  ;;               Context-owned — valid for the MLIRContext lifetime; do NOT free.
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define-ctx-optional mlir::DenseResourceElementsAttr::get %mlir::DenseResourceElementsAttr::get value)

  ;; @brief mlir::isa<IntegerAttr> — test whether an opaque attribute pointer is an IntegerAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::IntegerAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<IntegerAttr>
  (define (mlir::isa<IntegerAttr> a)        (not (zero? (%mlir::isa<IntegerAttr> a))))

  ;; @brief mlir::isa<FloatAttr> — test whether an opaque attribute pointer is a FloatAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::FloatAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<FloatAttr>
  (define (mlir::isa<FloatAttr> a)          (not (zero? (%mlir::isa<FloatAttr> a))))

  ;; @brief mlir::isa<StringAttr> — test whether an opaque attribute pointer is a StringAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::StringAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<StringAttr>
  (define (mlir::isa<StringAttr> a)         (not (zero? (%mlir::isa<StringAttr> a))))

  ;; @brief mlir::isa<DenseI32ArrayAttr> — test whether an opaque attribute pointer is a DenseI32ArrayAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::DenseI32ArrayAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<DenseI32ArrayAttr>
  (define (mlir::isa<DenseI32ArrayAttr> a) (not (zero? (%mlir::isa<DenseI32ArrayAttr> a))))

  ;; @brief mlir::isa<DenseElementsAttr> — test whether an opaque attribute pointer is a DenseElementsAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::DenseElementsAttr (or subclass), #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<DenseElementsAttr>
  (define (mlir::isa<DenseElementsAttr> a)  (not (zero? (%mlir::isa<DenseElementsAttr> a))))

  ;; @brief mlir::DenseElementsAttr::isSplat — test whether a DenseElementsAttr is a splat.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is DenseElementsAttr and isSplat() is true, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::DenseElementsAttr::isSplat
  (define (mlir::DenseElementsAttr::isSplat a) (not (zero? (%mlir::DenseElementsAttr::isSplat a))))

  ;; @brief mlir::isa<FloatAttr> (f32 alias) — alias for mlir::isa<FloatAttr>, tests mlir::FloatAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::FloatAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::isa<FloatAttr.f32> (which delegates to float_attr_isa in C++)
  (define (mlir::isa<FloatAttr.f32> a)        (not (zero? (%mlir::isa<FloatAttr.f32> a))))

  ;; @brief mlir::IntegerAttr::getValue — extract the integer value of an IntegerAttr.
  ;; @param attr   mlir::IntegerAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme exact integer (sign-extended from APInt via getSExtValue)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::IntegerAttr::getValue
  (define mlir::IntegerAttr::getValue                %mlir::IntegerAttr::getValue)

  ;; @brief mlir::FloatAttr::getValueAsDouble — extract the float value of a FloatAttr.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::FloatAttr::getValueAsDouble
  (define mlir::FloatAttr::getValueAsDouble          %mlir::FloatAttr::getValueAsDouble)

  ;; @brief mlir::FloatAttr::getValueAsDouble (f32 alias) — alias for mlir::FloatAttr::getValueAsDouble.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::FloatAttr::getValueAsDouble.f32 (which delegates to float_attr_get_value)
  (define mlir::FloatAttr::getValueAsDouble.f32      %mlir::FloatAttr::getValueAsDouble.f32)

  ;; @brief mlir::DenseI64ArrayAttr::intoArrayRef — transfer a DenseI64ArrayAttr into a CArrayRef*.
  ;; @param attr   mlir::DenseI64ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64}; element type :i64
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Caller owns the returned CArrayRef; always use with-ArrayRef for automatic cleanup:
  ;;
  ;;   (with-ArrayRef (ref (mlir::DenseI64ArrayAttr::intoArrayRef attr))
  ;;     (loop :for i :from 0 :below (ArrayRef::size ref)
  ;;           :collect (ArrayRef::at ref i :i64)))
  (define mlir::DenseI64ArrayAttr::intoArrayRef        %mlir::DenseI64ArrayAttr::intoArrayRef)

  ;; @brief mlir::DenseI32ArrayAttr::intoArrayRef — transfer a DenseI32ArrayAttr into a CArrayRef*.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64}; element type :i32
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Caller owns the returned CArrayRef; always use with-ArrayRef for automatic cleanup:
  ;;
  ;;   (with-ArrayRef (ref (mlir::DenseI32ArrayAttr::intoArrayRef attr))
  ;;     (loop :for i :from 0 :below (ArrayRef::size ref)
  ;;           :collect (ArrayRef::at ref i :i32)))
  (define mlir::DenseI32ArrayAttr::intoArrayRef        %mlir::DenseI32ArrayAttr::intoArrayRef)

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APFloat> — extract the splat float value.
  ;; @param attr   mlir::DenseFPElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme flonum (double precision via convertToDouble on the splat APFloat)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::DenseElementsAttr::getSplatValue<APFloat>
  (define mlir::DenseElementsAttr::getSplatValue<APFloat>  %mlir::DenseElementsAttr::getSplatValue<APFloat>)

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APInt> — extract the splat integer value.
  ;; @param attr   mlir::DenseIntElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme exact integer (sign-extended via getSExtValue on the splat APInt)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::DenseElementsAttr::getSplatValue<APInt>
  (define mlir::DenseElementsAttr::getSplatValue<APInt>    %mlir::DenseElementsAttr::getSplatValue<APInt>)

  ;; @brief mlir::DenseI32ArrayAttr::toVector — convert a DenseI32ArrayAttr to a Scheme vector.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme vector of fixnums, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define mlir::DenseI32ArrayAttr::toVector  %mlir::DenseI32ArrayAttr::toVector)

  ;; @brief mlir::DenseI64ArrayAttr::toVector — convert a DenseI64ArrayAttr to a Scheme vector.
  ;; @param attr   mlir::DenseI64ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme vector of integers, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define mlir::DenseI64ArrayAttr::toVector  %mlir::DenseI64ArrayAttr::toVector)

  ) ;; end library (mlir IR BuiltinAttributes)
