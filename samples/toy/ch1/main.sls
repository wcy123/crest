#!/usr/bin/env scheme --program
;; Toy Ch-1 entry point
;; Usage: main.sls <file.toy>
(import (chezscheme)
        (mlir IR MLIRContext)
        (toy ch1 toy)
        (toy ch1 codegen))

(define (main args)
  (when (null? args)
    (error "toy" "Usage: main.sls <file.toy>"))
  (let* ([filename (car args)]
         [ctx      (mlir::MLIRContext::new)])
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (toy:register! ctx)
    (mlir::MLIRContext::getOrLoadDialect ctx "toy")
    ;; TODO: parse filename, build AST, codegen, print
    (display "Toy dialect registered.\n")))

(main (cdr (command-line)))
