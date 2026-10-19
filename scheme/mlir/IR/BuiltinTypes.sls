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
    ;; Type predicate helpers
    mlir-isa
    bind-type
    ;; Singleton type instances + isa predicates (via bind-type)
    mlir::Float16Type  mlir::isa<Float16Type>?
    mlir::BFloat16Type mlir::isa<BFloat16Type>?
    mlir::Float32Type  mlir::isa<Float32Type>?
    mlir::Float64Type  mlir::isa<Float64Type>?
    mlir::NoneType     mlir::IndexType    ;; IndexType constructor (also available as mlir::IndexType above)
    mlir::IndexType::get
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
    mlir::FloatType::getWidth
    ;; NoneType
    mlir::NoneType::get
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

  ;; ── mlir-isa ──────────────────────────────────────────────────────────────
  ;; For singleton types, isa<T>(t) ≡ (equal? t (T::get ctx)).
  ;; case-lambda: (mlir-isa type-ptr) → predicate; (mlir-isa type-ptr val) → bool
  (define mlir-isa
    (case-lambda
     [(type-ptr)       (lambda (val) (equal? val type-ptr))]
     [(type-ptr val)   (equal? val type-ptr)]))

  ;; ── bind-type ─────────────────────────────────────────────────────────────
  ;; Generates a singleton instance AND an isa<Name>? predicate from one call:
  ;;   (bind-type mlir::Float64Type mlir::Float64Type::get)
  ;; → mlir::Float64Type       = (mlir::Float64Type::get)   singleton uptr
  ;; → mlir::isa<Float64Type>? = (mlir-isa mlir::Float64Type)
  (define-syntax bind-type
    (lambda (stx)
      (define (type-name-from s)
        ;; "mlir::Float64Type" → "Float64Type"
        (let loop ([i (- (string-length s) 1)])
          (cond [(< i 1) s]
                [(and (char=? (string-ref s i) #\:)
                      (char=? (string-ref s (- i 1)) #\:))
                 (substring s (+ i 1) (string-length s))]
                [else (loop (- i 1))])))
      (syntax-case stx ()
        [(_ name get-fn)
         (let* ([n   (symbol->string (syntax->datum #'name))]
                [isa (datum->syntax #'name
                                    (string->symbol
                                     (string-append "mlir::isa<" (type-name-from n) ">?")))])
           #`(begin
               (define name (get-fn))
               (define #,isa (mlir-isa name))))])))

  ;; ── Singleton types (instance + isa predicate via bind-type) ──────────────
  (bind-type mlir::Float16Type  mlir::Float16Type::get)
  (bind-type mlir::BFloat16Type mlir::BFloat16Type::get)
  (bind-type mlir::Float32Type  mlir::Float32Type::get)
  (bind-type mlir::Float64Type  mlir::Float64Type::get)
  (bind-type mlir::NoneType     mlir::NoneType::get)
  (bind-type mlir::IndexType    mlir::IndexType::get)


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
  (define (mlir::isa<IntegerType>?        t) (not (zero? (%mlir::isa<IntegerType>-isa        t))))
  (define (mlir::isa<FloatType>?          t) (not (zero? (%mlir::isa<FloatType>-isa          t))))
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
