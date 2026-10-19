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
    ;; IndexType
    mlir::IndexType::get
    mlir::isa<IndexType>?
    ;; IntegerType
    mlir::IntegerType::get<i1>
    mlir::IntegerType::get<i8>
    mlir::IntegerType::get<i16>
    mlir::IntegerType::get<i32>
    mlir::IntegerType::get<i64>
    mlir::IntegerType::get
    mlir::isa<IntegerType>?
    mlir::IntegerType::getWidth
    mlir::IntegerType::isUnsigned?
    ;; Float types
    mlir::Float16Type::get
    mlir::BFloat16Type::get
    mlir::Float32Type::get
    mlir::Float64Type::get
    mlir::isa<FloatType>?
    mlir::isa<Float16Type>?
    mlir::isa<BFloat16Type>?
    mlir::isa<Float32Type>?
    mlir::isa<Float64Type>?
    mlir::FloatType::getWidth
    ;; NoneType
    mlir::NoneType::get
    mlir::isa<NoneType>?
    ;; RankedTensorType
    mlir::isa<RankedTensorType>?
    mlir::RankedTensorType::getRank
    mlir::RankedTensorType::getElementType
    mlir::RankedTensorType::getShape
    mlir::RankedTensorType::getEncoding
    mlir::RankedTensorType::cloneWithEncoding
    ;; UnrankedTensorType
    mlir::isa<UnrankedTensorType>?
    ;; MemRefType
    mlir::isa<MemRefType>?
    mlir::isa<UnrankedMemRefType>?
    mlir::MemRefType::getElementType
    mlir::MemRefType::getMemorySpace
    ;; VectorType
    mlir::isa<VectorType>?
    mlir::VectorType::getRank
    mlir::VectorType::getElementType
    ;; ComplexType
    mlir::isa<ComplexType>?
    mlir::ComplexType::getElementType
    ;; ShapedType (base)
    mlir::ShapedType::getElementType)
  (import (rnrs)
          (only (mlir IR MLIRContext) current-MLIRContext define-ctx-optional)
          (mlir IR BuiltinTypes ffi))

  ;; @brief mlir::IndexType::get — construct an index type in the given context.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     IndexType opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define-ctx-optional mlir::IndexType::get %mlir::IndexType::get)

  ;; @brief mlir::IntegerType::get(ctx, 64) — construct a 64-bit integer type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     IntegerType (i64) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define-ctx-optional mlir::IntegerType::get<i64> %mlir::IntegerType::get<i64>)

  ;; @brief mlir::IntegerType::get(ctx, 1) — construct a 1-bit integer type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
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

  ;; Additional integer type constructors
  (define-ctx-optional mlir::IntegerType::get<i8>  %mlir::IntegerType::get<i8>)
  (define-ctx-optional mlir::IntegerType::get<i16> %mlir::IntegerType::get<i16>)
  (define-ctx-optional mlir::IntegerType::get<i32> %mlir::IntegerType::get<i32>)

  ;; General IntegerType::get(ctx, width) — not ctx-optional, width is required
  (define mlir::IntegerType::get %mlir::IntegerType::get)

  ;; Float type constructors
  (define-ctx-optional mlir::Float16Type::get  %mlir::Float16Type::get)
  (define-ctx-optional mlir::BFloat16Type::get %mlir::BFloat16Type::get)
  (define-ctx-optional mlir::Float32Type::get  %mlir::Float32Type::get)
  (define-ctx-optional mlir::Float64Type::get  %mlir::Float64Type::get)

  ;; NoneType constructor
  (define-ctx-optional mlir::NoneType::get %mlir::NoneType::get)

  ;; isa<> predicates — all return #t/#f
  (define (mlir::isa<IndexType>?          t) (not (zero? (%mlir::isa<IndexType>-isa          t))))
  (define (mlir::isa<IntegerType>?        t) (not (zero? (%mlir::isa<IntegerType>-isa        t))))
  (define (mlir::isa<FloatType>?          t) (not (zero? (%mlir::isa<FloatType>-isa          t))))
  (define (mlir::isa<Float16Type>?        t) (not (zero? (%mlir::isa<Float16Type>-isa        t))))
  (define (mlir::isa<BFloat16Type>?       t) (not (zero? (%mlir::isa<BFloat16Type>-isa       t))))
  (define (mlir::isa<Float32Type>?        t) (not (zero? (%mlir::isa<Float32Type>-isa        t))))
  (define (mlir::isa<Float64Type>?        t) (not (zero? (%mlir::isa<Float64Type>-isa        t))))
  (define (mlir::isa<NoneType>?           t) (not (zero? (%mlir::isa<NoneType>-isa           t))))
  (define (mlir::isa<MemRefType>?         t) (not (zero? (%mlir::isa<MemRefType>-isa         t))))
  (define (mlir::isa<UnrankedMemRefType>? t) (not (zero? (%mlir::isa<UnrankedMemRefType>-isa t))))
  (define (mlir::isa<UnrankedTensorType>? t) (not (zero? (%mlir::isa<UnrankedTensorType>-isa t))))
  (define (mlir::isa<VectorType>?         t) (not (zero? (%mlir::isa<VectorType>-isa         t))))
  (define (mlir::isa<ComplexType>?        t) (not (zero? (%mlir::isa<ComplexType>-isa        t))))

  ;; Float type accessor
  (define mlir::FloatType::getWidth %mlir::FloatType::getWidth)

  ;; ComplexType accessor
  (define mlir::ComplexType::getElementType %mlir::ComplexType::getElementType)

  ;; VectorType accessors
  (define mlir::VectorType::getRank        %mlir::VectorType::getRank)
  (define mlir::VectorType::getElementType %mlir::VectorType::getElementType)

  ;; MemRefType accessors
  (define mlir::MemRefType::getElementType %mlir::MemRefType::getElementType)
  (define mlir::MemRefType::getMemorySpace %mlir::MemRefType::getMemorySpace)

  ) ;; end library (mlir IR BuiltinTypes)
