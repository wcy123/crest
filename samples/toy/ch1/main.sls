#!/usr/bin/env scheme --program
;; Toy Ch-1 entry point
;; Usage: main.sls <file.toy>
;;
;; Reads a .toy source file, builds the AST, lowers to MLIR, prints the IR.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
(import (chezscheme)
        (mlir IR MLIRContext)
        (toy ch1 dialect)
        (toy ch1 ops)
        (toy ch1 codegen))

(define (main args)
  (when (null? args)
    (error "toy" "Usage: main.sls <file.toy>"))
  (let* ([filename (car args)]
         [ctx (mlir::MLIRContext::new)])
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (register-toy-dialect! ctx toy-ops-initialize)
    (mlir::MLIRContext::getOrLoadDialect ctx "toy")
    ;; TODO: parse filename, build AST, codegen, print
    (display "Toy dialect registered.\n")))

(main (cdr (command-line)))
