;; Toy compiler Ch1 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch1/toyc.sls <file.toy> [--emit=ast]
(import (chezscheme)
        (toy ch1 parser)
        (toy ch1 ast))

(define (main)
  (let-values ([(filename action) (%%parse-args (command-line-arguments))])
    (unless filename
      (display "Usage: toyc <file.toy> [--emit=ast]\n"
               (current-error-port))
      (exit 1))
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (case action
        [(ast) (toy:dump module-ast)]
        [else
         (display "No action — use --emit=ast\n"
                  (current-error-port))]))))

(define (%%parse-args args)
  (let loop ([args args] [file #f] [action #f])
    (cond
     [(null? args) (values file action)]
     [(member (car args) '("--emit=ast" "-emit=ast"))
      (loop (cdr args) file 'ast)]
     [else
      (loop (cdr args) (car args) action)])))

(main)
