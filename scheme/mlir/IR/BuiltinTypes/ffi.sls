#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/BuiltinTypes.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR BuiltinTypes ffi) — raw C bindings for mlir/IR/BuiltinTypes.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR BuiltinTypes) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR BuiltinTypes ffi)
  (export
    %mlir::IndexType::get
    %mlir::IntegerType::get<i1>
    %mlir::IntegerType::get<i8>
    %mlir::IntegerType::get<i16>
    %mlir::IntegerType::get<i32>
    %mlir::IntegerType::get<i64>
    %mlir::IntegerType::get
    %mlir::Float16Type::get
    %mlir::BFloat16Type::get
    %mlir::Float32Type::get
    %mlir::Float64Type::get
    %mlir::NoneType::get
    %mlir::isa<RankedTensorType>-isa
    %mlir::isa<IntegerType>-isa
    %mlir::isa<FloatType>-isa
    %mlir::isa<Float16Type>-isa
    %mlir::isa<BFloat16Type>-isa
    %mlir::isa<Float32Type>-isa
    %mlir::isa<Float64Type>-isa
    %mlir::isa<IndexType>-isa
    %mlir::isa<NoneType>-isa
    %mlir::isa<MemRefType>-isa
    %mlir::isa<UnrankedMemRefType>-isa
    %mlir::isa<UnrankedTensorType>-isa
    %mlir::isa<VectorType>-isa
    %mlir::isa<ComplexType>-isa
    %mlir::RankedTensorType::getRank
    %mlir::RankedTensorType::getElementType
    %mlir::RankedTensorType::getShape
    %mlir::RankedTensorType::getEncoding
    %mlir::RankedTensorType::cloneWithEncoding
    %mlir::ShapedType::getElementType
    %mlir::IntegerType::getWidth
    %mlir::IntegerType::isUnsigned
    %mlir::FloatType::getWidth
    %mlir::ComplexType::getElementType
    %mlir::VectorType::getRank
    %mlir::VectorType::getElementType
    %mlir::MemRefType::getElementType
    %mlir::MemRefType::getMemorySpace)
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
  (define %mlir::RankedTensorType::cloneWithEncoding
    (foreign-procedure
     "mlir::RankedTensorType::cloneWithEncoding"
     (uptr uptr) uptr))

  ;; @brief ShapedType::getElementType() — return the element type of a shaped type.
  ;; @param type  ShapedType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::ShapedType::getElementType
    (foreign-procedure "mlir::ShapedType::getElementType"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::getWidth() — return the bit width of an integer type.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      Bit width as uptr
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::IntegerType::getWidth
    (foreign-procedure "mlir::IntegerType::getWidth"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::isUnsigned() — check if an integer type is unsigned.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      1 if unsigned, 0 otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %mlir::IntegerType::isUnsigned
    (foreign-procedure "mlir::IntegerType::isUnsigned"
                       (uptr) int))

  ;; Additional integer type constructors
  (define %mlir::IntegerType::get<i8>
    (foreign-procedure "mlir::IntegerType::get<i8>" (uptr) uptr))
  (define %mlir::IntegerType::get<i16>
    (foreign-procedure "mlir::IntegerType::get<i16>" (uptr) uptr))
  (define %mlir::IntegerType::get<i32>
    (foreign-procedure "mlir::IntegerType::get<i32>" (uptr) uptr))
  (define %mlir::IntegerType::get
    (foreign-procedure "mlir::IntegerType::get" (uptr iptr) uptr))

  ;; Float type constructors
  (define %mlir::Float16Type::get
    (foreign-procedure "mlir::Float16Type::get" (uptr) uptr))
  (define %mlir::BFloat16Type::get
    (foreign-procedure "mlir::BFloat16Type::get" (uptr) uptr))
  (define %mlir::Float32Type::get
    (foreign-procedure "mlir::Float32Type::get" (uptr) uptr))
  (define %mlir::Float64Type::get
    (foreign-procedure "mlir::Float64Type::get" (uptr) uptr))

  ;; NoneType constructor
  (define %mlir::NoneType::get
    (foreign-procedure "mlir::NoneType::get" (uptr) uptr))

  ;; isa<> predicates — suffix -isa to avoid name collision with ? predicates
  (define %mlir::isa<IntegerType>-isa
    (foreign-procedure "mlir::isa<IntegerType>" (uptr) int))
  (define %mlir::isa<FloatType>-isa
    (foreign-procedure "mlir::isa<FloatType>" (uptr) int))
  (define %mlir::isa<Float16Type>-isa
    (foreign-procedure "mlir::isa<Float16Type>" (uptr) int))
  (define %mlir::isa<BFloat16Type>-isa
    (foreign-procedure "mlir::isa<BFloat16Type>" (uptr) int))
  (define %mlir::isa<Float32Type>-isa
    (foreign-procedure "mlir::isa<Float32Type>" (uptr) int))
  (define %mlir::isa<Float64Type>-isa
    (foreign-procedure "mlir::isa<Float64Type>" (uptr) int))
  (define %mlir::isa<IndexType>-isa
    (foreign-procedure "mlir::isa<IndexType>" (uptr) int))
  (define %mlir::isa<NoneType>-isa
    (foreign-procedure "mlir::isa<NoneType>" (uptr) int))
  (define %mlir::isa<MemRefType>-isa
    (foreign-procedure "mlir::isa<MemRefType>" (uptr) int))
  (define %mlir::isa<UnrankedMemRefType>-isa
    (foreign-procedure "mlir::isa<UnrankedMemRefType>" (uptr) int))
  (define %mlir::isa<UnrankedTensorType>-isa
    (foreign-procedure "mlir::isa<UnrankedTensorType>" (uptr) int))
  (define %mlir::isa<VectorType>-isa
    (foreign-procedure "mlir::isa<VectorType>" (uptr) int))
  (define %mlir::isa<ComplexType>-isa
    (foreign-procedure "mlir::isa<ComplexType>" (uptr) int))

  ;; Float type accessor
  (define %mlir::FloatType::getWidth
    (foreign-procedure "mlir::FloatType::getWidth" (uptr) integer-64))

  ;; ComplexType accessor
  (define %mlir::ComplexType::getElementType
    (foreign-procedure "mlir::ComplexType::getElementType" (uptr) uptr))

  ;; VectorType accessors
  (define %mlir::VectorType::getRank
    (foreign-procedure "mlir::VectorType::getRank" (uptr) integer-64))
  (define %mlir::VectorType::getElementType
    (foreign-procedure "mlir::VectorType::getElementType" (uptr) uptr))

  ;; MemRefType accessors
  (define %mlir::MemRefType::getElementType
    (foreign-procedure "mlir::MemRefType::getElementType" (uptr) uptr))
  (define %mlir::MemRefType::getMemorySpace
    (foreign-procedure "mlir::MemRefType::getMemorySpace" (uptr) uptr))

  ) ;; end library (mlir IR BuiltinTypes ffi)
