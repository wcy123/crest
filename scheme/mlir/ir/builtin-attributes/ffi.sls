#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-attributes ffi) — raw C bindings for mlir/IR/BuiltinAttributes.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir builtin-attributes) for normal use.
;; The old generic dispatch (mlir-make-attr, mlir-attr-isa, etc.) has been
;; removed; use (mlir ir builtin-attributes) or these raw bindings directly.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-attributes ffi)
  (export
    %integer-attr-get-i64
    %integer-attr-get-index
    %float-attr-get-f32
    %dense-i32-array-attr-get
    %dense-i64-array-attr-get
    %parse
    %dense-resource-elements-attr-get
    %integer-attr-isa
    %float-attr-isa
    %string-attr-isa
    %dense-i32-array-attr-isa
    %dense-elements-attr-isa
    %dense-elements-attr-is-splat
    %float32-attr-isa
    %integer-attr-get-value
    %float-attr-get-value
    %float32-attr-get-value
    %dense-i32-array-attr-as-array-ref
    %dense-fp-elements-attr-splat-value
    %dense-int-elements-attr-splat-value
    %dense-i32-array-attr-to-list)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i64 (integer<64>) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %integer-attr-get-i64
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_i64"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with IndexType.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme exact integer (coerced to int64_t via Sinteger64_value)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %integer-attr-get-index
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_index"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::FloatAttr::get — construct a FloatAttr with f32 (Float32) type.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme flonum (cast to float via Sflonum_value)
  ;; @return       FloatAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %float-attr-get-f32
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_get_f32"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI32ArrayAttr::get — construct a DenseI32ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of fixnums (each cast to int32_t via Sfixnum_value)
  ;; @return       DenseI32ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-i32-array-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::DenseI64ArrayAttr::get — construct a DenseI64ArrayAttr from a Scheme list.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme list of exact integers (each coerced to int64_t via Sinteger64_value)
  ;; @return       DenseI64ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-i64-array-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i64_array_attr_get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::parseAttribute — parse an attribute from MLIR textual syntax.
  ;; @param ctx    MLIRContext* uptr
  ;; @param value  Scheme string containing MLIR attribute syntax (e.g. "#some.attr<...>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises error if parse fails
  ;; @see          mlir/AsmParser/AsmParser.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %parse
    (foreign-procedure "mlir_ir_builtin_attributes_parse"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::DenseResourceElementsAttr::get — construct a DenseResourceElementsAttr.
  ;; @param ctx    MLIRContext* uptr (unused; type carries the context)
  ;; @param value  Scheme list of (result-type-uptr key-string data-addr-integer data-size-integer)
  ;;               where result-type-uptr is a RankedTensorType opaque pointer,
  ;;               key-string is a Scheme string blob key, data-addr and data-size
  ;;               describe a raw memory region
  ;; @return       DenseResourceElementsAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-resource-elements-attr-get
    (foreign-procedure "mlir_ir_builtin_attributes_dense_resource_elements_attr_get"
                       (uptr scheme-object) uptr))

  ;; @brief mlir::isa<IntegerAttr> — test whether an opaque attribute pointer is an IntegerAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::IntegerAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %integer-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_isa" (uptr) int))

  ;; @brief mlir::isa<FloatAttr> — test whether an opaque attribute pointer is a FloatAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::FloatAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %float-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_isa" (uptr) int))

  ;; @brief mlir::isa<StringAttr> — test whether an opaque attribute pointer is a StringAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::StringAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %string-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_string_attr_isa" (uptr) int))

  ;; @brief mlir::isa<DenseI32ArrayAttr> — test whether an opaque attribute pointer is a DenseI32ArrayAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseI32ArrayAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-i32-array-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_isa"
                       (uptr) int))

  ;; @brief mlir::isa<DenseElementsAttr> — test whether an opaque attribute pointer is a DenseElementsAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::DenseElementsAttr (or subclass), 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-elements-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_dense_elements_attr_isa"
                       (uptr) int))

  ;; @brief mlir::DenseElementsAttr::isSplat — test whether a DenseElementsAttr is a splat.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is a DenseElementsAttr and isSplat() is true, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-elements-attr-is-splat
    (foreign-procedure "mlir_ir_builtin_attributes_dense_elements_attr_is_splat"
                       (uptr) int))

  ;; @brief mlir::isa<FloatAttr> (f32 alias) — alias for %float-attr-isa, tests mlir::FloatAttr.
  ;; @param attr   mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       int: 1 if attr is mlir::FloatAttr, 0 otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; delegates to float_attr_isa
  (define %float32-attr-isa
    (foreign-procedure "mlir_ir_builtin_attributes_float32_attr_isa" (uptr) int))

  ;; @brief mlir::IntegerAttr::getValue — extract the integer value of an IntegerAttr.
  ;; @param attr   mlir::IntegerAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %integer-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_integer_attr_get_value"
                       (uptr) scheme-object))

  ;; @brief mlir::FloatAttr::getValueAsDouble — extract the float value of a FloatAttr.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via Sflonum / getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %float-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_float_attr_get_value"
                       (uptr) scheme-object))

  ;; @brief mlir::FloatAttr::getValueAsDouble (f32 alias) — alias for %float-attr-get-value.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via Sflonum / getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; delegates to float_attr_get_value
  (define %float32-attr-get-value
    (foreign-procedure "mlir_ir_builtin_attributes_float32_attr_get_value"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — return a CArrayRef* for a DenseI32ArrayAttr.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64} pair
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp; caller owns the CArrayRef
  (define %dense-i32-array-attr-as-array-ref
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref"
                       (uptr) uptr))

  ;; @brief mlir::DenseFPElementsAttr::begin — extract the splat float value of a DenseFPElementsAttr.
  ;; @param attr   mlir::DenseFPElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme flonum (double precision via convertToDouble on the splat APFloat)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-fp-elements-attr-splat-value
    (foreign-procedure "mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseIntElementsAttr::begin — extract the splat integer value of a DenseIntElementsAttr.
  ;; @param attr   mlir::DenseIntElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme exact integer (sign-extended via Sinteger64 / getSExtValue on the splat APInt)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-int-elements-attr-splat-value
    (foreign-procedure "mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value"
                       (uptr) scheme-object))

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — convert a DenseI32ArrayAttr to a Scheme list.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme list of fixnums, one per element (built in reverse then reversed)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Defined in lib/Bindings/IR/BuiltinAttributes.cpp
  (define %dense-i32-array-attr-to-list
    (foreign-procedure "mlir_ir_builtin_attributes_dense_i32_array_attr_to_list"
                       (uptr) scheme-object))

) ;; end library (mlir ir builtin-attributes ffi)
