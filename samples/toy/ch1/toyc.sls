;; Toy compiler Ch1 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch1/toyc.sls <file.toy> [--emit=ast]
(import (chezscheme)
        (rime command-line-options)
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

;; The command line: the input file and --emit=ast (also --emit ast). They can come in any order, and -h
;; shows the usage. (rime command-line-options) reads it.
(define-command-line-options %%read-command-line
  [:long "--emit" :choices ("ast") :description "the kind of output"])

;; Returns (values filename action): the input file or #f, and the action as a symbol or #f.
;; A mistake in the command line is a message and the exit status 1.
(define (%%parse-args args)
  (let ([option (guard (e [(error? e)
                           (apply %%command-line-error (condition-message e) (condition-irritants e))])
                  (parameterize ([command-line '("toyc")])
                    (%%read-command-line args)))])
    (when (> (option 'number-of-positional-argument) 1)
      (%%command-line-error "too many input files"))
    (values (and (= (option 'number-of-positional-argument) 1) (option 0))
            (and (option "--emit") (string->symbol (option "--emit"))))))

(define (%%command-line-error message . irritants)
  (display "toyc: " (current-error-port))
  (display message (current-error-port))
  (for-each (lambda (irritant) (display " " (current-error-port)) (write irritant (current-error-port)))
            irritants)
  (newline (current-error-port))
  (exit 1))

(main)
