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
    %mlir::IntegerAttr::get<i64>
    %mlir::IntegerAttr::get<index>
    %mlir::FloatAttr::get<f32>
    %mlir::UnitAttr::get
    %mlir::DenseI32ArrayAttr::get
    %mlir::DenseI64ArrayAttr::get
    %mlir::parseAttribute
    %mlir::DenseResourceElementsAttr::get
    %mlir::isa<IntegerAttr>
    %mlir::isa<FloatAttr>
    %mlir::isa<StringAttr>
    %mlir::isa<DenseI32ArrayAttr>
    %mlir::isa<DenseElementsAttr>
    %mlir::DenseElementsAttr::isSplat
    %mlir::isa<FloatAttr.f32>
    %mlir::IntegerAttr::getValue
    %mlir::FloatAttr::getValueAsDouble
    %mlir::FloatAttr::getValueAsDouble.f32
    %mlir::DenseI64ArrayAttr::intoArrayRef
    %mlir::DenseI32ArrayAttr::intoArrayRef
    %mlir::DenseElementsAttr::getSplatValue<APFloat>
    %mlir::DenseElementsAttr::getSplatValue<APInt>
    %mlir::DenseI32ArrayAttr::intoArrayRef->list)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i64 (integer<64>) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::get<i64>
    (foreign-procedure "mlir::IntegerAttr::get<i64>"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with IndexType.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::get<index>
    (foreign-procedure "mlir::IntegerAttr::get<index>"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::FloatAttr::get — construct a FloatAttr with f32 (Float32) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme flonum (cast to float via Sflonum_value)
  ;; @return       FloatAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::FloatAttr::get<f32>
    (foreign-procedure "mlir::FloatAttr::get<f32>"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI32ArrayAttr::get — construct a DenseI32ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of fixnums (each cast to int32_t via Sfixnum_value)
  ;; @return       DenseI32ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseI32ArrayAttr::get
    (foreign-procedure "mlir::DenseI32ArrayAttr::get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI64ArrayAttr::get — construct a DenseI64ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of exact integers (each coerced to int64_t via Sinteger64_value)
  ;; @return       DenseI64ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseI64ArrayAttr::get
    (foreign-procedure "mlir::DenseI64ArrayAttr::get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::parseAttribute — parse an attribute from MLIR textual syntax.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme string containing MLIR attribute syntax (e.g. "#some.attr<...>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises error if parse fails
  ;; @see          mlir/AsmParser/AsmParser.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::parseAttribute
    (foreign-procedure "mlir::parseAttribute"
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
    (foreign-procedure "mlir::DenseResourceElementsAttr::get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::isa<IntegerAttr> — test whether an opaque attribute pointer is an IntegerAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::IntegerAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<IntegerAttr>
    (foreign-procedure "mlir::isa<IntegerAttr>" (uptr) int))

  ;; @brief mlir::isa<FloatAttr> — test whether an opaque attribute pointer is a FloatAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::FloatAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<FloatAttr>
    (foreign-procedure "mlir::isa<FloatAttr>" (uptr) int))

  ;; @brief mlir::isa<StringAttr> — test whether an opaque attribute pointer is a StringAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::StringAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<StringAttr>
    (foreign-procedure "mlir::isa<StringAttr>" (uptr) int))

  ;; @brief mlir::isa<DenseI32ArrayAttr> — test whether an opaque attribute pointer is a DenseI32ArrayAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseI32ArrayAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<DenseI32ArrayAttr>
    (foreign-procedure "mlir::isa<DenseI32ArrayAttr>"
                       (uptr) int))

  ;; @brief mlir::isa<DenseElementsAttr> — test whether an opaque attribute pointer is a DenseElementsAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseElementsAttr (or subclass), 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::isa<DenseElementsAttr>
    (foreign-procedure "mlir::isa<DenseElementsAttr>"
                       (uptr) int))

  ;; @brief mlir::DenseElementsAttr::isSplat — test whether a DenseElementsAttr is a splat.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is a DenseElementsAttr and isSplat() is true, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::isSplat
    (foreign-procedure "mlir::DenseElementsAttr::isSplat"
                       (uptr) int))

  ;; @brief mlir::isa<FloatAttr> (f32 alias) — alias for %mlir::isa<FloatAttr>, tests mlir::FloatAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::FloatAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; delegates to float_attr_isa
  (define %mlir::isa<FloatAttr.f32>
    (foreign-procedure "mlir::isa<FloatAttr>.f32" (uptr) int))

  ;; @brief mlir::IntegerAttr::getValue — extract the integer value of an IntegerAttr.
  ;; @param attr   mlir::IntegerAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::IntegerAttr::getValue
    (foreign-procedure "mlir::IntegerAttr::getValue"
                       (uptr) scheme-object))

  ;; @brief mlir::FloatAttr::getValueAsDouble — extract the float value of a FloatAttr.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via Sflonum / getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::FloatAttr::getValueAsDouble
    (foreign-procedure "mlir::FloatAttr::getValueAsDouble"
                       (uptr) scheme-object))

  ;; @brief mlir::FloatAttr::getValueAsDouble (f32 alias) — alias for %mlir::FloatAttr::getValueAsDouble.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via Sflonum / getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; delegates to float_attr_get_value
  (define %mlir::FloatAttr::getValueAsDouble.f32
    (foreign-procedure "mlir::FloatAttr::getValueAsDouble.f32"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseI64ArrayAttr::intoArrayRef — return a CArrayRef* for a DenseI64ArrayAttr.
  ;; @param attr   mlir::DenseI64ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64} pair; element type :i64
  ;; @see          mlir/IR/BuiltinAttributes.h
  (define %mlir::DenseI64ArrayAttr::intoArrayRef
    (foreign-procedure "mlir::DenseI64ArrayAttr::intoArrayRef"
                       (uptr) uptr))

  ;; @brief mlir::DenseI32ArrayAttr::intoArrayRef — return a CArrayRef* for a DenseI32ArrayAttr.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64} pair
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; caller owns the CArrayRef
  (define %mlir::DenseI32ArrayAttr::intoArrayRef
    (foreign-procedure "mlir::DenseI32ArrayAttr::intoArrayRef"
                       (uptr) uptr))

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APFloat> — extract the splat float value.
  ;; @param attr   mlir::DenseFPElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme flonum (double precision via convertToDouble on the splat APFloat)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::getSplatValue<APFloat>
    (foreign-procedure "mlir::DenseElementsAttr::getSplatValue<APFloat>"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseElementsAttr::getSplatValue<APInt> — extract the splat integer value.
  ;; @param attr   mlir::DenseIntElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue on the splat APInt)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseElementsAttr::getSplatValue<APInt>
    (foreign-procedure "mlir::DenseElementsAttr::getSplatValue<APInt>"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseI32ArrayAttr::intoArrayRef->list — convert a DenseI32ArrayAttr to a Scheme list.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme list of fixnums, one per element (built in reverse then reversed)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %mlir::DenseI32ArrayAttr::intoArrayRef->list
    (foreign-procedure "mlir::DenseI32ArrayAttr::intoArrayRef->list"
                       (uptr) scheme-object))

  ;; @brief mlir::UnitAttr::get — create a UnitAttr (presence-only flag).
  ;; @param ctx  MLIRContext* uptr
  ;; @return     UnitAttr opaque ptr as uptr
  ;; @see        mlir/IR/BuiltinAttributes.h
  (define %mlir::UnitAttr::get
    (foreign-procedure "mlir::UnitAttr::get" (uptr) uptr))

  ) ;; end library (mlir IR BuiltinAttributes ffi)
