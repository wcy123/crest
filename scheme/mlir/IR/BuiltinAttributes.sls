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
    mlir::DenseI32ArrayAttr::get
    mlir::DenseI64ArrayAttr::get
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
    mlir::DenseI32ArrayAttr::asArrayRef
    mlir::DenseElementsAttr::getSplatValue<APFloat>
    mlir::DenseElementsAttr::getSplatValue<APInt>
    mlir::DenseI32ArrayAttr::asArrayRef->list
    mlir::Operation::getAttr
    mlir::Operation::setAttr!
    mlir::Operation::getAttrOfType<FloatAttr>
    mlir::ShapedType::getElementType
    mlir::IntegerType::getWidth
    mlir::IntegerType::isUnsigned?)
  (import (rnrs)
          (mlir IR BuiltinAttributes ffi)
          (mlir IR Operation ffi)
          (mlir IR BuiltinTypes ffi)
          (mlir IR MLIRContext))

  ;; Constructors — use current-MLIRContext so callers only pass the value.

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i64 (integer<64>) type.
  ;; @param value  Scheme exact integer (coerced to int64_t)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::IntegerAttr::get<i64>; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::IntegerAttr::get<i64> %mlir::IntegerAttr::get<i64> value)

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with IndexType.
  ;; @param value  Scheme exact integer (coerced to int64_t)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::IntegerAttr::get<index>; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::IntegerAttr::get<index> %mlir::IntegerAttr::get<index> value)

  ;; @brief mlir::FloatAttr::get — construct a FloatAttr with f32 (Float32) type.
  ;; @param value  Scheme flonum (cast to float)
  ;; @return       FloatAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::FloatAttr::get<f32>; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::FloatAttr::get<f32> %mlir::FloatAttr::get<f32> value)

  ;; @brief mlir::DenseI32ArrayAttr::get — construct a DenseI32ArrayAttr from a Scheme list.
  ;; @param value  Scheme list of fixnums (each cast to int32_t)
  ;; @return       DenseI32ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::DenseI32ArrayAttr::get; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::DenseI32ArrayAttr::get %mlir::DenseI32ArrayAttr::get value)

  ;; @brief mlir::DenseI64ArrayAttr::get — construct a DenseI64ArrayAttr from a Scheme list.
  ;; @param value  Scheme list of exact integers (each coerced to int64_t)
  ;; @return       DenseI64ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::DenseI64ArrayAttr::get; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::DenseI64ArrayAttr::get %mlir::DenseI64ArrayAttr::get value)

  ;; @brief mlir::parseAttribute — parse an attribute from MLIR textual syntax.
  ;; @param value  Scheme string containing MLIR attribute syntax (e.g. "#some.attr<...>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises error if parse fails
  ;; @see          mlir/AsmParser/AsmParser.h
  ;; @note         Wraps %mlir::parseAttribute; ctx optional, defaults to current-MLIRContext
  (define-ctx-optional mlir::parseAttribute %mlir::parseAttribute value)

  ;; @brief mlir::DenseResourceElementsAttr::get — construct a DenseResourceElementsAttr.
  ;; @param value  Scheme list of (result-type-uptr key-string data-addr-integer data-size-integer)
  ;;               where result-type-uptr is a RankedTensorType opaque pointer
  ;; @return       DenseResourceElementsAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %mlir::DenseResourceElementsAttr::get; ctx optional, defaults to current-MLIRContext
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

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — return a CArrayRef* for a DenseI32ArrayAttr.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64} pair
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::DenseI32ArrayAttr::asArrayRef; caller owns the CArrayRef
  (define mlir::DenseI32ArrayAttr::asArrayRef        %mlir::DenseI32ArrayAttr::asArrayRef)

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

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef->list — convert a DenseI32ArrayAttr to a Scheme list.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme list of fixnums, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %mlir::DenseI32ArrayAttr::asArrayRef->list
  (define mlir::DenseI32ArrayAttr::asArrayRef->list  %mlir::DenseI32ArrayAttr::asArrayRef->list)

  ;; @brief mlir::Operation::getAttr — retrieve a named attribute from an operation.
  ;; @param op     mlir::Operation* uptr
  ;; @param name   C string attribute name
  ;; @return       mlir::Attribute opaque pointer uptr; 0 if attribute not found
  ;; @see          mlir/IR/Operation.h
  ;; @note         Direct alias for %get-attr (from mlir ir operation ffi)
  (define mlir::Operation::getAttr                %get-attr)

  ;; @brief mlir::Operation::setAttr! — set a named attribute on an operation.
  ;; @param op     mlir::Operation* uptr
  ;; @param name   C string attribute name
  ;; @param attr   mlir::Attribute opaque pointer uptr
  ;; @return       unspecified
  ;; @see          mlir/IR/Operation.h
  ;; @note         Wraps %set-attr (from mlir ir operation ffi)
  (define (mlir::Operation::setAttr! op name attr) (%set-attr op name attr))

  ;; @brief mlir::Operation::getAttrOfType<FloatAttr> — retrieve a named FloatAttr as a double.
  ;; @param op     mlir::Operation* uptr (0 returns NaN)
  ;; @param name   C string attribute name (NULL returns NaN)
  ;; @return       double: the float attribute's value, or NaN if not found
  ;; @see          mlir/IR/Operation.h
  ;; @note         Direct alias for %get-float-attr (from mlir ir operation ffi)
  (define mlir::Operation::getAttrOfType<FloatAttr>          %get-float-attr)

  ;; @brief mlir::ShapedType::getElementType — return the element type of a ShapedType.
  ;; @param type   mlir::Type opaque pointer uptr (0 returns 0)
  ;; @return       mlir::Type opaque pointer uptr for the element type; 0 if not a ShapedType
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Direct alias for %mlir::ShapedType::getElementType (from mlir ir builtin-types ffi)
  (define mlir::ShapedType::getElementType          %mlir::ShapedType::getElementType)

  ;; @brief mlir::IntegerType::getWidth — return the bit width of an IntegerType.
  ;; @param type   mlir::Type opaque pointer uptr (0 returns 0)
  ;; @return       uint64 bit width; 0 if not an IntegerType
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Direct alias for %mlir::IntegerType::getWidth (from mlir ir builtin-types ffi)
  (define mlir::IntegerType::getWidth                %mlir::IntegerType::getWidth)

  ;; @brief mlir::IntegerType::isUnsigned — test whether an IntegerType has unsigned signedness.
  ;; @param t      mlir::Type opaque pointer uptr (0 returns #f)
  ;; @return       boolean: #t if the IntegerType is unsigned, #f otherwise
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Wraps %mlir::IntegerType::isUnsigned (from mlir ir builtin-types ffi)
  (define (mlir::IntegerType::isUnsigned? t) (not (zero? (%mlir::IntegerType::isUnsigned t))))

  ) ;; end library (mlir IR BuiltinAttributes)
