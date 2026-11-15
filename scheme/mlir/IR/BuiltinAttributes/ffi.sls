#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/BuiltinAttributes.h,
;;         mlir/AsmParser/AsmParser.h (mlir::parseAttribute).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR BuiltinAttributes ffi) — raw C bindings for mlir/IR/BuiltinAttributes.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR BuiltinAttributes) for normal use.
;; The old generic dispatch (mlir-make-attr, mlir-attr-isa, etc.) has been
;; removed; use (mlir IR BuiltinAttributes) or these raw bindings directly.
;;
;; Symbol naming follows the C++ convention: mlir::ClassName::methodName[<Specialization>]
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR BuiltinAttributes ffi)
  (export
    %mlir::IntegerAttr::get<i8>
    %mlir::IntegerAttr::get<i16>
    %mlir::IntegerAttr::get<i32>
    %mlir::IntegerAttr::get<i64>
    %mlir::IntegerAttr::get<index>
    %mlir::FloatAttr::get<f32>
    %mlir::UnitAttr::get
    %mlir::DenseI8ArrayAttr::get
    %mlir::DenseI16ArrayAttr::get
    %mlir::DenseI32ArrayAttr::get
    %mlir::DenseI64ArrayAttr::get
    %mlir::parseAttribute
    %mlir::DenseResourceElementsAttr::get
    %mlir::StringAttr::get
    %mlir::StringAttr::get<StringRef>
    %mlir::TypeAttr::get
    %mlir::TypeAttr::getValue
    %mlir::AffineMapAttr::get
    %mlir::AffineMapAttr::getValue
    %mlir::DenseElementsAttr::get<f64>
    %mlir::isa<IntegerAttr>
    %mlir::isa<FloatAttr>
    %mlir::isa<StringAttr>
    %mlir::isa<DenseI32ArrayAttr>
    %mlir::isa<DenseElementsAttr>
    %mlir::DenseElementsAttr::isSplat
    %mlir::IntegerAttr::getValue
    %mlir::FloatAttr::getValueAsDouble
    %mlir::DenseI64ArrayAttr::asArrayRef
    %mlir::DenseI32ArrayAttr::asArrayRef
    %mlir::DenseElementsAttr::getSplatValue<APFloat>
    %mlir::DenseElementsAttr::getSplatValue<APInt>
    %mlir::DenseElementsAttr::getType
    %mlir::DenseElementsAttr::reshape
    %mlir::DenseI32ArrayAttr::toVector
    %mlir::DenseI64ArrayAttr::toVector
    %mlir::FloatAttr::get<f64>
    %mlir::DenseElementsAttr::getNumElements
    %mlir::DenseElementsAttr::getValueAt<f64>
    %mlir::ArrayAttr::get
    %mlir::ArrayAttr::getElement
    %mlir::isa<ArrayAttr>
    %mlir::FlatSymbolRefAttr::get
    %mlir::isa<FlatSymbolRefAttr>
    %mlir::FlatSymbolRefAttr::getValue
    %mlir::ArrayAttr::size)
  (import (rnrs)
          (crest support foreign) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::StringAttr::get — construct a StringAttr from a Scheme string.
  ;; @param ctx    MLIRContext* uptr
  ;; @param str    Scheme string
  ;; @return       StringAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::StringAttr::get
    (crest-foreign-procedure "mlir::StringAttr::get" (uptr string) uptr))

  ;; @brief mlir::StringAttr::get<StringRef> — construct a StringAttr with explicit byte count.
  ;; Required when the string contains embedded NUL bytes (e.g. C format strings).
  (define %mlir::StringAttr::get<StringRef>
    (crest-foreign-procedure "mlir::StringAttr::get<StringRef>" (uptr string uptr) uptr))

  ;; @brief mlir::TypeAttr::get — wrap an mlir::Type as a TypeAttr.
  ;; @param type   Type opaque pointer uptr
  ;; @return       TypeAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::TypeAttr::get
    (crest-foreign-procedure "mlir::TypeAttr::get" (uptr) uptr))

  ;; @brief mlir::TypeAttr::getValue — extract the mlir::Type wrapped in a TypeAttr.
  ;; @param attr  TypeAttr opaque pointer uptr
  ;; @return      Type opaque pointer uptr
  (define %mlir::TypeAttr::getValue
    (crest-foreign-procedure "mlir::TypeAttr::getValue" (uptr) uptr))

  ;; @brief mlir::AffineMapAttr::get — wrap an AffineMap as an AffineMapAttr.
  ;; @param map  AffineMap opaque pointer uptr (see (mlir IR AffineMap))
  ;; @return     AffineMapAttr opaque pointer uptr
  (define %mlir::AffineMapAttr::get
    (crest-foreign-procedure "mlir::AffineMapAttr::get" (uptr) uptr))

  ;; @brief mlir::AffineMapAttr::getValue — extract the AffineMap wrapped in an AffineMapAttr.
  ;; @param attr  AffineMapAttr opaque pointer uptr
  ;; @return      AffineMap opaque pointer uptr
  (define %mlir::AffineMapAttr::getValue
    (crest-foreign-procedure "mlir::AffineMapAttr::getValue" (uptr) uptr))

  (define %mlir::DenseElementsAttr::get<f64>
    (crest-foreign-procedure "mlir::DenseElementsAttr::get<f64>" (uptr scheme-object) uptr))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i64 (integer<64>) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::get<i64>
    (crest-foreign-procedure "mlir::IntegerAttr::get<i64>"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i8, i16 or i32 type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (narrowed to the width)
  ;; @return       IntegerAttr opaque pointer uptr
  (define %mlir::IntegerAttr::get<i8>
    (crest-foreign-procedure "mlir::IntegerAttr::get<i8>" (uptr scheme-object) uptr))
  (define %mlir::IntegerAttr::get<i16>
    (crest-foreign-procedure "mlir::IntegerAttr::get<i16>" (uptr scheme-object) uptr))
  (define %mlir::IntegerAttr::get<i32>
    (crest-foreign-procedure "mlir::IntegerAttr::get<i32>" (uptr scheme-object) uptr))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with IndexType.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::get<index>
    (crest-foreign-procedure "mlir::IntegerAttr::get<index>"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::FloatAttr::get — construct a FloatAttr with f32 (Float32) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme flonum (cast to float via Sflonum_value)
  ;; @return       FloatAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::FloatAttr::get<f32>
    (crest-foreign-procedure "mlir::FloatAttr::get<f32>"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI8ArrayAttr::get, mlir::DenseI16ArrayAttr::get — from a Scheme list or vector.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list or vector of exact integers (each narrowed to the element type)
  ;; @return       the attribute's opaque pointer uptr
  (define %mlir::DenseI8ArrayAttr::get
    (crest-foreign-procedure "mlir::DenseI8ArrayAttr::get" (uptr scheme-object) uptr))
  (define %mlir::DenseI16ArrayAttr::get
    (crest-foreign-procedure "mlir::DenseI16ArrayAttr::get" (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI32ArrayAttr::get — construct a DenseI32ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of fixnums (each cast to int32_t via Sfixnum_value)
  ;; @return       DenseI32ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseI32ArrayAttr::get
    (crest-foreign-procedure "mlir::DenseI32ArrayAttr::get"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI64ArrayAttr::get — construct a DenseI64ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of exact integers (each coerced to int64_t via Sinteger64_value)
  ;; @return       DenseI64ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseI64ArrayAttr::get
    (crest-foreign-procedure "mlir::DenseI64ArrayAttr::get"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::parseAttribute — parse an attribute from MLIR textual syntax.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme string containing MLIR attribute syntax (e.g. "#some.attr<...>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises error if parse fails
  ;; @see          mlir/AsmParser/AsmParser.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::parseAttribute
    (crest-foreign-procedure "mlir::parseAttribute"
                             (uptr string) uptr))

  ;; @brief mlir::DenseResourceElementsAttr::get — construct a DenseResourceElementsAttr.
  ;; @param ctx    MLIRContext* uptr (unused; type carries the context)
  ;; @param value  Scheme list of (result-type-uptr key-string data-addr-integer data-size-integer)
  ;;               where result-type-uptr is a RankedTensorType opaque pointer,
  ;;               key-string is a Scheme string blob key, data-addr and data-size
  ;;               describe a raw memory region
  ;; @return       DenseResourceElementsAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseResourceElementsAttr::get
    (crest-foreign-procedure "mlir::DenseResourceElementsAttr::get"
                             (uptr scheme-object) uptr))

  ;; @brief mlir::isa<IntegerAttr> — test whether an opaque attribute pointer is an IntegerAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::IntegerAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<IntegerAttr>
    (crest-foreign-procedure "mlir::isa<IntegerAttr>" (uptr) int))

  ;; @brief mlir::isa<FloatAttr> — test whether an opaque attribute pointer is a FloatAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::FloatAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<FloatAttr>
    (crest-foreign-procedure "mlir::isa<FloatAttr>" (uptr) int))

  ;; @brief mlir::isa<StringAttr> — test whether an opaque attribute pointer is a StringAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::StringAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<StringAttr>
    (crest-foreign-procedure "mlir::isa<StringAttr>" (uptr) int))

  ;; @brief mlir::isa<DenseI32ArrayAttr> — test whether an opaque attribute pointer is a DenseI32ArrayAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseI32ArrayAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<DenseI32ArrayAttr>
    (crest-foreign-procedure "mlir::isa<DenseI32ArrayAttr>"
                             (uptr) int))

  ;; @brief mlir::isa<DenseElementsAttr> — test whether an opaque attribute pointer is a DenseElementsAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseElementsAttr (or subclass), 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<DenseElementsAttr>
    (crest-foreign-procedure "mlir::isa<DenseElementsAttr>"
                             (uptr) int))

  ;; @brief mlir::DenseElementsAttr::isSplat — test whether a DenseElementsAttr is a splat.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is a DenseElementsAttr and isSplat() is true, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::isSplat
    (crest-foreign-procedure "mlir::DenseElementsAttr::isSplat"
                             (uptr) int))

  ;; @brief mlir::IntegerAttr::getValue — extract the integer value of an IntegerAttr.
  ;; @param attr   mlir::IntegerAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::getValue
    (crest-foreign-procedure "mlir::IntegerAttr::getValue"
                             (uptr) scheme-object))

  ;; @brief mlir::FloatAttr::getValueAsDouble — extract the float value of a FloatAttr.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via Sflonum / getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::FloatAttr::getValueAsDouble
    (crest-foreign-procedure "mlir::FloatAttr::getValueAsDouble"
                             (uptr) scheme-object))

  ;; @brief mlir::DenseI64ArrayAttr::asArrayRef — the elements of a DenseI64ArrayAttr, copied into a list.
  ;; @param attr   mlir::DenseI64ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       list of integers (a copy: nothing for the caller to free)
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define %mlir::DenseI64ArrayAttr::asArrayRef
    (crest-foreign-procedure "mlir::DenseI64ArrayAttr::asArrayRef"
                             (uptr) scheme-object))

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — the elements of a DenseI32ArrayAttr, copied into a list.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       list of integers (a copy: nothing for the caller to free)
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define %mlir::DenseI32ArrayAttr::asArrayRef
    (crest-foreign-procedure "mlir::DenseI32ArrayAttr::asArrayRef"
                             (uptr) scheme-object))

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APFloat> — extract the splat float value.
  ;; @param attr   mlir::DenseFPElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme flonum (double precision via convertToDouble on the splat APFloat)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::getSplatValue<APFloat>
    (crest-foreign-procedure "mlir::DenseElementsAttr::getSplatValue<APFloat>"
                             (uptr) scheme-object))

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APInt> — extract the splat integer value.
  ;; @param attr   mlir::DenseIntElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue on the splat APInt)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::getSplatValue<APInt>
    (crest-foreign-procedure "mlir::DenseElementsAttr::getSplatValue<APInt>"
                             (uptr) scheme-object))

  ;; @brief mlir::DenseI32ArrayAttr::toVector — convert a DenseI32ArrayAttr to a Scheme vector.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme vector of fixnums, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define %mlir::DenseI32ArrayAttr::toVector
    (crest-foreign-procedure "mlir::DenseI32ArrayAttr::toVector" (uptr) scheme-object))

  ;; @brief mlir::DenseI64ArrayAttr::toVector — convert a DenseI64ArrayAttr to a Scheme vector.
  ;; @param attr   mlir::DenseI64ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme vector of integers, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define %mlir::DenseI64ArrayAttr::toVector
    (crest-foreign-procedure "mlir::DenseI64ArrayAttr::toVector" (uptr) scheme-object))

  ;; @brief mlir::UnitAttr::get — create a UnitAttr (presence-only flag).
  ;; @param ctx  MLIRContext* uptr
  ;; @return     UnitAttr opaque ptr as uptr
  ;; @see        mlir/IR/BuiltinAttributes.h
  (define %mlir::UnitAttr::get
    (crest-foreign-procedure "mlir::UnitAttr::get" (uptr) uptr))


  (define %mlir::DenseElementsAttr::getType
    (crest-foreign-procedure "mlir::DenseElementsAttr::getType" (uptr) uptr))

  (define %mlir::DenseElementsAttr::reshape
    (crest-foreign-procedure "mlir::DenseElementsAttr::reshape" (uptr uptr) uptr))

  (define %mlir::FloatAttr::get<f64>
    (crest-foreign-procedure "mlir::FloatAttr::get<f64>" (uptr double) uptr))

  (define %mlir::DenseElementsAttr::getNumElements
    (crest-foreign-procedure "mlir::DenseElementsAttr::getNumElements" (uptr) uptr))

  (define %mlir::DenseElementsAttr::getValueAt<f64>
    (crest-foreign-procedure "mlir::DenseElementsAttr::getValueAt<f64>" (uptr uptr) uptr))

  (define %mlir::ArrayAttr::get
    (crest-foreign-procedure "mlir::ArrayAttr::get" (uptr scheme-object) uptr))

  (define %mlir::ArrayAttr::getElement
    (crest-foreign-procedure "mlir::ArrayAttr::getElement" (uptr uptr) uptr))

  (define %mlir::FlatSymbolRefAttr::get
    (crest-foreign-procedure "mlir::FlatSymbolRefAttr::get" (uptr string) uptr))

  (define %mlir::isa<FlatSymbolRefAttr>
    (crest-foreign-procedure "mlir::isa<FlatSymbolRefAttr>" (uptr) int))

  (define %mlir::FlatSymbolRefAttr::getValue
    (crest-foreign-procedure "mlir::FlatSymbolRefAttr::getValue" (uptr) string))

  (define %mlir::isa<ArrayAttr>
    (crest-foreign-procedure "mlir::isa<ArrayAttr>" (uptr) int))

  (define %mlir::ArrayAttr::size
    (crest-foreign-procedure "mlir::ArrayAttr::size" (uptr) integer-64))

  ) ;; end library (mlir IR BuiltinAttributes ffi)
