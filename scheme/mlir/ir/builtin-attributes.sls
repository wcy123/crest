#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-attributes) — MLIR builtin attribute bindings.
;;
;; Mirrors mlir/IR/BuiltinAttributes.h.
;; Imports raw C bindings from (mlir ir builtin-attributes ffi) and re-exports
;; under clean names.
;;
;; This is the canonical attribute API.  The old generic dispatch
;; (mlir-make-attr, mlir-attr-isa, etc.) in (mlir core attribute) has been removed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-attributes)
  (export
    integer-attr-get-i64
    integer-attr-get-index
    float-attr-get-f32
    dense-i32-array-attr-get
    dense-i64-array-attr-get
    parse-attribute
    dense-resource-elements-attr-get
    integer-attr?
    float-attr?
    string-attr?
    dense-i32-array-attr?
    dense-elements-attr?
    dense-elements-attr-splat?
    float32-attr?
    integer-attr-value
    float-attr-value
    float32-attr-value
    dense-i32-array-attr-as-array-ref
    dense-fp-elements-attr-splat-value
    dense-int-elements-attr-splat-value
    dense-i32-array-attr->list
    operation-get-attr
    operation-set-attr!
    operation-get-float-attr
    shaped-type-element-type
    integer-type-width
    integer-type-unsigned?)
  (import (rnrs)
          (mlir ir builtin-attributes ffi)
          (mlir ir operation ffi)
          (mlir ir builtin-types ffi)
          (mlir core context))

  ;; Constructors — use current-mlir-context so callers only pass the value.

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with i64 (integer<64>) type.
  ;; @param value  Scheme exact integer (coerced to int64_t)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %integer-attr-get-i64; context supplied by current-mlir-context
  (define (integer-attr-get-i64 value)
    (%integer-attr-get-i64 (current-mlir-context) value))

  ;; @brief mlir::IntegerAttr::get — construct an IntegerAttr with IndexType.
  ;; @param value  Scheme exact integer (coerced to int64_t)
  ;; @return       IntegerAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %integer-attr-get-index; context supplied by current-mlir-context
  (define (integer-attr-get-index value)
    (%integer-attr-get-index (current-mlir-context) value))

  ;; @brief mlir::FloatAttr::get — construct a FloatAttr with f32 (Float32) type.
  ;; @param value  Scheme flonum (cast to float)
  ;; @return       FloatAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %float-attr-get-f32; context supplied by current-mlir-context
  (define (float-attr-get-f32 value)
    (%float-attr-get-f32 (current-mlir-context) value))

  ;; @brief mlir::DenseI32ArrayAttr::get — construct a DenseI32ArrayAttr from a Scheme list.
  ;; @param value  Scheme list of fixnums (each cast to int32_t)
  ;; @return       DenseI32ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-i32-array-attr-get; context supplied by current-mlir-context
  (define (dense-i32-array-attr-get value)
    (%dense-i32-array-attr-get (current-mlir-context) value))

  ;; @brief mlir::DenseI64ArrayAttr::get — construct a DenseI64ArrayAttr from a Scheme list.
  ;; @param value  Scheme list of exact integers (each coerced to int64_t)
  ;; @return       DenseI64ArrayAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-i64-array-attr-get; context supplied by current-mlir-context
  (define (dense-i64-array-attr-get value)
    (%dense-i64-array-attr-get (current-mlir-context) value))

  ;; @brief mlir::parseAttribute — parse an attribute from MLIR textual syntax.
  ;; @param value  Scheme string containing MLIR attribute syntax (e.g. "#some.attr<...>")
  ;; @return       mlir::Attribute opaque pointer uptr; raises error if parse fails
  ;; @see          mlir/AsmParser/AsmParser.h
  ;; @note         Wraps %parse; context supplied by current-mlir-context
  (define (parse-attribute value)
    (%parse (current-mlir-context) value))

  ;; @brief mlir::DenseResourceElementsAttr::get — construct a DenseResourceElementsAttr.
  ;; @param value  Scheme list of (result-type-uptr key-string data-addr-integer data-size-integer)
  ;;               where result-type-uptr is a RankedTensorType opaque pointer
  ;; @return       DenseResourceElementsAttr opaque pointer uptr
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-resource-elements-attr-get; context supplied by current-mlir-context
  (define (dense-resource-elements-attr-get value)
    (%dense-resource-elements-attr-get (current-mlir-context) value))

  ;; @brief mlir::isa<IntegerAttr> — test whether an opaque attribute pointer is an IntegerAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::IntegerAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %integer-attr-isa
  (define (integer-attr? a)        (not (zero? (%integer-attr-isa a))))

  ;; @brief mlir::isa<FloatAttr> — test whether an opaque attribute pointer is a FloatAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::FloatAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %float-attr-isa
  (define (float-attr? a)          (not (zero? (%float-attr-isa a))))

  ;; @brief mlir::isa<StringAttr> — test whether an opaque attribute pointer is a StringAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::StringAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %string-attr-isa
  (define (string-attr? a)         (not (zero? (%string-attr-isa a))))

  ;; @brief mlir::isa<DenseI32ArrayAttr> — test whether an opaque attribute pointer is a DenseI32ArrayAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::DenseI32ArrayAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-i32-array-attr-isa
  (define (dense-i32-array-attr? a) (not (zero? (%dense-i32-array-attr-isa a))))

  ;; @brief mlir::isa<DenseElementsAttr> — test whether an opaque attribute pointer is a DenseElementsAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::DenseElementsAttr (or subclass), #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-elements-attr-isa
  (define (dense-elements-attr? a)  (not (zero? (%dense-elements-attr-isa a))))

  ;; @brief mlir::DenseElementsAttr::isSplat — test whether a DenseElementsAttr is a splat.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is DenseElementsAttr and isSplat() is true, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %dense-elements-attr-is-splat
  (define (dense-elements-attr-splat? a) (not (zero? (%dense-elements-attr-is-splat a))))

  ;; @brief mlir::isa<FloatAttr> (f32 alias) — alias for float-attr?, tests mlir::FloatAttr.
  ;; @param a      mlir::Attribute opaque pointer uptr (0 treated as false)
  ;; @return       boolean: #t if a is mlir::FloatAttr, #f otherwise
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Wraps %float32-attr-isa (which delegates to float_attr_isa in C++)
  (define (float32-attr? a)        (not (zero? (%float32-attr-isa a))))

  ;; @brief mlir::IntegerAttr::getValue — extract the integer value of an IntegerAttr.
  ;; @param attr   mlir::IntegerAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme exact integer (sign-extended from APInt via getSExtValue)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %integer-attr-get-value
  (define integer-attr-value                %integer-attr-get-value)

  ;; @brief mlir::FloatAttr::getValueAsDouble — extract the float value of a FloatAttr.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %float-attr-get-value
  (define float-attr-value                  %float-attr-get-value)

  ;; @brief mlir::FloatAttr::getValueAsDouble (f32 alias) — alias for float-attr-value.
  ;; @param attr   mlir::FloatAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme flonum (double precision via getValueAsDouble)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %float32-attr-get-value (which delegates to float_attr_get_value)
  (define float32-attr-value                %float32-attr-get-value)

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — return a CArrayRef* for a DenseI32ArrayAttr.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       CArrayRef* uptr — heap-allocated {data-ptr uptr, size uint64} pair
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %dense-i32-array-attr-as-array-ref; caller owns the CArrayRef
  (define dense-i32-array-attr-as-array-ref %dense-i32-array-attr-as-array-ref)

  ;; @brief mlir::DenseFPElementsAttr::begin — extract the splat float value of a DenseFPElementsAttr.
  ;; @param attr   mlir::DenseFPElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme flonum (double precision via convertToDouble on the splat APFloat)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %dense-fp-elements-attr-splat-value
  (define dense-fp-elements-attr-splat-value  %dense-fp-elements-attr-splat-value)

  ;; @brief mlir::DenseIntElementsAttr::begin — extract the splat integer value of a DenseIntElementsAttr.
  ;; @param attr   mlir::DenseIntElementsAttr opaque pointer uptr; raises error if null, wrong type, or not splat
  ;; @return       Scheme exact integer (sign-extended via getSExtValue on the splat APInt)
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %dense-int-elements-attr-splat-value
  (define dense-int-elements-attr-splat-value %dense-int-elements-attr-splat-value)

  ;; @brief mlir::DenseI32ArrayAttr::asArrayRef — convert a DenseI32ArrayAttr to a Scheme list.
  ;; @param attr   mlir::DenseI32ArrayAttr opaque pointer uptr; raises error if null or wrong type
  ;; @return       Scheme list of fixnums, one per element
  ;; @see          mlir/IR/BuiltinAttributes.h
  ;; @note         Direct alias for %dense-i32-array-attr-to-list
  (define dense-i32-array-attr->list        %dense-i32-array-attr-to-list)

  ;; @brief mlir::Operation::getAttr — retrieve a named attribute from an operation.
  ;; @param op     mlir::Operation* uptr
  ;; @param name   C string attribute name
  ;; @return       mlir::Attribute opaque pointer uptr; 0 if attribute not found
  ;; @see          mlir/IR/Operation.h
  ;; @note         Direct alias for %operation-get-attr (from mlir ir operation ffi)
  (define operation-get-attr                %operation-get-attr)

  ;; @brief mlir::Operation::setAttr — set a named attribute on an operation.
  ;; @param op     mlir::Operation* uptr
  ;; @param name   C string attribute name
  ;; @param attr   mlir::Attribute opaque pointer uptr
  ;; @return       unspecified
  ;; @see          mlir/IR/Operation.h
  ;; @note         Wraps %operation-set-attr (from mlir ir operation ffi)
  (define (operation-set-attr! op name attr) (%operation-set-attr op name attr))

  ;; @brief mlir::Operation::getAttrOfType<FloatAttr> — retrieve a named FloatAttr as a double.
  ;; @param op     mlir::Operation* uptr (0 returns NaN)
  ;; @param name   C string attribute name (NULL returns NaN)
  ;; @return       double: the float attribute's value, or NaN if not found
  ;; @see          mlir/IR/Operation.h
  ;; @note         Direct alias for %operation-get-float-attr (from mlir ir operation ffi)
  (define operation-get-float-attr          %operation-get-float-attr)

  ;; @brief mlir::ShapedType::getElementType — return the element type of a ShapedType.
  ;; @param type   mlir::Type opaque pointer uptr (0 returns 0)
  ;; @return       mlir::Type opaque pointer uptr for the element type; 0 if not a ShapedType
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Direct alias for %shaped-type-get-element-type (from mlir ir builtin-types ffi)
  (define shaped-type-element-type          %shaped-type-get-element-type)

  ;; @brief mlir::IntegerType::getWidth — return the bit width of an IntegerType.
  ;; @param type   mlir::Type opaque pointer uptr (0 returns 0)
  ;; @return       uint64 bit width; 0 if not an IntegerType
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Direct alias for %integer-type-get-width (from mlir ir builtin-types ffi)
  (define integer-type-width                %integer-type-get-width)

  ;; @brief mlir::IntegerType::isUnsigned — test whether an IntegerType has unsigned signedness.
  ;; @param t      mlir::Type opaque pointer uptr (0 returns #f)
  ;; @return       boolean: #t if the IntegerType is unsigned, #f otherwise
  ;; @see          mlir/IR/BuiltinTypes.h
  ;; @note         Wraps %integer-type-is-unsigned (from mlir ir builtin-types ffi)
  (define (integer-type-unsigned? t) (not (zero? (%integer-type-is-unsigned t))))

) ;; end library (mlir ir builtin-attributes)
