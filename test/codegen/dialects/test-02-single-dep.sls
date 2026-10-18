#!/usr/bin/env scheme --program
;; Test 02: Single dependency
;; Features: one dependent dialect

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

(define test-02-dialect
  (define-dialect
    :name "test02"
    :cpp-namespace "::mlir::test02"
    :description "Dialect with single dependency on Arith"
    :depends-on ("::mlir::arith::ArithDialect")))

(define (main args)
  (cond
   [(or (null? args) (equal? (car args) "decl"))
    (display (sexp->cpp (generate-dialect-decl test-02-dialect)))]
   [(equal? (car args) "def")
    (display (sexp->cpp (generate-dialect-def test-02-dialect)))]
   [else
    (error "Usage: test-02-single-dep.sls [decl|def]")]))

(main (cdr (command-line)))
