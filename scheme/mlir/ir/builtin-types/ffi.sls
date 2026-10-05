#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-types ffi) — raw C bindings for mlir/IR/BuiltinTypes.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir builtin-types) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-types ffi)
  (export
    %mlir::IndexType::get
    %mlir::IntegerType::get<i64>
    %mlir::IntegerType::get<i1>
    %mlir::isa<RankedTensorType>-isa
    %mlir::RankedTensorType::getRank
    %mlir::RankedTensorType::getElementType
    %mlir::RankedTensorType::getShape
    %mlir::RankedTensorType::getEncoding
    %crest::RankedTensorType::cloneWithEncoding
    %shaped-type-get-element-type
    %integer-type-get-width
    %integer-type-is-unsigned)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::IndexType::get — construct an index type in the given context.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IndexType opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::IndexType::get
    (foreign-procedure "mlir::IndexType::get" (uptr) uptr))

  ;; @brief mlir::IntegerType::get(ctx, 64) — construct a 64-bit integer type.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IntegerType (i64) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::IntegerType::get<i64>
    (foreign-procedure "mlir::IntegerType::get<i64>" (uptr) uptr))

  ;; @brief mlir::IntegerType::get(ctx, 1) — construct a 1-bit integer type.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IntegerType (i1) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::IntegerType::get<i1>
    (foreign-procedure "mlir::IntegerType::get<i1>" (uptr) uptr))

  ;; @brief mlir::isa<mlir::RankedTensorType>(type) — check if type is a ranked tensor.
  ;; @param type  Type opaque pointer uptr
  ;; @return      1 if RankedTensorType, 0 otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::isa<RankedTensorType>-isa
    (foreign-procedure "mlir::isa<RankedTensorType>" (uptr) int))

  ;; @brief mlir::RankedTensorType::getRank() — return the rank of a ranked tensor type.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Rank as integer-64, or -1 if type is null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::RankedTensorType::getRank
    (foreign-procedure "mlir::RankedTensorType::getRank"
                       (uptr) integer-64))

  ;; @brief mlir::RankedTensorType::getElementType() — return the element type of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::RankedTensorType::getElementType
    (foreign-procedure
     "mlir::RankedTensorType::getElementType" (uptr) uptr))

  ;; @brief mlir::RankedTensorType::getShape() — return the shape of a ranked tensor as a Scheme list.
  ;; @param type  RankedTensorType opaque pointer (scheme-object)
  ;; @return      List of dimension sizes as Scheme integers; '() if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::RankedTensorType::getShape
    (foreign-procedure "mlir::RankedTensorType::getShape"
                       (uptr) scheme-object))

  ;; @brief mlir::RankedTensorType::getEncoding() — return the encoding attribute of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Encoding Attribute opaque pointer uptr, or 0 if absent or null
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::RankedTensorType::getEncoding
    (foreign-procedure "mlir::RankedTensorType::getEncoding"
                       (uptr) uptr))

  ;; @brief mlir::RankedTensorType::cloneWithEncoding(attr) — clone a ranked tensor type with a new encoding.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @param attr  Attribute opaque pointer uptr for the new encoding
  ;; @return      New RankedTensorType opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %crest::RankedTensorType::cloneWithEncoding
    (foreign-procedure
     "crest::RankedTensorType::cloneWithEncoding"
     (uptr uptr) uptr))

  ;; @brief ShapedType::getElementType() — return the element type of a shaped type.
  ;; @param type  ShapedType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %shaped-type-get-element-type
    (foreign-procedure "mlir::ShapedType::getElementType"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::getWidth() — return the bit width of an integer type.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      Bit width as uptr
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-get-width
    (foreign-procedure "mlir::IntegerType::getWidth"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::isUnsigned() — check if an integer type is unsigned.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      1 if unsigned, 0 otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-is-unsigned
    (foreign-procedure "mlir::IntegerType::isUnsigned"
                       (uptr) int))

) ;; end library (mlir ir builtin-types ffi)
