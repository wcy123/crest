#!/bin/sh
#|
SCHEME="${CREST_BUILD_DIR:-/home/build/crest-1}/ChezScheme-build/ta6le/bin/ta6le/scheme"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$SCHEME" --libdirs "$ROOT/samples:$ROOT/scheme" --program "$0" "$@"
|#
;; Toy compiler Ch1 entry point.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
;;
;; Usage: toyc-ch1.sls <input.toy> [--emit=ast]
;;
;; Actions:
;;   --emit=ast   dump the parsed AST to stdout

(import (chezscheme)
        (toy ch1 parser)
        (toy ch1 ast))

(define (%%parse-args args)
  (let loop ([args args] [filename #f] [action 'none])
    (cond
     [(null? args)
      (values filename action)]
     [(member (car args) (quote ("--emit=ast" "-emit=ast")))
      (loop (cdr args) filename 'dump-ast)]
     [else
      (loop (cdr args) (car args) action)])))

(define (main args)
  (let-values ([(filename action) (%%parse-args args)])
    (unless filename
      (display "Usage: toyc.sls <input.toy> [--emit=ast]\n"
               (current-error-port))
      (exit 1))
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast
        (exit 1))
      (case action
        [(dump-ast) (toy:dump module-ast)]
        [else
         (display "No action specified (parsing only?), use --emit=<action>\n"
                  (current-error-port))]))))

(main (cdr (command-line)))
