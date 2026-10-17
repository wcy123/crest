#!/usr/bin/env scheme --program
;; Test 03: Multiple dependencies
;; Features: three dependent dialects (matches Tensor dialect)

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

(define test-03-dialect
  (define-dialect
    :name "test03"
    :cpp-namespace "::mlir::test03"
    :description "Dialect with multiple dependencies (Affine, Arith, Complex)"
    :depends-on ("::mlir::affine::AffineDialect"
                 "::mlir::arith::ArithDialect"
                 "::mlir::complex::ComplexDialect")))

(define (main args)
  (cond
    [(or (null? args) (equal? (car args) "decl"))
     (display (sexp->cpp (generate-dialect-decl test-03-dialect)))]
    [(equal? (car args) "def")
     (display (sexp->cpp (generate-dialect-def test-03-dialect)))]
    [else
     (error "Usage: test-03-multiple-deps.sls [decl|def]")]))

(main (command-line))
