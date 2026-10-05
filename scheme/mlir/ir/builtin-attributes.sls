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
;; For the generic dispatch API (mlir-make-attr, mlir-attr-isa, etc.),
;; use (mlir core attribute) — that layer is preserved for backward compat.
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
  (import (rnrs) (mlir ir builtin-attributes ffi))

  (define integer-attr-get-i64              %integer-attr-get-i64)
  (define integer-attr-get-index            %integer-attr-get-index)
  (define float-attr-get-f32                %float-attr-get-f32)
  (define dense-i32-array-attr-get          %dense-i32-array-attr-get)
  (define dense-i64-array-attr-get          %dense-i64-array-attr-get)
  (define parse-attribute                   %parse)
  (define dense-resource-elements-attr-get  %dense-resource-elements-attr-get)
  (define (integer-attr? a)        (not (zero? (%integer-attr-isa a))))
  (define (float-attr? a)          (not (zero? (%float-attr-isa a))))
  (define (string-attr? a)         (not (zero? (%string-attr-isa a))))
  (define (dense-i32-array-attr? a) (not (zero? (%dense-i32-array-attr-isa a))))
  (define (dense-elements-attr? a)  (not (zero? (%dense-elements-attr-isa a))))
  (define (dense-elements-attr-splat? a) (not (zero? (%dense-elements-attr-is-splat a))))
  (define (float32-attr? a)        (not (zero? (%float32-attr-isa a))))
  (define integer-attr-value                %integer-attr-get-value)
  (define float-attr-value                  %float-attr-get-value)
  (define float32-attr-value                %float32-attr-get-value)
  (define dense-i32-array-attr-as-array-ref %dense-i32-array-attr-as-array-ref)
  (define dense-fp-elements-attr-splat-value  %dense-fp-elements-attr-splat-value)
  (define dense-int-elements-attr-splat-value %dense-int-elements-attr-splat-value)
  (define dense-i32-array-attr->list        %dense-i32-array-attr-to-list)
  (define operation-get-attr                %operation-get-attr)
  (define (operation-set-attr! op name attr) (%operation-set-attr op name attr))
  (define operation-get-float-attr          %operation-get-float-attr)
  (define shaped-type-element-type          %shaped-type-get-element-type)
  (define integer-type-width                %integer-type-get-width)
  (define (integer-type-unsigned? t) (not (zero? (%integer-type-is-unsigned t))))

) ;; end library (mlir ir builtin-attributes)
