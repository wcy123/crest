#!/bin/sh
#|
SCHEME="${CREST_BUILD_DIR:-/home/build/crest-1}/ChezScheme-build/ta6le/bin/ta6le/scheme"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$SCHEME" --libdirs "$ROOT/samples:$ROOT/scheme" --program "$0" "$@"
|#
;; Toy compiler Ch2 entry point.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Usage: toyc.sls <input.toy> [--emit=ast|--emit=mlir]
;;
;; Actions:
;;   --emit=ast    dump the parsed Toy AST
;;   --emit=mlir   lower the AST to MLIR and dump the module

(import (chezscheme)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (toy ch1 parser)
        (toy ch1 ast)
        (toy ch2 toy)
        (toy ch2 mlir-gen))

(define (%%parse-args args)
  (let loop ([args args] [filename #f] [action 'none])
    (cond
     [(null? args)
      (values filename action)]
     [(member (car args) '("--emit=ast" "-emit=ast"))
      (loop (cdr args) filename 'dump-ast)]
     [(member (car args) '("--emit=mlir" "-emit=mlir"))
      (loop (cdr args) filename 'dump-mlir)]
     [else
      (loop (cdr args) (car args) action)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (let* ([ctx (mlir::MLIRContext::new)]
           [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
           [_   (toy:register! ctx)]
           [module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      (mlir::Operation::dump (mlir::ModuleOp::getOperation module-op)))))

(define (main args)
  (let-values ([(filename action) (%%parse-args args)])
    (unless filename
      (display "Usage: toyc.sls <input.toy> [--emit=ast|--emit=mlir]\n"
               (current-error-port))
      (exit 1))
    (case action
      [(dump-ast)  (%%dump-ast  filename)]
      [(dump-mlir) (%%dump-mlir filename)]
      [else
       (display "No action specified (parsing only?), use --emit=<action>\n"
                (current-error-port))])))

(main (cdr (command-line)))
