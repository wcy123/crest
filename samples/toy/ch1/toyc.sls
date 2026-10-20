#!/usr/bin/env scheme --program
;; Toy compiler Ch1 entry point.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
;;
;; Usage: toyc.sls <input.toy> [--emit=ast]
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
     [(string=? (car args) "--emit=ast")
      (loop (cdr args) filename 'dump-ast)]
     [else
      (loop (cdr args) (car args) action)])))

(define (main args)
  (call-with-values
      (lambda () (%%parse-args args))
    (lambda (filename action)
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
                    (current-error-port))])))))

(main (cdr (command-line)))
