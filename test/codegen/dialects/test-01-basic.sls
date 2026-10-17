#!/usr/bin/env scheme --program
;; Test 01: Basic minimal dialect
;; Features: name, cppNamespace, description, no dependencies

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

(define test-01-dialect
  (define-dialect
    :name "test01"
    :cpp-namespace "::mlir::test01"
    :description "Minimal test dialect with only basic fields"
    :depends-on ()))

;; Command-line handling
(define (main args)
  (cond
    [(or (null? args) (equal? (car args) "decl"))
     (display (sexp->cpp (generate-dialect-decl test-01-dialect)))]
    [(equal? (car args) "def")
     (display (sexp->cpp (generate-dialect-def test-01-dialect)))]
    [else
     (error "Usage: test-01-basic.sls [decl|def]")]))

(main (command-line))
