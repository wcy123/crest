#!/usr/bin/env scheme --program
;; Test 12: All features combined
;; This test enables EVERY dialect feature to ensure complete coverage

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Use make-dialect directly to specify all fields
(define test-12-dialect
  (make-dialect
    ;; Basic properties
    "test12"                                    ; name
    "::mlir::test12"                            ; cpp-namespace
    "Comprehensive test dialect with all features enabled" ; description
    '("::mlir::arith::ArithDialect"             ; dependent-dialects
      "::mlir::tensor::TensorDialect")

    ;; Printer/parser flags
    #t                                          ; use-default-attr-printer
    #t                                          ; use-default-type-printer

    ;; Capabilities
    #t                                          ; has-constant-materializer
    #t                                          ; has-canonicalizer
    #t                                          ; has-op-attr-verify
    #t                                          ; has-region-arg-attr-verify
    #t                                          ; has-region-result-attr-verify
    #f                                          ; has-non-default-destructor
    #f                                          ; has-op-interface-fallback

    ;; Extra code
    "
  // Project-specific helpers
  static bool isQuantizedType(::mlir::Type type);
  void registerCustomPasses();
"))

(define (main args)
  (cond
    [(or (null? args) (equal? (car args) "decl"))
     (display (sexp->cpp (generate-dialect-decl test-12-dialect)))]
    [(equal? (car args) "def")
     (display (sexp->cpp (generate-dialect-def test-12-dialect)))]
    [else
     (error "Usage: test-12-all-features.sls [decl|def]")]))

(main (command-line))
