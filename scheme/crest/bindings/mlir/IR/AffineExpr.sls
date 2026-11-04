#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/AffineExpr.h
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR AffineExpr) — mlir::AffineExpr values and operators.
;;
;; An AffineExpr is a boxed value holding the opaque pointer, so the operators can tell one
;; from an integer: both would otherwise be Scheme integers. mlir::AffineExpr? is the
;; predicate; mlir::AffineExpr::getAsOpaquePointer unboxes. The value is context-owned: valid
;; for the MLIRContext lifetime, do NOT free.
;;
;; The operators accept an AffineExpr or an integer for each operand. An integer becomes
;; getAffineConstantExpr in the context of the other operand. When every operand is an
;; integer, the operator is plain integer arithmetic and returns an integer. The context
;; argument of the leaf constructors is optional and defaults to (current-MLIRContext).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR AffineExpr)
  (export
    mlir::AffineExpr?
    mlir::AffineExpr::getAsOpaquePointer
    mlir::AffineExpr::getContext
    mlir::getAffineDimExpr
    mlir::getAffineSymbolExpr
    mlir::getAffineConstantExpr
    mlir::AffineExpr::operator+
    mlir::AffineExpr::operator-
    mlir::AffineExpr::operator*
    mlir::AffineExpr::floorDiv
    mlir::AffineExpr::ceilDiv
    mlir::AffineExpr::operator%)
  (import (rnrs)
          (mlir IR AffineExpr ffi)
          (mlir IR MLIRContext))

  (define-record-type (%%affine-expr %%box mlir::AffineExpr?)
    (fields (immutable ptr %%unbox)))

  ;; @brief mlir::AffineExpr::getAsOpaquePointer — the raw pointer of an AffineExpr.
  (define (mlir::AffineExpr::getAsOpaquePointer expr)
    (unless (mlir::AffineExpr? expr)
      (error 'mlir::AffineExpr::getAsOpaquePointer "not an AffineExpr" expr))
    (%%unbox expr))

  ;; @brief mlir::AffineExpr::getContext — the raw mlir::MLIRContext* of an AffineExpr.
  (define (mlir::AffineExpr::getContext expr)
    (%mlir::AffineExpr::getContext (mlir::AffineExpr::getAsOpaquePointer expr)))

  (define-syntax define-ctx-expr
    (syntax-rules ()
      [(_ name raw arg)
       (define name
         (case-lambda
          [(arg)     (%%box (raw (current-MLIRContext) arg))]
          [(ctx arg) (%%box (raw ctx arg))]))]))

  ;; @brief mlir::getAffineDimExpr — dimension `position`.
  (define-ctx-expr mlir::getAffineDimExpr %mlir::getAffineDimExpr position)
  ;; @brief mlir::getAffineSymbolExpr — symbol `position`.
  (define-ctx-expr mlir::getAffineSymbolExpr %mlir::getAffineSymbolExpr position)
  ;; @brief mlir::getAffineConstantExpr — the constant `value`.
  (define-ctx-expr mlir::getAffineConstantExpr %mlir::getAffineConstantExpr value)

  (define (%%integer? x) (and (integer? x) (exact? x)))

  ;; The context of the first AffineExpr among the operands, or #f when there is none.
  (define (%%context-of operands)
    (cond
     [(null? operands) #f]
     [(mlir::AffineExpr? (car operands)) (mlir::AffineExpr::getContext (car operands))]
     [else (%%context-of (cdr operands))]))

  ;; The raw pointer of an operand: an AffineExpr as is, an integer as a constant in ctx.
  (define (%%operand who ctx x)
    (cond
     [(mlir::AffineExpr? x) (%%unbox x)]
     [(%%integer? x) (%mlir::getAffineConstantExpr ctx x)]
     [else (error who "operand must be an integer or an AffineExpr" x)]))

  ;; A binary operator: the AffineExpr form when an operand is an AffineExpr, otherwise the
  ;; integer form (both operands must then be integers).
  (define (%%binary who raw integer-form)
    (lambda (a b)
      (let ([ctx (%%context-of (list a b))])
        (if ctx
            (%%box (raw (%%operand who ctx a) (%%operand who ctx b)))
            (begin
              (unless (and (%%integer? a) (%%integer? b))
                (error who "operands must be integers or AffineExprs" a b))
              (integer-form a b))))))

  (define %%add2 (%%binary 'mlir::AffineExpr::operator+ %mlir::AffineExpr::operator+ +))
  (define %%mul2 (%%binary 'mlir::AffineExpr::operator* %mlir::AffineExpr::operator* *))

  ;; @brief mlir::AffineExpr::operator+ — two or more operands, folded to the left.
  (define mlir::AffineExpr::operator+
    (case-lambda
     [(a b) (%%add2 a b)]
     [(a b . rest) (fold-left %%add2 (%%add2 a b) rest)]))

  ;; @brief mlir::AffineExpr::operator* — two or more operands, folded to the left.
  (define mlir::AffineExpr::operator*
    (case-lambda
     [(a b) (%%mul2 a b)]
     [(a b . rest) (fold-left %%mul2 (%%mul2 a b) rest)]))

  ;; @brief mlir::AffineExpr::operator- — negation with one operand, subtraction otherwise.
  ;; MLIR defines -e as e * -1 and a - b as a + (-b), so no raw binding is needed.
  (define mlir::AffineExpr::operator-
    (case-lambda
     [(a) (%%mul2 a -1)]
     [(a . rest)
      (fold-left (lambda (acc x) (%%add2 acc (%%mul2 x -1))) a rest)]))

  ;; @brief mlir::AffineExpr::floorDiv — a floordiv b. For integers, rounds toward -infinity.
  (define mlir::AffineExpr::floorDiv
    (%%binary 'mlir::AffineExpr::floorDiv %mlir::AffineExpr::floorDiv
              (lambda (a b) (floor (/ a b)))))

  ;; @brief mlir::AffineExpr::ceilDiv — a ceildiv b. For integers, rounds toward +infinity.
  (define mlir::AffineExpr::ceilDiv
    (%%binary 'mlir::AffineExpr::ceilDiv %mlir::AffineExpr::ceilDiv
              (lambda (a b) (ceiling (/ a b)))))

  ;; @brief mlir::AffineExpr::operator% — a mod b. For integers, the nonnegative remainder.
  (define mlir::AffineExpr::operator%
    (%%binary 'mlir::AffineExpr::operator% %mlir::AffineExpr::operator% mod))

  ) ;; end library (mlir IR AffineExpr)
