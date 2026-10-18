#!/usr/bin/env scheme --program
;; Arith dialect definition for regression testing
;; Should produce byte-for-byte identical output to mlir-tblgen

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Define Arith dialect (matches MLIR upstream)
(define arith-dialect
  (define-dialect
    :name "arith"
    :cpp-namespace "::mlir::arith"
    :description "The arith dialect is intended to hold basic integer and floating point mathematical operations. This includes unary, binary, and ternary arithmetic ops, bitwise and shift ops, cast ops, and compare ops. Operations in this dialect also accept vectors and tensors of integers or floats."
    :depends-on ()))

;; Command-line handling
(define (main args)
  (cond
   [(or (null? args) (equal? (car args) "decl"))
    (display (sexp->cpp (generate-dialect-decl arith-dialect)))]
   [(equal? (car args) "def")
    (display (sexp->cpp (generate-dialect-def arith-dialect)))]
   [else
    (error "Usage: arith-dialect.sls [decl|def]")]))

;; Run
(main (cdr (command-line)))
