#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir operation) — Operation inspection, mutation, attr access, walk.
;;
;; Mirrors mlir/IR/Operation.h.
;; Imports raw bindings from (mlir ir operation ffi); Scheme helpers added here.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir operation)
  (export
    operation-get-name
    operation-get-context
    operation-get-num-operands
    operation-get-num-results
    operation-get-op-operand
    operation-get-result
    operation-get-parent-op
    op-operand-get-value
    op-result-get-value
    operation-get-loc
    operation-walk
    operation-set-operand
    operation-use-empty?
    operation-get-string-attr
    operation-get-integer-attr
    operation-get-integer-array-attr
    operation-set-f32-attr!
    operation-set-i64-attr!
    operation-set-unit-attr!
    operation-set-index-attr!
    operation-set-dense-i64-array!
    operation-set-i64-array-attr!
    operation-set-dense-i32-array!
    operation-copy-attr!
    operation-has-attr?
    operation-emit-error!
    operation-emit-warning!
    operation-emit-remark!
    operation-erase!
    operation-get-attr
    operation-set-attr!
    operation-get-float-attr)
  (import (rnrs) (mlir ir operation ffi))

  (define operation-get-name          %get-name)
  (define operation-get-context       %get-context)
  (define operation-get-num-operands  %get-num-operands)
  (define operation-get-num-results   %get-num-results)
  (define operation-get-op-operand    %get-op-operand)
  (define operation-get-result        %get-result)
  (define operation-get-parent-op     %get-parent-op)
  (define op-operand-get-value        %op-operand-get-value)
  (define op-result-get-value         %op-result-get-value)
  (define operation-get-loc           %get-loc)
  (define operation-walk              %walk)
  (define operation-set-operand       %set-operand)
  (define (operation-use-empty? op)   (= 1 (%use-empty op)))
  (define operation-get-string-attr   %get-string-attr)
  (define operation-get-integer-attr  %get-integer-attr)
  (define operation-get-integer-array-attr %get-integer-array-attr)
  (define operation-set-f32-attr!     %set-f32-attr)
  (define operation-set-i64-attr!     %set-i64-attr)
  (define operation-set-unit-attr!    %set-unit-attr)
  (define operation-set-index-attr!   %set-index-attr)
  (define operation-set-dense-i64-array! %set-dense-i64-array)
  (define operation-set-i64-array-attr!  %set-i64-array-attr)
  (define operation-set-dense-i32-array! %set-dense-i32-array)
  (define operation-copy-attr!        %copy-attr)
  (define (operation-has-attr? op name) (= 1 (%has-attr op name)))
  (define operation-emit-error!       %emit-error)
  (define operation-emit-warning!     %emit-warning)
  (define operation-emit-remark!      %emit-remark)
  (define operation-erase!            %erase)
  (define operation-get-attr          %operation-get-attr)
  (define (operation-set-attr! op name attr) (%operation-set-attr op name attr))
  (define operation-get-float-attr    %operation-get-float-attr)

) ;; end library (mlir ir operation)
