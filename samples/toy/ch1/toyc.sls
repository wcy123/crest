;; Toy compiler Ch1 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch1/toyc.sls <file.toy> --emit=ast
(import (chezscheme)
        (rime command-line-options)
        (toy ch1 parser)
        (toy ch1 ast))

;; The command line is one input file and the option --emit=ast, in any order. -h shows the usage.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast") :required :description "the kind of output"]
  [:positional "file" :description "the Toy source file"])

(define (main)
  (let* ([option (parse-or-exit parse-command-line (command-line-arguments))]
         [module-ast (parse-input-file (option "file"))])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(main)
