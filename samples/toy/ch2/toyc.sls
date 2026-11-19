;; Toy compiler Ch2 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch2/toyc.sls <file.toy> [--emit=ast|--emit=mlir]
(import (chezscheme)
        (rime command-line-options)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR OwningOpRef)
        (mlir IR BuiltinOps)
        (toy ch2 parser)
        (toy ch2 ast)
        (toy ch2 toy)
        (toy ch2 mlir-gen))

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename)]
     [else
      (display "No action specified (parsing only?), use -emit=<action>
"
               (current-error-port))
      (%%quit 255)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; -emit=<action> (also --emit=<action> and -emit <action>), -opt (also --opt) and -x <toy|mlir>
;; (also -x=<...>, --x=<...>). The options and the input file can come in any order, and -h shows the
;; usage. (rime command-line-options) reads it.
(define-command-line-options %%read-command-line
  [:short "-emit" :long "--emit" :choices ("ast" "mlir") :description "the kind of output"]
  [:short "-opt"  :long "--opt"  :arity 0 :description "run the optimizer"]
  [:short "-x"    :long "--x"    :choices ("toy" "mlir") :description "the kind of input"])

;; Returns (values filename action opt? input-type): the input file, the action as a string or #f,
;; whether -opt is there, and the kind of input as a symbol.
;; A mistake in the command line is a message and the exit status 1.
(define (%%parse-args args)
  (let ([option (guard (e [(error? e)
                           (apply %%command-line-error (condition-message e) (condition-irritants e))])
                  (parameterize ([command-line '("toyc")])
                    (%%read-command-line args)))])
    (when (> (option 'number-of-positional-argument) 1)
      (%%command-line-error "too many input files"))
    (values (if (zero? (option 'number-of-positional-argument)) "-" (option 0))
            (option "-emit")
            (eq? (option "-opt") 'present)
            (string->symbol (or (option "-x") "toy")))))

(define (%%command-line-error message . irritants)
  (display "toyc: " (current-error-port))
  (display message (current-error-port))
  (for-each (lambda (irritant) (display " " (current-error-port)) (write irritant (current-error-port)))
            irritants)
  (newline (current-error-port))
  (%%quit 1))

(define (%%dump-ast filename)
  (when (eq? %%input-type 'mlir)
    (display "Can't dump a Toy AST when the input is MLIR\n" (current-error-port))
    (%%quit 5))
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 6))
    (with-DialectRegistry reg ()
      (mlir::DialectRegistry::insert reg "toy" "toy/ch2/toy")
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::getOrLoadDialect ctx "toy")
        ;; mlir-gen answers #f when it fails; erasing 0 does nothing.
        ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
        ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
        (with-mlir::OwningOpRef module-op (or (mlir-gen ctx module-ast) 0)
          (when (zero? module-op) (%%quit 1))
          (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
          (newline))))))



;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it
;; (the context, the module), and raising does.
(define (%%quit code)
  (raise (list 'toyc-exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'toyc-exit)) (exit (cadr e))])
  (main))
