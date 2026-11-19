;; Toy compiler Ch2 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch2/toyc.sls <file.toy> --emit=ast|--emit=mlir
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
  (let* ([option   (parse-command-line (command-line-arguments))]
         [filename (let ([files (option "file")]) (if (null? files) "-" (car files)))]
         [action   (option "emit")])
    (set! %%input-type (string->symbol (or (option "x") "toy")))
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action>, --opt and -x <toy|mlir>, in any order. -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast" "mlir") :required :description "the kind of output"]
  [:long "--opt" :arity 0 :description "run the optimizer"]
  [:short "-x" :choices ("toy" "mlir") :description "the kind of input"]
  [:positional "file" :arity (0 1) :description "the input file, or - for standard input"])

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
