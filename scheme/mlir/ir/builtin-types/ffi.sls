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
    %index-type-get
    %integer-type-get-i64
    %integer-type-get-i1
    %ranked-tensor-type-isa
    %ranked-tensor-type-get-rank
    %ranked-tensor-type-get-element-type
    %ranked-tensor-type-get-shape
    %ranked-tensor-type-get-encoding
    %ranked-tensor-type-clone-with-encoding
    %shaped-type-get-element-type
    %integer-type-get-width
    %integer-type-is-unsigned)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::IndexType::get — construct an index type in the given context.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IndexType opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %index-type-get
    (foreign-procedure "mlir_ir_builtin_types_index_type_get" (uptr) uptr))

  ;; @brief mlir::IntegerType::get(ctx, 64) — construct a 64-bit integer type.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IntegerType (i64) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-get-i64
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i64" (uptr) uptr))

  ;; @brief mlir::IntegerType::get(ctx, 1) — construct a 1-bit integer type.
  ;; @param ctx  MLIRContext opaque pointer uptr
  ;; @return     IntegerType (i1) opaque pointer uptr, or 0 on failure
  ;; @see        mlir/IR/BuiltinTypes.h
  ;; @note       Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-get-i1
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_i1" (uptr) uptr))

  ;; @brief mlir::isa<mlir::RankedTensorType>(type) — check if type is a ranked tensor.
  ;; @param type  Type opaque pointer uptr
  ;; @return      1 if RankedTensorType, 0 otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-isa
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_isa" (uptr) int))

  ;; @brief mlir::RankedTensorType::getRank() — return the rank of a ranked tensor type.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Rank as integer-64, or -1 if type is null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-get-rank
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_rank"
                       (uptr) integer-64))

  ;; @brief mlir::RankedTensorType::getElementType() — return the element type of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-get-element-type
    (foreign-procedure
     "mlir_ir_builtin_types_ranked_tensor_type_get_element_type" (uptr) uptr))

  ;; @brief mlir::RankedTensorType::getShape() — return the shape of a ranked tensor as a Scheme list.
  ;; @param type  RankedTensorType opaque pointer (scheme-object)
  ;; @return      List of dimension sizes as Scheme integers; '() if null or not a RankedTensorType
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-get-shape
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_shape"
                       (uptr) scheme-object))

  ;; @brief mlir::RankedTensorType::getEncoding() — return the encoding attribute of a ranked tensor.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @return      Encoding Attribute opaque pointer uptr, or 0 if absent or null
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-get-encoding
    (foreign-procedure "mlir_ir_builtin_types_ranked_tensor_type_get_encoding"
                       (uptr) uptr))

  ;; @brief mlir::RankedTensorType::cloneWithEncoding(attr) — clone a ranked tensor type with a new encoding.
  ;; @param type  RankedTensorType opaque pointer uptr
  ;; @param attr  Attribute opaque pointer uptr for the new encoding
  ;; @return      New RankedTensorType opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %ranked-tensor-type-clone-with-encoding
    (foreign-procedure
     "mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding"
     (uptr uptr) uptr))

  ;; @brief ShapedType::getElementType() — return the element type of a shaped type.
  ;; @param type  ShapedType opaque pointer uptr
  ;; @return      Element type opaque pointer uptr, or 0 on failure
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %shaped-type-get-element-type
    (foreign-procedure "mlir_ir_builtin_types_shaped_type_get_element_type"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::getWidth() — return the bit width of an integer type.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      Bit width as uptr
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-get-width
    (foreign-procedure "mlir_ir_builtin_types_integer_type_get_width"
                       (uptr) uptr))

  ;; @brief mlir::IntegerType::isUnsigned() — check if an integer type is unsigned.
  ;; @param type  IntegerType opaque pointer uptr
  ;; @return      1 if unsigned, 0 otherwise
  ;; @see         mlir/IR/BuiltinTypes.h
  ;; @note        Defined in lib/Bindings/IR/BuiltinTypes.cpp
  (define %integer-type-is-unsigned
    (foreign-procedure "mlir_ir_builtin_types_integer_type_is_unsigned"
                       (uptr) int))

) ;; end library (mlir ir builtin-types ffi)
