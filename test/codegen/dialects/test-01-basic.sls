#!/usr/bin/env scheme --program
;; Test 01: Basic minimal dialect
;; Features: name, cppNamespace, description, no dependencies

(import (chezscheme)
        (mlir codegen))

(define test-01-dialect
  (define-dialect
    :name 'test01
    :cpp-namespace  '::mlir::test01
    :description "Minimal test dialect with only required fields.\n    No dependencies, no optional features."
    :depends-on ()))

(main (list test-01-dialect) (cdr (command-line)))
