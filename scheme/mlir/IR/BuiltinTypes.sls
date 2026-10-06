#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR BuiltinTypes) — MLIR builtin type constructors and queries.
;;
;; Mirrors mlir/IR/BuiltinTypes.h.
;; Imports raw C bindings from (mlir IR BuiltinTypes ffi) and re-exports
;; under clean names. Add Scheme-level helpers here as needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR BuiltinTypes)
  (export
    mlir::IndexType::get
    mlir::IntegerType::get<i64>
    mlir::IntegerType::get<i1>
    mlir::isa<RankedTensorType>?
    mlir::RankedTensorType::getRank
    mlir::RankedTensorType::getElementType
    mlir::RankedTensorType::getShape
    mlir::RankedTensorType::getEncoding
    mlir::RankedTensorType::cloneWithEncoding
    mlir::ShapedType::getElementType
    mlir::IntegerType::getWidth
    mlir::IntegerType::isUnsigned?)
  (import (rnrs)
          (only (mlir IR MLIRContext) current-mlir-context define-ctx-optional)
          (mlir IR BuiltinTypes ffi))

  ;; @brief mlir::IndexType::get — construct an index type in the given context.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     IndexType opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define-ctx-optional mlir::IndexType::get %mlir::IndexType::get)

  ;; @brief mlir::IntegerType::get(ctx, 64) — construct a 64-bit integer type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     IntegerType (i64) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define-ctx-optional mlir::IntegerType::get<i64> %mlir::IntegerType::get<i64>)

  ;; @brief mlir::IntegerType::get(ctx, 1) — construct a 1-bit integer type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     IntegerType (i1) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define-ctx-optional mlir::IntegerType::get<i1> %mlir::IntegerType::get<i1>)

  ;; @brief mlir::RankedTensorType::getRank() — return the rank of a ranked tensor type.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Rank as integer-64, or -1 if type is null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::RankedTensorType::getRank      %mlir::RankedTensorType::getRank)

  ;; @brief mlir::RankedTensorType::getElementType() — return the element type of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::RankedTensorType::getElementType %mlir::RankedTensorType::getElementType)

  ;; @brief mlir::RankedTensorType::getShape() — return the shape of a ranked tensor as a Scheme list.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      List of dimension sizes as Scheme integers; '() if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::RankedTensorType::getShape     %mlir::RankedTensorType::getShape)

  ;; @brief mlir::RankedTensorType::getEncoding() — return the encoding attribute of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Encoding Attribute opaque pointer uptr, or 0 if absent or null
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::RankedTensorType::getEncoding  %mlir::RankedTensorType::getEncoding)

  ;; @brief mlir::RankedTensorType::cloneWithEncoding(attr) — clone a ranked tensor type with a new encoding.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @param attr  Attribute opaque pointer uptr for the new encoding
  ;; @return      New RankedTensorType opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::RankedTensorType::cloneWithEncoding
    %mlir::RankedTensorType::cloneWithEncoding)

  ;; @brief mlir::isa<mlir::RankedTensorType>(type) — predicate: is the type a ranked tensor?
  ;; @param type  Type opaque pointer uptr
  ;; @return      #t if RankedTensorType, #f otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Wraps %mlir::isa<RankedTensorType>-isa; returns boolean instead of 1/0
  (define (mlir::isa<RankedTensorType>? type)
    (not (zero? (%mlir::isa<RankedTensorType>-isa type))))

  ;; @brief ShapedType::getElementType() — return the element type of a shaped type.
  ;; @param type  ShapedType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::ShapedType::getElementType    %mlir::ShapedType::getElementType)

  ;; @brief mlir::IntegerType::getWidth() — return the bit width of an integer type.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      Bit width as uptr
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define mlir::IntegerType::getWidth          %mlir::IntegerType::getWidth)

  ;; @brief mlir::IntegerType::isUnsigned() — predicate: is the integer type unsigned?
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      #t if unsigned, #f otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Wraps %mlir::IntegerType::isUnsigned; returns boolean instead of 1/0
  (define (mlir::IntegerType::isUnsigned? t)  (not (zero? (%mlir::IntegerType::isUnsigned t))))

  ) ;; end library (mlir IR BuiltinTypes)
